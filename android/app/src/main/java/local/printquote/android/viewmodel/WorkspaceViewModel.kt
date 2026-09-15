package local.printquote.android.viewmodel

import android.app.Application
import androidx.compose.runtime.*
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.runInterruptible
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.withContext
import local.printquote.android.data.*
import local.printquote.android.model.*
import local.printquote.android.pricing.PricingEngine
import org.json.JSONObject
import java.io.File

class Draft(val json: JSONObject) {
    var expiryText by mutableStateOf<String?>(null)
    var expiryValid by mutableStateOf(true)
    var revision by mutableIntStateOf(0)
    fun change(action:()->Unit) { action(); revision++ }
}

class WorkspaceViewModel(app:Application) : AndroidViewModel(app) {
    private val repository=WorkspaceRepository(File(app.filesDir,"workspace-v2.json")) { name -> app.assets.open(name).bufferedReader().use { it.readText() } }
    private val writeMutex=Mutex()
    private val journal=DraftJournal(File(app.filesDir,"recovery-v4"))
    var recoveredDrafts by mutableStateOf<List<JSONObject>>(emptyList())
    var autosaveStatus by mutableStateOf("")
    var catalogStage by mutableStateOf("Loading filament library…")
 var catalogLoading by mutableStateOf(false)
    private val catalog=MaterialCatalogRepository { app.assets.open("open_filaments_v2.json").bufferedReader() }
    var library by mutableStateOf<JSONObject?>(null); private set
    var catalogIndex by mutableStateOf<List<CatalogEntry>>(emptyList()); private set
    private val preferences=app.getSharedPreferences("v4-discovery",0)
 var entityFavorites by mutableStateOf(preferences.getStringSet("entityFavorites",emptySet())!!.toSet())
 var entityRecent by mutableStateOf(preferences.all.filterKeys{it.startsWith("entityRecent:")}.mapKeys{it.key.removePrefix("entityRecent:")}.mapValues{it.value as? Long ?: 0L})
 private fun entityKey(kind:String,id:String)=kind+":"+java.util.UUID.nameUUIDFromBytes(id.toByteArray(Charsets.UTF_8)).toString()
 fun isFavorite(kind:String,id:String)=if(kind=="filaments")id in favoriteFilaments else entityKey(kind,id) in entityFavorites
 fun favoriteEntity(kind:String,id:String){if(kind=="filaments"){favoriteFilament(id);return};val key=entityKey(kind,id);entityFavorites=if(key in entityFavorites)entityFavorites-key else entityFavorites+key;preferences.edit().putStringSet("entityFavorites",entityFavorites).apply()}
 fun usedEntity(kind:String,id:String){val key=entityKey(kind,id);val time=System.currentTimeMillis();entityRecent=entityRecent+(key to time);preferences.edit().putLong("entityRecent:"+key,time).apply()}
 fun discoveryOrder(kind:String,rows:List<JSONObject>)=rows.sortedWith(compareByDescending<JSONObject>{isFavorite(kind,it.text("id"))}.thenByDescending{entityRecent[entityKey(kind,it.text("id"))] ?: 0L})
 fun sortedRecords(kind:String,rows:List<JSONObject>,sort:String)=sortDiscoveryRecords(kind,rows,sort,rows.filter{isFavorite(kind,it.text("id"))}.map{it.text("id")}.toSet(),rows.associate{it.text("id") to (if(kind=="filaments")recentFilaments[it.text("id")] ?: 0L else entityRecent[entityKey(kind,it.text("id"))] ?: 0L)})
 fun quickQuoteFor(printer:JSONObject){
  if((quote?.revision ?: 0)>0 && autosaveStatus!="Saved"){error="The current quote has unsaved edits. Save it before starting another quote.";return}
  val value=Defaults.quote(checkNotNull(library));Defaults.selectPrinter(value,printer);quote=Draft(value);screen="New Estimate";editor=null;picker=null;usedEntity("printers",printer.text("id"))
 }
 fun duplicateEntity(kind:String,value:JSONObject){
  val copy=value.copy().put("id",java.util.UUID.randomUUID().toString())
  if(kind=="quotes"){copy.put("number","PQ-"+java.util.UUID.randomUUID().toString().take(8).uppercase()).put("status","draft").put("createdAt",swiftNow()).put("expiresAt",swiftNow()+((library?.optJSONObject("settings")?.number("expirationDays",30) ?: 30)*86400));openQuote(copy)}
  else {val key=when(kind){"printers"->"model";"filaments"->"productName";else->"name"};copy.put(key,copy.text(key)+" copy");edit(kind,copy)}
 }
    var favoriteFilaments by mutableStateOf(preferences.getStringSet("favorites",emptySet())!!.toSet())
    var recentFilaments by mutableStateOf(preferences.all.filterKeys{it.startsWith("recent:")}.mapKeys{it.key.removePrefix("recent:")}.mapValues{(it.value as? Long) ?: 0L})
    var catalogQuery by mutableStateOf(CatalogQuery())
    var catalogPage by mutableStateOf(CatalogPage(emptyList(),0,0))
    var catalogDiagnostics by mutableStateOf(CatalogDiagnostics())
    var catalogSearching by mutableStateOf(false)
    var catalogBrands by mutableStateOf<List<String>>(emptyList())
    var catalogFamilies by mutableStateOf<List<String>>(emptyList())
    var selectedCatalogVariant:String?=null;var selectedCatalogSize:String?=null
    private var searchEngine:FilamentCatalogIndex?=null
    private var searchJob:Job?=null
 private var catalogJob:Job?=null
    var sources by mutableStateOf<List<JSONObject>>(emptyList()); private set
    var technical by mutableStateOf<List<JSONObject>>(emptyList()); private set
    var error by mutableStateOf<String?>(null)
    var busy by mutableStateOf(false); private set
    var screen by mutableStateOf("Dashboard")
    var editor by mutableStateOf<Draft?>(null)
    var editorKind by mutableStateOf("")
    var quote by mutableStateOf<Draft?>(null)
    var picker by mutableStateOf<String?>(null)
    var materialPickerGroup by mutableStateOf("all")
    var product by mutableStateOf<Pair<JSONObject,JSONObject>?>(null)
    var savedMessage by mutableStateOf<String?>(null)
    init { reload() }
    fun reload() {
        viewModelScope.launch {
            busy=true
            try {
                val result=withContext(Dispatchers.IO) {
                    val app=getApplication<Application>()
                    val l=repository.load()
                    val s=JSONObject(app.assets.open("filament_sources_v2.json").bufferedReader().use { it.readText() }).array("sources")
                    val t=JSONObject(app.assets.open("orca_profiles_v2.json").bufferedReader().use { it.readText() }).array("profiles")
                    Triple(l,s,t)
                }
                library=result.first; sources=result.second; technical=result.third
                busy=false;refreshFilaments()
                val recovery=withContext(Dispatchers.IO){journal.scan()};recoveredDrafts=recovery.drafts;if(recovery.issues.isNotEmpty())error="Some recovery files could not be read and are preserved: "+recovery.issues.joinToString("\n")

            } catch(e:Exception) { error="Unable to load workspace: ${e.message}" } finally { busy=false }
        }
    }
    fun refreshFilaments(){
  if(catalogLoading)return
  catalogJob=viewModelScope.launch{catalogLoading=true
   try{
    val existing=catalogIndex.map{it.id}.toSet()
    catalogStage="Reading and normalizing offline filament source…"
    val fresh=runInterruptible(Dispatchers.IO){catalog.index()}
    catalogStage="Building search index for ${fresh.size} spool options…"
    val engine=runInterruptible(Dispatchers.Default){FilamentCatalogIndex(fresh)}
    catalogIndex=fresh;searchEngine=engine
    catalogDiagnostics=catalog.diagnostics.copy(inserted=fresh.count{it.id !in existing},updated=fresh.count{it.id in existing})
    catalogBrands=engine.manufacturers;catalogFamilies=engine.materialFamilies;catalogStage="Offline catalog ready";searchCatalog(catalogQuery);savedMessage="Local filament index refreshed"
   }catch(e:CancellationException){catalogStage="Refresh canceled; existing catalog retained.";savedMessage="Refresh canceled. Existing local catalog remains available.";throw e}
   catch(e:Exception){catalogStage="Filament refresh failed; existing catalog retained. ${e.message}";error="Filament database could not be refreshed. Existing local library remains available. Technical details: ${e.message}"}
   finally{catalogLoading=false}
  }
 }
 var printerLoading by mutableStateOf(false)
 var printerStatus by mutableStateOf("Offline printer profiles")
 private var printerJob:Job?=null
 fun refreshPrinters(){if(printerLoading)return;printerJob=viewModelScope.launch{printerLoading=true;printerStatus="Reading offline printer profiles…";try{
  val profiles=runInterruptible(Dispatchers.IO){repository.printerCatalog()}
  val next=checkNotNull(library).copy();val existing=next.array("printers");val ids=existing.map{it.text("id").lowercase()}.toMutableSet();val added=profiles.filter{ids.add(it.text("id").lowercase())}
  next.put("printers",array(existing+added));commit(next){printerStatus="Printer catalog validated; ${added.size} new profiles. Existing configurations retained.";savedMessage="Printer database refreshed"}
 }catch(e:CancellationException){printerStatus="Printer refresh canceled; existing profiles retained.";throw e}catch(e:Exception){printerStatus="Printer refresh failed; existing profiles retained.";error="Printer data could not be refreshed: ${e.message}"}finally{printerLoading=false}}}
 fun cancelPrinterRefresh(){printerJob?.cancel()}
 fun cancelCatalogRefresh(){catalogJob?.cancel()}

    suspend fun autosave(text:String){autosaveStatus="Saving…";try{withContext(Dispatchers.IO){journal.write(text)};delay(800);val value=JSONObject(text);WorkspaceRepository.validate("quotes",value);value.put("result",PricingEngine.calculate(value.getJSONObject("input")));withContext(NonCancellable){writeMutex.withLock{val next=checkNotNull(library).copy();val rows=next.array("quotes").filterNot{it.text("id")==value.text("id")};next.put("quotes",array(listOf(value)+rows));withContext(Dispatchers.IO){repository.save(next)};library=next;autosaveStatus="Saved"}}}catch(e:CancellationException){throw e}catch(e:Exception){autosaveStatus="Save failed — draft retained: ${e.message}"}}
    fun discardRecovery(id:String){viewModelScope.launch{try{withContext(Dispatchers.IO){journal.discard(id)};recoveredDrafts=recoveredDrafts.filterNot{it.text("id")==id}}catch(e:Exception){error=e.message}}}
    fun searchCatalog(query:CatalogQuery) {
        catalogQuery=query;searchJob?.cancel();catalogSearching=true
        searchJob=viewModelScope.launch {try{delay(250);val page=withContext(Dispatchers.Default){searchEngine?.search(query,favoriteFilaments,recentFilaments,entries("filaments").associate{it.text("id") to it.decimal("pricePerKG").toDouble()})};if(page!=null)catalogPage=page}catch(_:CancellationException){return@launch}finally{catalogSearching=false}}
    }
    fun favoriteFilament(id:String) {
        favoriteFilaments=if(id in favoriteFilaments)favoriteFilaments-id else favoriteFilaments+id
        preferences.edit().putStringSet("favorites",favoriteFilaments).apply();searchCatalog(catalogQuery)
    }
    fun useRecentMaterial(id:String){usedEntity("filaments",id);val time=System.currentTimeMillis();recentFilaments=recentFilaments+(id to time);preferences.edit().putLong("recent:"+id,time).apply()}
    fun entries(kind:String)=library?.array(kind) ?: emptyList()
    fun edit(kind:String,value:JSONObject) { usedEntity(kind,value.text("id")); editorKind=kind; editor=Draft(value.copy()); savedMessage=null }
    fun newQuote() { quote=Draft(Defaults.quote(checkNotNull(library))); screen="New Estimate"; savedMessage=null }
    fun openQuote(q:JSONObject) { usedEntity("quotes",q.text("id"));usedEntity("customers",q.text("customer")); quote=Draft(q.copy()); screen="New Estimate"; savedMessage=null }
    fun selectPrinter(p:JSONObject) {usedEntity("printers",p.text("id")); quote?.let { d -> d.change { Defaults.selectPrinter(d.json,p) } }; picker=null }
    fun selectMaterial(m:JSONObject) { useRecentMaterial(m.text("id")); quote?.let { d -> d.change { Defaults.selectMaterial(d.json,m) } }; picker=null }
    fun preset(p:JSONObject) {usedEntity("presets",p.text("id")); quote?.let { d -> d.change {
        d.json.put("preset",p.copy()); val i=d.json.getJSONObject("input")
        i.put("pricingMode",p.text("mode")).put("profitRate",p.decimal("rate"))
        listOf("machineRate","laborRate","minimumCharge","materialMultiplier","rushMultiplier").forEach { i.put(it,p.decimal(it)) }
    } }; picker=null }
    private fun commit(next:JSONObject,done:()->Unit) {
        val base=checkNotNull(library).copy()
        viewModelScope.launch {withContext(NonCancellable){writeMutex.withLock{busy=true;try{val merged=mergeWorkspaceChanges(checkNotNull(library),base,next);withContext(Dispatchers.IO){repository.save(merged)};library=merged;savedMessage="Saved";done()}catch(e:Exception){error="Save failed; existing data remains available: ${e.message}"}finally{busy=false}}}}
    }
    fun save(kind:String,value:JSONObject,done:()->Unit={ editor=null }) {
        try {
            val copy=value.copy(); WorkspaceRepository.validate(kind,copy)
            if(kind=="quotes") copy.put("result",PricingEngine.calculate(copy.getJSONObject("input")))
            if(kind=="printers") copy.optJSONObject("externalProfile")?.put("userOverride",true)
            if(kind=="filaments") copy.optJSONObject("catalogSnapshot")?.put("userOverride",true)
            val next=checkNotNull(library).copy()
            if(kind=="settings") next.put(kind,copy) else {
                val items=next.array(kind).toMutableList(); val index=items.indexOfFirst { it.text("id")==copy.text("id") }
                if(index>=0) items[index]=copy else if(kind=="quotes") items.add(0,copy) else items.add(copy)
                next.put(kind,array(items))
            }
            commit(next,done)
        } catch(e:Exception) { error=e.message ?: "Invalid data" }
    }
    fun saveQuote() { quote?.let { d -> if(!d.expiryValid) { error="Enter a valid expiry date"; return }; save("quotes",d.json) { d.change { d.json.put("result",PricingEngine.calculate(d.json.getJSONObject("input"))) }; discardRecovery(d.json.text("id"));screen="Quotes"; quote=null } } }
    fun delete(kind:String,id:String) {
        val next=checkNotNull(library).copy(); next.put(kind,array(next.array(kind).filterNot { it.text("id")==id })); commit(next) { editor=null }
    }
    fun showProduct(id:String) {
        if(busy) return
        viewModelScope.launch { busy=true; try { product=withContext(Dispatchers.IO) { catalog.product(id) } } catch(e:Exception) { error=e.message } finally { busy=false } }
    }
}
