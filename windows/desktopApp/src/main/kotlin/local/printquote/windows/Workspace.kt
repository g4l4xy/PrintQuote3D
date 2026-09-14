package local.printquote.windows
import androidx.compose.runtime.*
import kotlinx.coroutines.*
import local.printquote.android.model.*
import local.printquote.android.data.WorkspaceRepository
import local.printquote.android.pricing.PricingEngine
import local.printquote.android.viewmodel.Draft
import org.json.JSONObject

class Workspace(private val scope:CoroutineScope) {
 var loadFailed by mutableStateOf(false)
 var library by mutableStateOf<JSONObject?>(null)
 var searchRequest by mutableIntStateOf(0)
 var screen by mutableStateOf("Dashboard")
 var draft by mutableStateOf<Draft?>(null)
 var editor by mutableStateOf<Draft?>(null)
 var kind by mutableStateOf("")
 var picker by mutableStateOf<String?>(null)
 var busy by mutableStateOf(false)
 var message by mutableStateOf<String?>(null)
 var error by mutableStateOf<String?>(null)
 var index by mutableStateOf<List<CatalogEntry>>(emptyList())
 var product by mutableStateOf<Pair<JSONObject,JSONObject>?>(null)
 var sources by mutableStateOf<List<JSONObject>>(emptyList())
 private lateinit var store:WorkspaceStore
 private val catalog=MaterialCatalogRepository {resource("open_filaments_v2.json").bufferedReader()}
 init {scope.launch {busy=true;try {
  val loaded=withContext(Dispatchers.IO) {store=SqliteWorkspaceStore(dataHome().resolve("database/workspace.sqlite")); store.load()}
  library=loaded
  index=withContext(Dispatchers.IO) {catalog.index()}
  sources=withContext(Dispatchers.IO) {JSONObject(resource("filament_sources_v2.json").bufferedReader().use {it.readText()}).array("sources")}
 }catch(e:Exception){loadFailed=true;error="Could not load workspace: ${e.message}"}finally{busy=false}}}
 fun exportBackup(path:java.nio.file.Path) {
  if(busy)return
  scope.launch {busy=true;try {
   withContext(Dispatchers.IO) {(store as SqliteWorkspaceStore).exportBackup(path)}
   message="Backup exported"
  }catch(e:Exception){error="Backup export failed: ${e.message}"}finally{busy=false}}
 }
 fun openRecoveryFolder() {
  try {val folder=dataHome().resolve("database");java.nio.file.Files.createDirectories(folder);java.awt.Desktop.getDesktop().open(folder.toFile())}
  catch(e:Exception){error="Could not open recovery folder: ${e.message}"}
 }
 fun entries(kind:String)=library?.array(kind).orEmpty()
 fun newQuote(){library?.let {draft=Draft(Defaults.quote(it));screen="New Estimate";message=null}}
 fun useMaterial(m:JSONObject){if(draft==null)newQuote();draft?.let{d->d.change{Defaults.selectMaterial(d.json,m)}};screen="New Estimate";editor=null;product=null}
 fun open(q:JSONObject){draft=Draft(q.copy());screen="New Estimate"}
 fun edit(k:String,o:JSONObject){error=null;kind=k;editor=Draft(o.copy())}
 fun save(k:String,o:JSONObject,done:()->Unit={editor=null}) {
  if(busy)return
  try {
   error=null;val value=o.copy();WorkspaceRepository.validate(k,value)
   if(k=="quotes") {value.decimal("expiresAt");require(value.text("projectName").isNotBlank()){ "Enter a project name" };value.put("result",PricingEngine.calculate(value.getJSONObject("input")))}
   if(k=="printers")value.optJSONObject("externalProfile")?.put("userOverride",true)
   if(k=="filaments")value.optJSONObject("catalogSnapshot")?.put("userOverride",true)
   val next=checkNotNull(library).copy()
   if(k=="settings")next.put(k,value) else {
    val items=next.array(k).toMutableList();val i=items.indexOfFirst {it.text("id")==value.text("id")}
    if(i>=0)items[i]=value else items.add(0,value)
    next.put(k,array(items))
   }
   commit(next,done)
  }catch(e:Exception){error=e.message}
 }
 private fun commit(next:JSONObject,done:()->Unit){scope.launch{busy=true;try{withContext(Dispatchers.IO){store.save(next)};library=next;message="Saved";done()}catch(e:Exception){error="Save failed: ${e.message}"}finally{busy=false}}}
 fun saveQuote(){draft?.let{save("quotes",it.json){message="Quote saved"}}}
 fun delete(k:String,id:String){val next=checkNotNull(library).copy();next.put(k,array(next.array(k).filterNot{it.text("id")==id}));commit(next){editor=null}}
 fun choose(o:JSONObject){draft?.let{d->d.change{when(picker){
  "printers"->Defaults.selectPrinter(d.json,o)
  "filaments"->Defaults.selectMaterial(d.json,o)
  "presets"->{d.json.put("preset",o.copy());val i=d.json.getJSONObject("input");i.put("pricingMode",o.text("mode")).put("profitRate",o.decimal("rate"));listOf("machineRate","laborRate","minimumCharge","materialMultiplier","rushMultiplier").forEach{k->i.put(k,o.decimal(k))}}
 }}};picker=null}
 fun showProduct(id:String){scope.launch{busy=true;try{product=withContext(Dispatchers.IO){catalog.product(id)}}catch(e:Exception){error=e.message}finally{busy=false}}}
}
