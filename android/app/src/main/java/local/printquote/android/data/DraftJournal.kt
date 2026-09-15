package local.printquote.android.data
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.UUID
import org.json.JSONObject

/** Atomic recovery journals, separate from validated/saved quotes. */
class DraftJournal(private val folder:File) {
 @Synchronized fun write(text:String){val id=UUID.fromString(JSONObject(text).getString("id")).toString();folder.mkdirs();val tmp=File.createTempFile("draft-",".tmp",folder);try{tmp.outputStream().use{it.write(text.toByteArray(Charsets.UTF_8));it.fd.sync()};try{Files.move(tmp.toPath(),File(folder,"$id.json").toPath(),StandardCopyOption.ATOMIC_MOVE,StandardCopyOption.REPLACE_EXISTING)}catch(_:java.nio.file.AtomicMoveNotSupportedException){Files.move(tmp.toPath(),File(folder,"$id.json").toPath(),StandardCopyOption.REPLACE_EXISTING)}}finally{tmp.delete()}}
 @Synchronized fun read():List<JSONObject> = folder.listFiles()?.filter{it.extension=="json"}?.sortedByDescending{it.lastModified()}?.map{JSONObject(it.readText())}.orEmpty()
 data class Scan(val drafts:List<JSONObject>,val issues:List<String>)
 @Synchronized fun scan():Scan {
  val drafts=mutableListOf<JSONObject>();val issues=mutableListOf<String>()
  for(file in folder.listFiles()?.filter{it.extension=="json"}?.sortedByDescending{it.lastModified()}.orEmpty()) {
   try{val value=JSONObject(file.readText());UUID.fromString(value.getString("id"));drafts.add(value)}catch(e:Exception){issues.add(file.name+": "+e.message)}
  }
  return Scan(drafts,issues)
 }
 @Synchronized fun discard(id:String){val file=File(folder,UUID.fromString(id).toString()+".json");if(file.exists())check(file.delete()){ "Could not remove recovery draft" }}
}

/** Merge only records changed by an operation, preserving unrelated commits queued meanwhile. */
fun mergeWorkspaceChanges(latest:JSONObject,base:JSONObject,next:JSONObject):JSONObject {
 val result=JSONObject(latest.toString())
 for(kind in listOf("quotes","printers","filaments","presets")) {
  fun rows(root:JSONObject):List<JSONObject>{val a=root.optJSONArray(kind) ?: return emptyList();return (0 until a.length()).map{a.getJSONObject(it)}}
  val before=rows(base).associateBy{it.getString("id")};val after=rows(next).associateBy{it.getString("id")}
  val changed=after.filter{(id,value)->before[id]?.toString()!=value.toString()};val removed=before.keys-after.keys
  val kept=rows(latest).filterNot{it.getString("id") in removed || it.getString("id") in changed}
  result.put(kind,org.json.JSONArray(changed.values.toList()+kept))
 }
 if(base.optJSONObject("settings")?.toString()!=next.optJSONObject("settings")?.toString())result.put("settings",next.getJSONObject("settings"))
 return result
}
