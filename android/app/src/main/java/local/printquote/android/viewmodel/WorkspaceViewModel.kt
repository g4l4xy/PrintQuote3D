package local.printquote.android.viewmodel

import android.app.Application
import androidx.compose.runtime.*
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
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
    private val catalog=MaterialCatalogRepository { app.assets.open("open_filaments_v2.json").bufferedReader() }
    var library by mutableStateOf<JSONObject?>(null); private set
    var catalogIndex by mutableStateOf<List<CatalogEntry>>(emptyList()); private set
    var sources by mutableStateOf<List<JSONObject>>(emptyList()); private set
    var technical by mutableStateOf<List<JSONObject>>(emptyList()); private set
    var error by mutableStateOf<String?>(null)
    var busy by mutableStateOf(false); private set
    var screen by mutableStateOf("Dashboard")
    var editor by mutableStateOf<Draft?>(null)
    var editorKind by mutableStateOf("")
    var quote by mutableStateOf<Draft?>(null)
    var picker by mutableStateOf<String?>(null)
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
                catalogIndex=withContext(Dispatchers.IO) { catalog.index() }
            } catch(e:Exception) { error="Unable to load workspace: ${e.message}" } finally { busy=false }
        }
    }
    fun entries(kind:String)=library?.array(kind) ?: emptyList()
    fun edit(kind:String,value:JSONObject) { editorKind=kind; editor=Draft(value.copy()); savedMessage=null }
    fun newQuote() { quote=Draft(Defaults.quote(checkNotNull(library))); screen="New Estimate"; savedMessage=null }
    fun openQuote(q:JSONObject) { quote=Draft(q.copy()); screen="New Estimate"; savedMessage=null }
    fun selectPrinter(p:JSONObject) { quote?.let { d -> d.change { Defaults.selectPrinter(d.json,p) } }; picker=null }
    fun selectMaterial(m:JSONObject) { quote?.let { d -> d.change { Defaults.selectMaterial(d.json,m) } }; picker=null }
    fun preset(p:JSONObject) { quote?.let { d -> d.change {
        d.json.put("preset",p.copy()); val i=d.json.getJSONObject("input")
        i.put("pricingMode",p.text("mode")).put("profitRate",p.decimal("rate"))
        listOf("machineRate","laborRate","minimumCharge","materialMultiplier","rushMultiplier").forEach { i.put(it,p.decimal(it)) }
    } }; picker=null }
    private fun commit(next:JSONObject,done:()->Unit) {
        if(busy) return
        viewModelScope.launch { busy=true; try { withContext(Dispatchers.IO) { repository.save(next) }; library=next; savedMessage="Saved"; done() } catch(e:Exception) { error="Save failed: ${e.message}" } finally { busy=false } }
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
    fun saveQuote() { quote?.let { d -> if(!d.expiryValid) { error="Enter a valid expiry date"; return }; save("quotes",d.json) { d.change { d.json.put("result",PricingEngine.calculate(d.json.getJSONObject("input"))) }; screen="Quotes"; quote=null } } }
    fun delete(kind:String,id:String) {
        val next=checkNotNull(library).copy(); next.put(kind,array(next.array(kind).filterNot { it.text("id")==id })); commit(next) { editor=null }
    }
    fun showProduct(id:String) {
        if(busy) return
        viewModelScope.launch { busy=true; try { product=withContext(Dispatchers.IO) { catalog.product(id) } } catch(e:Exception) { error=e.message } finally { busy=false } }
    }
}
