package local.printquote.windows

import local.printquote.android.model.*
import local.printquote.android.data.WorkspaceRepository
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.*
import kotlinx.serialization.encodeToString
import kotlinx.serialization.decodeFromString
import org.json.JSONObject
import java.nio.file.Path
import java.nio.file.Files
import java.sql.DriverManager
import java.sql.Connection
import java.nio.file.StandardCopyOption
import java.util.UUID

fun resource(name:String)=checkNotNull(object {}.javaClass.getResourceAsStream("/$name")) { "Missing bundled resource: $name" }
@Serializable data class WorkspaceDocument(val formatVersion:Int=1,val document:JsonObject)
interface WorkspaceStore { fun load():JSONObject; fun save(document:JSONObject) }
/** One transactional document preserves unknown Swift fields and immutable quote snapshots. */
class SqliteWorkspaceStore(val path:Path):WorkspaceStore {
 private val backups = path.toAbsolutePath().parent.resolve("backups")
 private fun connection()=DriverManager.getConnection("jdbc:sqlite:$path").also { c ->
  try {c.createStatement().use { s ->
   s.execute("PRAGMA busy_timeout=5000")
   s.execute("PRAGMA foreign_keys=ON")
   s.execute("PRAGMA synchronous=FULL")
  }} catch(e:Exception) {c.close();throw e}
 }
 init {
  Files.createDirectories(path.toAbsolutePath().parent)
  Class.forName("org.sqlite.JDBC")
  connection().use { c ->
   checkIntegrity(c)
   val version=version(c)
   require(version in 0..1) { "This database needs a newer version of PrintQuote3D. No migration was performed." }
   val tables=c.createStatement().use { s -> s.executeQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").use { r -> buildList {while(r.next()) add(r.getString(1))} } }
   if(version==0) {
    require(tables.isEmpty() || tables==listOf("workspace")) { "Unrecognized database layout. Original data preserved." }
    if(tables.isNotEmpty()) {
     readPayload(c)?.let(::decodeDocument)
     backup(c,"migration")
    }
    c.autoCommit=false
    try {
     c.createStatement().use { s ->
      s.execute("CREATE TABLE IF NOT EXISTS workspace (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)")
      s.execute("PRAGMA user_version=1")
     }
     checkIntegrity(c);c.commit()
    } catch(e:Exception) {c.rollback();throw e} finally {c.autoCommit=true}
   } else {
    require("workspace" in tables) { "Workspace table is missing. Restore a backup; no data was reset." }
    readPayload(c)?.let(::decodeDocument)
   }
   c.createStatement().use { it.execute("PRAGMA journal_mode=WAL") }
  }
 }
 private fun version(c:Connection)=c.createStatement().use { s -> s.executeQuery("PRAGMA user_version").use { r ->r.next();r.getInt(1) } }
 private fun checkIntegrity(c:Connection) {
  c.createStatement().use { s -> s.executeQuery("PRAGMA quick_check").use { r ->
   require(r.next() && r.getString(1)=="ok" && !r.next()) { "Database integrity check failed. Original data preserved; restore a backup." }
  } }
 }
 private fun readPayload(c:Connection):String?=c.createStatement().use { s -> s.executeQuery("SELECT payload FROM workspace WHERE id=1").use { r ->if(r.next())r.getString(1)else null } }
 private fun decodeDocument(payload:String):JSONObject {
  val envelope=Json.decodeFromString<WorkspaceDocument>(payload)
  require(envelope.formatVersion==1) { "Unsupported database document version; original data preserved." }
  return JSONObject(envelope.document.toString()).also {
   require(it.number("schemaVersion",1) in 1..2) { "Unsupported workspace schema; original data preserved." }
  }
 }
 /** VACUUM INTO includes committed WAL pages; copying the main file alone does not. */
 private fun backup(c:Connection,reason:String):Path {
  Files.createDirectories(backups)
  val name="workspace-${System.currentTimeMillis()}-${UUID.randomUUID()}-$reason"
  val temporary=backups.resolve("$name.partial")
  val complete=backups.resolve("$name.sqlite")
  try {
   c.prepareStatement("VACUUM INTO ?").use { it.setString(1,temporary.toString());it.execute() }
   DriverManager.getConnection("jdbc:sqlite:$temporary").use(::checkIntegrity)
   Files.move(temporary,complete,StandardCopyOption.ATOMIC_MOVE)
  } finally {Files.deleteIfExists(temporary)}
  // Migration recovery points are retained independently of routine rolling backups.
  if(reason=="rolling") Files.list(backups).use { paths ->
   paths.filter {it.fileName.toString().endsWith("-rolling.sqlite")}
    .sorted(compareByDescending<Path> {Files.getLastModifiedTime(it)}.thenByDescending {it.fileName.toString()})
    .skip(3).forEach {Files.deleteIfExists(it)}
  }
  return complete
 }
 @Synchronized fun exportBackup(destination:Path) {
  require(!Files.exists(destination)) { "Choose a new backup filename; existing files are never overwritten." }
  connection().use { c ->
   checkIntegrity(c);readPayload(c)?.let(::decodeDocument)
   val snapshot=backup(c,"manual")
   val temporary=Files.createTempFile(destination.toAbsolutePath().parent,".printquote-backup-",".partial")
   try {
    Files.copy(snapshot,temporary,StandardCopyOption.REPLACE_EXISTING)
    java.nio.channels.FileChannel.open(temporary,java.nio.file.StandardOpenOption.WRITE).use {it.force(true)}
    Files.move(temporary,destination)
   }finally{Files.deleteIfExists(temporary)}
  }
 }
 @Synchronized override fun load():JSONObject {
  val stored=connection().use(::readPayload)
  if(stored!=null) return decodeDocument(stored)
  val library=JSONObject(resource("library_seed_v1.json").bufferedReader().use {it.readText()})
  val printers=library.array("printers").toMutableList(); val ids=printers.map {it.text("id").lowercase()}.toMutableSet()
  printers.forEach {if(it.optJSONObject("toolSystem")==null) it.put("toolSystem",Defaults.system().put("architecture","custom"))}
  listOf("orca_profiles_v2.json","manufacturer_printers_v2.json").forEach { name ->
   JSONObject(resource(name).bufferedReader().use {it.readText()}).array("profiles").filter {it.text("kind")=="machine"}.forEach {p -> if(ids.add(p.text("id").lowercase())) printers.add(WorkspaceRepository.convertPrinter(p))}
  }
  library.put("printers",array(printers)).put("schemaVersion",2)
  save(library); return library
 }
 @Synchronized override fun save(document:JSONObject) {
  require(document.number("schemaVersion",1) in 1..2) { "Unsupported workspace schema" }
  val payload=Json.encodeToString(WorkspaceDocument(document=Json.parseToJsonElement(document.toString()).jsonObject))
  connection().use {c ->
   val previous=readPayload(c)
   if(previous==payload)return
   if(previous!=null) {decodeDocument(previous);backup(c,"rolling")}
   c.autoCommit=false; try {
   c.prepareStatement("INSERT INTO workspace(id,payload) VALUES(1,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload").use {s -> s.setString(1,payload);s.executeUpdate()}; c.commit()
  } catch(e:Exception) {c.rollback();throw e} }
 }
}
fun dataHome():Path {
 val override=System.getProperty("printquote.dataDir")
 if(override!=null) return Path.of(override)
 val base=System.getenv("LOCALAPPDATA") ?: (System.getProperty("user.home")+"/Library/Application Support")
 return Path.of(base,"PrintQuote3D")
}
