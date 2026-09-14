import local.printquote.windows.*
import local.printquote.android.model.*
import org.junit.Test
import org.junit.Assert.*
import java.nio.file.Files
import java.nio.file.Path
import java.sql.DriverManager
import org.json.JSONObject

class DatabaseSafetyTests {
 private fun temporary(test:(Path)->Unit) {val d=Files.createTempDirectory("pq-safety");try{test(d)}finally{d.toFile().deleteRecursively()}}
 private fun sql(p:Path,statement:String)=DriverManager.getConnection("jdbc:sqlite:$p").use {c->c.createStatement().use {it.execute(statement)}}
 private fun value(p:Path,query:String)=DriverManager.getConnection("jdbc:sqlite:$p").use {c->c.createStatement().use {s->s.executeQuery(query).use {r->r.next();r.getString(1)}}}
 private fun doc(n:Int)=JSONObject().put("schemaVersion",2).put("revisionMarker",n).put("userOverride",true)
 @Test fun futureDatabaseVersionIsNotDowngraded()=temporary { d->
  val p=d.resolve("workspace.sqlite");SqliteWorkspaceStore(p).save(doc(1));sql(p,"PRAGMA user_version=77")
  val before=Files.readAllBytes(p)
  assertThrows(IllegalArgumentException::class.java){SqliteWorkspaceStore(p)}
  assertEquals("77",value(p,"PRAGMA user_version"));assertArrayEquals(before,Files.readAllBytes(p))
 }
 @Test fun corruptDatabaseIsPreserved()=temporary { d->
  val p=d.resolve("workspace.sqlite");val original="not a sqlite database".toByteArray();Files.write(p,original)
  assertThrows(Exception::class.java){SqliteWorkspaceStore(p)}
  assertArrayEquals(original,Files.readAllBytes(p));Files.move(p,d.resolve("preserved.sqlite"))
 }
 @Test fun legacyMigrationBacksUpBeforeChangingVersion()=temporary { d->
  val p=d.resolve("workspace.sqlite");SqliteWorkspaceStore(p).save(doc(19));sql(p,"PRAGMA user_version=0")
  val original=value(p,"SELECT payload FROM workspace")
  assertEquals(19,SqliteWorkspaceStore(p).load().getInt("revisionMarker"))
  assertEquals("1",value(p,"PRAGMA user_version"))
  val b=Files.list(d.resolve("backups")).use{it.filter{p->p.toString().endsWith("-migration.sqlite")}.toList()}.single()
  assertEquals("0",value(b,"PRAGMA user_version"));assertEquals(original,value(b,"SELECT payload FROM workspace"))
 }
 @Test fun backupFailureBlocksMigrationAndSave()=temporary { d->
  val p=d.resolve("workspace.sqlite");val store=SqliteWorkspaceStore(p);store.save(doc(1))
  Files.writeString(d.resolve("backups"),"block backup directory")
  assertThrows(Exception::class.java){store.save(doc(2))}
  assertEquals(1,store.load().getInt("revisionMarker"))
  sql(p,"PRAGMA user_version=0")
  assertThrows(Exception::class.java){SqliteWorkspaceStore(p)}
  assertEquals("0",value(p,"PRAGMA user_version"))
 }
 @Test fun transactionFailureRetainsCompleteOldDocument()=temporary { d->
  val p=d.resolve("workspace.sqlite");val store=SqliteWorkspaceStore(p);store.save(doc(1))
  sql(p,"CREATE TRIGGER reject_write BEFORE UPDATE ON workspace BEGIN SELECT RAISE(ABORT,'injected failure'); END")
  assertThrows(Exception::class.java){store.save(doc(2))}
  assertEquals(1,store.load().getInt("revisionMarker"));assertEquals("ok",value(p,"PRAGMA integrity_check"))
 }
 @Test fun backupsContainPriorValuesAndKeepOnlyThreeRollingSnapshots()=temporary { d->
  val store=SqliteWorkspaceStore(d.resolve("workspace.sqlite"));(1..6).forEach {store.save(doc(it))}
  val snapshots=Files.list(d.resolve("backups")).use{it.filter{p->p.toString().endsWith("-rolling.sqlite")}.toList()}
  assertEquals(3,snapshots.size)
  assertEquals(setOf(3,4,5),snapshots.map{JSONObject(value(it,"SELECT payload FROM workspace")).getJSONObject("document").getInt("revisionMarker")}.toSet())
  val exported=d.resolve("manual.sqlite");store.exportBackup(exported)
  assertEquals(6,SqliteWorkspaceStore(exported).load().getInt("revisionMarker"))
  assertThrows(IllegalArgumentException::class.java){store.exportBackup(exported)}
 }
 @Test fun backupIncludesCommittedWalPages()=temporary {d->
  val p=d.resolve("workspace.sqlite");val store=SqliteWorkspaceStore(p);store.save(doc(1))
  DriverManager.getConnection("jdbc:sqlite:$p").use {c->
   c.createStatement().use {s->s.execute("PRAGMA wal_autocheckpoint=0");s.execute("UPDATE workspace SET payload='{"+"\"formatVersion\":1,\"document\":{\"schemaVersion\":2,\"revisionMarker\":23}}'")}
   val exported=d.resolve("wal-copy.sqlite");store.exportBackup(exported)
   assertEquals(23,SqliteWorkspaceStore(exported).load().getInt("revisionMarker"))
  }
 }
 @Test fun unsupportedWorkspaceSchemaIsNotOverwritten()=temporary {d->
  val p=d.resolve("workspace.sqlite");val store=SqliteWorkspaceStore(p);store.save(doc(1))
  sql(p,"UPDATE workspace SET payload='{\"formatVersion\":1,\"document\":{\"schemaVersion\":99}}'")
  assertThrows(IllegalArgumentException::class.java){SqliteWorkspaceStore(p)}
  assertThrows(IllegalArgumentException::class.java){store.save(doc(2))}
  assertTrue(value(p,"SELECT payload FROM workspace").contains("99"))
 }
}
