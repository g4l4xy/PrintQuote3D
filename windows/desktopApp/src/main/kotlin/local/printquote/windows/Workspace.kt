package local.printquote.windows
import androidx.compose.runtime.*
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import local.printquote.android.data.mergeWorkspaceChanges
import local.printquote.android.data.DraftJournal
import local.printquote.android.data.sortDiscoveryRecords
import local.printquote.android.data.CatalogQuery
import local.printquote.android.data.CatalogPage
import local.printquote.android.data.CatalogDiagnostics
import local.printquote.android.data.FilamentCatalogIndex
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
 private val writeMutex=Mutex()
 private val journal=DraftJournal(dataHome().resolve("recovery-v4").toFile())
 var recoveredDrafts by mutableStateOf<List<JSONObject>>(emptyList())
 var autosaveStatus by mutableStateOf("")
 var commandPalette by mutableStateOf(false)
 private val preferences=java.util.prefs.Preferences.userRoot().node("PrintQuote3D/V4")
 var entityFavorites by mutableStateOf(preferences.keys().filter{it.startsWith("entityFavorite:") && preferences.getBoolean(it,false)}.map{it.removePrefix("entityFavorite:")}.toSet())
 var entityRecent by mutableStateOf(preferences.keys().filter{it.startsWith("entityRecent:")}.associate{it.removePrefix("entityRecent:") to preferences.getLong(it,0L)})
 private fun entityKey(kind:String,id:String)=kind+":"+java.util.UUID.nameUUIDFromBytes(id.toByteArray(Charsets.UTF_8)).toString()
 fun isFavorite(kind:String,id:String)=if(kind=="filaments")id in favoriteFilaments else entityKey(kind,id) in entityFavorites
 fun favoriteEntity(kind:String,id:String){if(kind=="filaments"){favoriteFilament(id);return};val key=entityKey(kind,id);entityFavorites=if(key in entityFavorites)entityFavorites-key else entityFavorites+key;preferences.putBoolean("entityFavorite:"+key,key in entityFavorites)}
 fun usedEntity(kind:String,id:String){val key=entityKey(kind,id);val time=System.currentTimeMillis();entityRecent=entityRecent+(key to time);preferences.putLong("entityRecent:"+key,time)}
 fun discoveryOrder(kind:String,rows:List<JSONObject>)=rows.sortedWith(compareByDescending<JSONObject>{isFavorite(kind,it.text("id"))}.thenByDescending{entityRecent[entityKey(kind,it.text("id"))] ?: 0L})
 fun sortedRecords(kind:String,rows:List<JSONObject>,sort:String)=sortDiscoveryRecords(kind,rows,sort,rows.filter{isFavorite(kind,it.text("id"))}.map{it.text("id")}.toSet(),rows.associate{it.text("id") to (if(kind=="filaments")recentFilaments[it.text("id")] ?: 0L else entityRecent[entityKey(kind,it.text("id"))] ?: 0L)})
 fun quickQuoteFor(printer:JSONObject){
  if((draft?.revision ?: 0)>0 && autosaveStatus!="Saved"){error="The current quote has unsaved edits. Save it before starting another quote.";return}
  val value=Defaults.quote(checkNotNull(library));Defaults.selectPrinter(value,printer);draft=Draft(value);screen="New Estimate";editor=null;picker=null;usedEntity("printers",printer.text("id"))
 }
 fun duplicateEntity(kind:String,value:JSONObject){
  val copy=value.copy().put("id",java.util.UUID.randomUUID().toString())
  if(kind=="quotes"){copy.put("number","PQ-"+java.util.UUID.randomUUID().toString().take(8).uppercase()).put("status","draft").put("createdAt",swiftNow()).put("expiresAt",swiftNow()+((library?.optJSONObject("settings")?.number("expirationDays",30) ?: 30)*86400));open(copy)}
  else {val key=when(kind){"printers"->"model";"filaments"->"productName";else->"name"};copy.put(key,copy.text(key)+" copy");edit(kind,copy)}
 }
 var favoriteFilaments by mutableStateOf(preferences.keys().filter{it.startsWith("favorite-") && preferences.getBoolean(it,false)}.map{it.removePrefix("favorite-")}.toSet())
 var recentFilaments by mutableStateOf(preferences.keys().filter{it.startsWith("recent-")}.associate{it.removePrefix("recent-") to preferences.getLong(it,0)})
 var catalogStage by mutableStateOf("Loading filament library…")
 var catalogLoading by mutableStateOf(false)
 var catalogQuery by mutableStateOf(CatalogQuery())
 var catalogPage by mutableStateOf(CatalogPage(emptyList(),0,0))
 var catalogDiagnostics by mutableStateOf(CatalogDiagnostics())
 var catalogBrands by mutableStateOf<List<String>>(emptyList())
 var catalogFamilies by mutableStateOf<List<String>>(emptyList())
 var selectedCatalogVariant:String?=null;var selectedCatalogSize:String?=null
 private var searchEngine:FilamentCatalogIndex?=null
 private var searchJob:Job?=null
 private var catalogJob:Job?=null
 private val catalog=MaterialCatalogRepository {resource("open_filaments_v2.json").bufferedReader()}
 init {scope.launch {busy=true;try {
  val loaded=withContext(Dispatchers.IO) {store=SqliteWorkspaceStore(dataHome().resolve("database/workspace.sqlite")); store.load()}
  library=loaded
  busy=false;refreshFilaments();val recovery=withContext(Dispatchers.IO){journal.scan()};recoveredDrafts=recovery.drafts;if(recovery.issues.isNotEmpty())error="Some recovery files could not be read and are preserved: "+recovery.issues.joinToString("\n")
  sources=withContext(Dispatchers.IO) {JSONObject(resource("filament_sources_v2.json").bufferedReader().use {it.readText()}).array("sources")}
 }catch(e:Exception){loadFailed=true;error="Could not load workspace: ${e.message}"}finally{busy=false}}}
 suspend fun autosave(text:String){autosaveStatus="Saving…";try{withContext(Dispatchers.IO){journal.write(text)};delay(800);val value=JSONObject(text);WorkspaceRepository.validate("quotes",value);value.put("result",PricingEngine.calculate(value.getJSONObject("input")));withContext(NonCancellable){writeMutex.withLock{val next=checkNotNull(library).copy();val rows=next.array("quotes").filterNot{it.text("id")==value.text("id")};next.put("quotes",array(listOf(value)+rows));withContext(Dispatchers.IO){store.save(next)};library=next;autosaveStatus="Saved"}}}catch(e:CancellationException){throw e}catch(e:Exception){autosaveStatus="Save failed — recovery retained: ${e.message}"}}
 fun discardRecovery(id:String){scope.launch{try{withContext(Dispatchers.IO){journal.discard(id)};recoveredDrafts=recoveredDrafts.filterNot{it.text("id")==id}}catch(e:Exception){error=e.message}}}
 fun searchCatalog(query:CatalogQuery){catalogQuery=query;searchJob?.cancel();searchJob=scope.launch{delay(250);val result=withContext(Dispatchers.Default){searchEngine?.search(query,favoriteFilaments,recentFilaments,entries("filaments").associate{it.text("id") to it.decimal("pricePerKG").toDouble()})};if(result!=null)catalogPage=result}}
 fun favoriteFilament(id:String){favoriteFilaments=if(id in favoriteFilaments)favoriteFilaments-id else favoriteFilaments+id;preferences.putBoolean("favorite-"+id,id in favoriteFilaments);searchCatalog(catalogQuery)}
 fun refreshFilaments(){
  if(catalogLoading)return
  catalogJob=scope.launch{catalogLoading=true
   try{
    val existing=index.map{it.id}.toSet()
    catalogStage="Reading and normalizing offline filament source…"
    val fresh=runInterruptible(Dispatchers.IO){catalog.index()}
    catalogStage="Building search index for ${fresh.size} spool options…"
    val engine=runInterruptible(Dispatchers.Default){FilamentCatalogIndex(fresh)}
    index=fresh;searchEngine=engine
    catalogDiagnostics=catalog.diagnostics.copy(inserted=fresh.count{it.id !in existing},updated=fresh.count{it.id in existing})
    catalogBrands=engine.manufacturers;catalogFamilies=engine.materialFamilies;catalogStage="Offline catalog ready";searchCatalog(catalogQuery);message="Local filament index refreshed"
   }catch(e:CancellationException){catalogStage="Refresh canceled; existing catalog retained.";message="Refresh canceled. Existing local catalog remains available.";throw e}
   catch(e:Exception){catalogStage="Filament refresh failed; existing catalog retained. ${e.message}";error="Filament database could not be refreshed. Existing local library remains available. Technical details: ${e.message}"}
   finally{catalogLoading=false}
  }
 }
 var printerLoading by mutableStateOf(false)
 var printerStatus by mutableStateOf("Offline printer profiles")
 private var printerJob:Job?=null
 fun refreshPrinters(){if(printerLoading)return;printerJob=scope.launch{printerLoading=true;printerStatus="Reading offline printer profiles…";try{
  val profiles=runInterruptible(Dispatchers.IO){WorkspaceRepository.importedPrinters {resource(it).bufferedReader().use{r->r.readText()}}}
  val next=checkNotNull(library).copy();val existing=next.array("printers");val ids=existing.map{it.text("id").lowercase()}.toMutableSet();val added=profiles.filter{ids.add(it.text("id").lowercase())}
  next.put("printers",array(existing+added));commit(next){printerStatus="Printer catalog validated; ${added.size} new profiles. Existing configurations retained.";message="Printer database refreshed"}
 }catch(e:CancellationException){printerStatus="Printer refresh canceled; existing profiles retained.";throw e}catch(e:Exception){printerStatus="Printer refresh failed; existing profiles retained.";error="Printer data could not be refreshed: ${e.message}"}finally{printerLoading=false}}}
 fun cancelPrinterRefresh(){printerJob?.cancel()}
 fun cancelCatalogRefresh(){catalogJob?.cancel()}

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
 fun useMaterial(m:JSONObject){usedEntity("filaments",m.text("id"));val time=System.currentTimeMillis();recentFilaments=recentFilaments+(m.text("id") to time);preferences.putLong("recent-"+m.text("id"),time);if(draft==null)newQuote();draft?.let{d->d.change{Defaults.selectMaterial(d.json,m)}};screen="New Estimate";editor=null;product=null;picker=null}
 fun open(q:JSONObject){usedEntity("quotes",q.text("id"));usedEntity("customers",q.text("customer"));draft=Draft(q.copy());screen="New Estimate"}
 fun edit(k:String,o:JSONObject){usedEntity(k,o.text("id"));error=null;kind=k;editor=Draft(o.copy())}
 fun save(k:String,o:JSONObject,done:()->Unit={editor=null}) {
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
 private fun commit(next:JSONObject,done:()->Unit){val base=checkNotNull(library).copy();scope.launch{withContext(NonCancellable){writeMutex.withLock{busy=true;try{val merged=mergeWorkspaceChanges(checkNotNull(library),base,next);withContext(Dispatchers.IO){store.save(merged)};library=merged;message="Saved";done()}catch(e:Exception){error="Save failed: ${e.message}"}finally{busy=false}}}}}
 fun saveQuote(){draft?.let{save("quotes",it.json){discardRecovery(it.json.text("id"));message="Quote saved"}}}
 fun delete(k:String,id:String){val next=checkNotNull(library).copy();next.put(k,array(next.array(k).filterNot{it.text("id")==id}));commit(next){editor=null}}
 fun choose(o:JSONObject){picker?.let{usedEntity(it,o.text("id"))};draft?.let{d->d.change{when(picker){
  "printers"->Defaults.selectPrinter(d.json,o)
  "filaments"->Defaults.selectMaterial(d.json,o)
  "presets"->{d.json.put("preset",o.copy());val i=d.json.getJSONObject("input");i.put("pricingMode",o.text("mode")).put("profitRate",o.decimal("rate"));listOf("machineRate","laborRate","minimumCharge","materialMultiplier","rushMultiplier").forEach{k->i.put(k,o.decimal(k))}}
 }}};picker=null}
 fun showProduct(id:String){scope.launch{busy=true;try{product=withContext(Dispatchers.IO){catalog.product(id)}}catch(e:Exception){error=e.message}finally{busy=false}}}
}
