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

fun resource(name:String)=checkNotNull(object {}.javaClass.getResourceAsStream("/$name")) { "Missing bundled resource: $name" }
@Serializable data class WorkspaceDocument(val formatVersion:Int=1,val document:JsonObject)
interface WorkspaceStore { fun load():JSONObject; fun save(document:JSONObject) }
/** One transactional document preserves unknown Swift fields and immutable quote snapshots. */
class SqliteWorkspaceStore(val path:Path):WorkspaceStore {
 private fun connection()=DriverManager.getConnection("jdbc:sqlite:$path")
 init {
  Files.createDirectories(path.toAbsolutePath().parent)
  Class.forName("org.sqlite.JDBC")
  connection().use { c -> c.createStatement().use { s ->
   s.execute("PRAGMA journal_mode=WAL")
   s.execute("CREATE TABLE IF NOT EXISTS workspace (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)")
   s.execute("PRAGMA user_version=1")
  } }
 }
 override fun load():JSONObject {
  val stored=connection().use { c -> c.createStatement().use { s -> s.executeQuery("SELECT payload FROM workspace WHERE id=1").use { r -> if(r.next()) r.getString(1) else null } } }
  if(stored!=null) {
   val envelope=Json.decodeFromString<WorkspaceDocument>(stored)
   require(envelope.formatVersion==1) { "Unsupported database version; original data preserved." }
   return JSONObject(envelope.document.toString())
  }
  val library=JSONObject(resource("library_seed_v1.json").bufferedReader().use {it.readText()})
  val printers=library.array("printers").toMutableList(); val ids=printers.map {it.text("id").lowercase()}.toMutableSet()
  printers.forEach {if(it.optJSONObject("toolSystem")==null) it.put("toolSystem",Defaults.system().put("architecture","custom"))}
  listOf("orca_profiles_v2.json","manufacturer_printers_v2.json").forEach { name ->
   JSONObject(resource(name).bufferedReader().use {it.readText()}).array("profiles").filter {it.text("kind")=="machine"}.forEach {p -> if(ids.add(p.text("id").lowercase())) printers.add(WorkspaceRepository.convertPrinter(p))}
  }
  library.put("printers",array(printers)).put("schemaVersion",2)
  save(library); return library
 }
 override fun save(document:JSONObject) {
  require(document.number("schemaVersion",1) in 1..2) { "Unsupported workspace schema" }
  val payload=Json.encodeToString(WorkspaceDocument(document=Json.parseToJsonElement(document.toString()).jsonObject))
  connection().use {c -> c.autoCommit=false; try {
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
