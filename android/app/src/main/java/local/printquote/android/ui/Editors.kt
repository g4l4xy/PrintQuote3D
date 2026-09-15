package local.printquote.android.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.clickable
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.ui.Alignment
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import local.printquote.android.model.*
import local.printquote.android.viewmodel.Draft
import org.json.JSONObject
import org.json.JSONArray

val LocalSettingsSearch=compositionLocalOf { "" }
fun label(key:String)=key.replace(Regex("([a-z])([A-Z])"),"$1 $2").replace("MM"," (mm)").replace("KG","kg").replaceFirstChar { it.uppercase() }
@Composable fun Heading(text:String) { Text(text,style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(top=12.dp)) }
@Composable fun Fields(d:Draft,o:JSONObject,keys:List<String>,numeric:Boolean=true) { keys.forEach { Field(d,o,it,label(it),numeric) } }
@Composable fun Field(d:Draft,o:JSONObject,key:String,title:String=label(key),numeric:Boolean=false,optional:Boolean=false) {
    val filter=LocalSettingsSearch.current
    if(filter.isNotBlank() && !(title+" "+key).contains(filter,true))return
    d.revision
    val stored=o.text(key)
    var value by remember(o,key) { mutableStateOf(stored) }
    LaunchedEffect(stored) {
        val equivalent=numeric && value.toBigDecimalOrNull()?.let { a -> stored.toBigDecimalOrNull()?.let { a.compareTo(it)==0 } }==true
        if(value!=stored && !equivalent) value=stored
    }
    val invalid=numeric && value.isNotEmpty() && value.toBigDecimalOrNull()==null
    OutlinedTextField(value=value,onValueChange={ next -> value=next; d.change { if(optional && next.isEmpty()) o.remove(key) else o.put(key,if(numeric) next.toBigDecimalOrNull() ?: next else next) } },label={Text(title)},
        modifier=Modifier.fillMaxWidth(),isError=invalid,singleLine=key!="notes",keyboardOptions=KeyboardOptions(keyboardType=if(numeric) KeyboardType.Decimal else KeyboardType.Text))
}
@Composable fun Toggle(d:Draft,o:JSONObject,key:String,title:String=label(key)) {
    d.revision
    Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) { Text(title,modifier=Modifier.weight(1f)); Switch(o.optBoolean(key),onCheckedChange={d.change { o.put(key,it) }}) }
}
@Composable fun Choice(d:Draft,o:JSONObject,key:String,options:List<String>,title:String=label(key)) {
    d.revision; var open by remember { mutableStateOf(false) }
    OutlinedButton(onClick={open=true},modifier=Modifier.fillMaxWidth()) { Text("$title: ${o.text(key)}") }
    if(open) AlertDialog(onDismissRequest={open=false},title={Text(title)},text={Column(Modifier.heightIn(max=400.dp).verticalScroll(rememberScrollState())) {
        options.forEach { option -> TextButton(onClick={d.change {o.put(key,option)};open=false},modifier=Modifier.fillMaxWidth()) { Text(option) } }
    }},confirmButton={TextButton(onClick={open=false}) {Text("Close")}})
}
@Composable fun Fold(title:String,initial:Boolean=false,content:@Composable ()->Unit) {
    var expanded by rememberSaveable(title) { mutableStateOf(initial) }
    TextButton(onClick={expanded=!expanded},modifier=Modifier.fillMaxWidth()) { Text((if(expanded) "− " else "+ ")+title) }
    if(expanded) content()
}
@Composable fun StringList(d:Draft,o:JSONObject,key:String,title:String) {
    d.revision; val a=o.optJSONArray(key) ?: JSONArray()
    var text by remember(o,key) { mutableStateOf((0 until a.length()).joinToString(", ") {a.getString(it)}) }
    OutlinedTextField(text,onValueChange={value -> text=value; d.change {o.put(key,JSONArray(value.split(',').map {it.trim()}.filter {it.isNotEmpty()}))}},label={Text(title)},modifier=Modifier.fillMaxWidth())
}
@Composable fun ToolSystemFields(d:Draft,s:JSONObject) {
    d.revision
    Text("Physical toolheads are separate from feeder slots and selectable materials.",style=MaterialTheme.typography.bodySmall)
    var countOpen by remember {mutableStateOf(false)}
    OutlinedButton(onClick={countOpen=true},modifier=Modifier.fillMaxWidth()) {Text("Physical toolheads: ${s.text("availableToolheadCount","1")}")}
    if(countOpen) AlertDialog(onDismissRequest={countOpen=false},title={Text("Physical toolheads")},text={Column(Modifier.heightIn(max=320.dp).verticalScroll(rememberScrollState())) {(1..12).forEach { count -> TextButton(onClick={d.change {Defaults.resize(s,count)};countOpen=false}) {Text(count.toString())} }}},confirmButton={})
    Choice(d,s,"architecture",listOf("singleTool","singleNozzleSwitcher","idex","dualExtruder","fixedMultiNozzle","toolChanger","mixingHotend","custom"))
    Fields(d,s,listOf("simultaneousToolUseCount","filamentInputCount","feederSlotCount","maxSimultaneousMaterials","maxAutomaticSelectableMaterials"))
    Toggle(d,s,"automaticMaterialSwitching"); Toggle(d,s,"sharedNozzle")
    Fields(d,s,listOf("materialSwitchSeconds","purgeGramsPerMaterialSwitch")); Toggle(d,s,"needsReview")
    s.array("toolheads").forEach { t -> key(t.text("id")) { Fold("Tool ${t.text("index")}: ${t.text("name")}") {
        Field(d,t,"name"); Field(d,t,"nozzleDiameterMM",numeric=true)
        Choice(d,t,"nozzleMaterial",listOf("unknown","brass","hardenedSteel","stainlessSteel","tungstenCarbide","ruby","custom"))
        Field(d,t,"maxNozzleTemperatureC","Maximum nozzle temperature (°C)",true,true)
        StringList(d,t,"supportedMaterialFamilies","Supported families (comma separated)")
        Toggle(d,t,"abrasiveMaterialsAllowed");Toggle(d,t,"flexibleMaterialsAllowed")
        Fields(d,t,listOf("changeOverheadSeconds","purgeGramsPerActivation","wipeGramsPerActivation","additionalHeaterWatts","parkedHeaterWatts","maintenancePerHour","nozzleReplacementCost","nozzleLifeHours","abrasiveWearMultiplier"))
        Toggle(d,t,"needsReview")
    } } }
}
@Composable fun HardwareFields(d:Draft,h:JSONObject) {
    listOf("ratedMaximumPowerWatts","idlePowerWatts","maximumBedTemperatureC","maximumChamberTemperatureC","physicalBuildHeightMM").forEach {Field(d,h,it,numeric=true,optional=true)}
    Choice(d,h,"typicalPowerQuality",listOf("manufacturerRated","manufacturerTypical","measuredIndependent","userMeasured","estimated","unknown"))
    Toggle(d,h,"activeChamberHeating");StringList(d,h,"installedAccessories","Installed accessories (comma separated)")
    d.revision
    h.array("buildVolumeByOperatingMode").forEach { mode -> key(mode.text("id")) { Fold("Build mode: ${mode.text("mode")}") {
        Choice(d,mode,"mode",listOf("singleExtrusion","dualExtrusion","copy","mirror","toolchanger","fullPlate","belt","custom"))
        Choice(d,mode,"shape",listOf("rectangular","circular","customPolygon"))
        Fields(d,mode,listOf("widthMM","depthMM","heightMM")); Field(d,mode,"diameterMM",numeric=true,optional=true);Field(d,mode,"notes")
        TextButton(onClick={d.change {h.put("buildVolumeByOperatingMode",array(h.array("buildVolumeByOperatingMode").filterNot {it.text("id")==mode.text("id")}))}}) {Text("Remove build mode")}
    } } }
    TextButton(onClick={d.change {h.put("buildVolumeByOperatingMode",array(h.array("buildVolumeByOperatingMode")+doc("id" to uuid(),"mode" to "fullPlate","shape" to "rectangular","widthMM" to 220,"depthMM" to 220,"heightMM" to 250,"notes" to "User configured; verify usable area.")))}}) {Text("Add build mode")}
    TechnicalFields(h.optJSONObject("fieldSources"))
}
private val feederSystems=listOf("AMS","AMS Lite","AMS 2 Pro","AMS HT","ACE Pro","ACE 2 Pro","IFS","MMU","CFS","External Spool")
private fun materialSection(key:String)=when { key.contains("dry")->"Drying";listOf("nozzle","bed","flow","speed","temperature").any{key.contains(it)}->"Printing";listOf("density","strength","modulus","elongation","hardness").any{key.contains(it)}->"Mechanical Properties";else->"Overview" }
@Composable fun TechnicalFields(fields:JSONObject?) {
 if(fields!=null) for(section in listOf("Overview","Printing","Drying","Mechanical Properties")) {
  val keys=fields.keys().asSequence().filter{materialSection(it)==section}.sorted().toList()
  if(keys.isNotEmpty())Fold(section){keys.forEach{k->val f=fields.optJSONObject(k);Text("${label(k)}: ${f?.text("value") ?: fields.opt(k)}");if(f!=null)Text("Source: ${f.text("sourcePath")}",style=MaterialTheme.typography.bodySmall)}}
 }
}
@Composable fun Compatibility(fields:JSONObject?,overrides:JSONObject?=null) {
 Fold("Compatibility") {feederSystems.forEach{system->val key="compatibility_"+system.lowercase().replace(" ","_");Text("$system: ${overrides?.optString(key)?.takeIf{it.isNotBlank()} ?: fields?.optJSONObject(key)?.text("value") ?: "Unknown / not verified"}")};Text("Generic feeder claims do not establish support for a particular system.",style=MaterialTheme.typography.bodySmall)}
}
@Composable fun MaterialOverrides(d:Draft) {
 Fold("User Overrides") {
  Text("Source values stay unchanged. Clear an override to use the source value. Technical values are reference data; quote costs use your entered price.")
  val values=d.json.optJSONObject("technicalOverrides") ?: JSONObject().also{d.json.put("technicalOverrides",it)}
  val source=d.json.optJSONObject("catalogSnapshot")?.optJSONObject("fields")
  val keys=listOf("nozzle_min_c","nozzle_max_c","bed_min_c","bed_max_c","drying_temperature_c","drying_hours","flow_ratio","max_volumetric_speed","density_g_cm3","notes")+feederSystems.map{"compatibility_"+it.lowercase().replace(" ","_")}
  keys.forEach{k->val original=source?.optJSONObject(k)?.text("value") ?: "Unknown";Text("${label(k)} · Source Value: $original");Field(d,values,k,"User Override");Text("Effective Value: ${values.optString(k).takeIf{it.isNotBlank()} ?: original}",style=MaterialTheme.typography.bodySmall)}
 }
}
@Composable fun SourceFields(d:Draft,o:JSONObject) {
    val source=o.optJSONObject("source") ?: source().also {o.put("source",it)}
    Fold("Source and provenance") { Fields(d,source,listOf("name","url","sourceType","notes"),false)
        o.optJSONObject("externalProfile")?.let { Text("Upstream: ${it.text("repositoryURL")}\n${it.text("sourcePath")}\nCommit: ${it.text("commitSHA")}",style=MaterialTheme.typography.bodySmall) }
        o.optJSONObject("catalogSnapshot")?.let { Text("${it.text("sourceName")} · ${it.text("sourceLicense")} · ${it.text("upstreamVersion")}\nRetrieved ${it.text("retrievedAt")}",style=MaterialTheme.typography.bodySmall); TechnicalFields(it.optJSONObject("fields")) }
    }
}
@Composable fun LibraryEditor(d:Draft,kind:String) {
    d.revision; val o=d.json
    when(kind) {
        "printers" -> {
            if(o.optJSONObject("externalProfile")!=null) Text("Imported profile: review tool setup and enter actual operating costs.",color=MaterialTheme.colorScheme.primary)
            Fields(d,o,listOf("manufacturer","model"),false)
            Fields(d,o,listOf("buildVolumeXMM","buildVolumeYMM","buildVolumeZMM","typicalPowerWatts","machineRate","maintenanceRate"))
            Field(d,o,"multiMaterialSystem")
            Fold("Hardware and usable build volumes") { val h=o.optJSONObject("hardware") ?: Defaults.hardware().also {o.put("hardware",it)}; HardwareFields(d,h) }
            Fold("Tools and material switching") { val s=o.optJSONObject("toolSystem") ?: Defaults.system().also {o.put("toolSystem",it)}; ToolSystemFields(d,s) }
            SourceFields(d,o)
        }
        "filaments" -> {
            Fields(d,o,listOf("manufacturer","productName","materialFamily","colorName"),false)
            Fields(d,o,listOf("diameterMM","netWeightGrams","pricePerKG"))
            MaterialOverrides(d)
            Compatibility(o.optJSONObject("catalogSnapshot")?.optJSONObject("fields"),o.optJSONObject("technicalOverrides"))
            Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {Text("Track stock");Switch(o.optJSONObject("stock")!=null,onCheckedChange={enabled->d.change {if(enabled) o.put("stock",doc("spoolCount" to 0,"remainingGrams" to 0,"location" to "","notes" to "")) else o.remove("stock")}})}
            o.optJSONObject("stock")?.let {Fields(d,it,listOf("spoolCount","remainingGrams"));Fields(d,it,listOf("location","notes"),false);Text("Saving a quote does not consume stock.",style=MaterialTheme.typography.bodySmall)}
            SourceFields(d,o)
        }
        "presets" -> {
            Field(d,o,"name");Choice(d,o,"mode",listOf("margin","markup"));Text("Enter rates as decimals: 0.40 = 40%.")
            Fields(d,o,listOf("rate","materialMultiplier","machineRate","laborRate","minimumCharge","rushMultiplier"))
        }
        "settings" -> {
            Field(d,o,"businessName");Choice(d,o,"currency",listOf("USD","CAD","EUR","GBP","AUD"))
            Field(d,o,"taxRate","Default tax rate (0.08 = 8%)",true);Field(d,o,"electricityRate","Electricity per kWh",true);Field(d,o,"expirationDays","Quote validity (1–365 days)",true)
            Text("Defaults apply to new quotes. Saved quotes retain their original rates and snapshots.")
        }
    }
}

data class ComparisonRow(val id:String,val values:Map<String,String>)
private data class ComparisonStorage(val read:()->String,val write:(String)->Unit)
@Composable private fun comparisonStorage(key:String):ComparisonStorage {
val prefs=androidx.compose.ui.platform.LocalContext.current.getSharedPreferences("v4-comparison",0);return ComparisonStorage({prefs.getString(key,"") ?: ""},{prefs.edit().putString(key,it).apply()})
}
@Composable fun ComparisonMode(key:String):Boolean {
 val store=comparisonStorage(key+".mode")
 var table by remember(key){mutableStateOf(store.read()=="table")}
 Row {FilterChip(!table,onClick={table=false;store.write("cards")},label={Text("Cards")});FilterChip(table,onClick={table=true;store.write("table")},label={Text("Table")})}
 return table
}
fun comparisonRow(value:JSONObject,kind:String):ComparisonRow {
 val title=when(kind){"printers"->value.text("manufacturer")+" "+value.text("model");"filaments"->value.text("manufacturer")+" "+value.text("productName");else->value.text("name")}
 return ComparisonRow(value.text("id"),mapOf("Name" to title,"Manufacturer" to value.text("manufacturer"),"Material" to value.text("materialFamily"),"Color" to value.text("colorName"),"Build volume" to "${value.text("buildVolumeXMM")} × ${value.text("buildVolumeYMM")} × ${value.text("buildVolumeZMM")} mm","Toolheads" to (value.optJSONObject("toolSystem")?.text("availableToolheadCount") ?: "Unknown"),"Price / kg" to value.text("pricePerKG"),"Stock (g)" to (value.optJSONObject("stock")?.text("remainingGrams") ?: ""),"Nickname" to value.text("productName"),"Notes" to (value.optJSONObject("stock")?.text("notes") ?: "")))
}
@Composable fun ComparisonTable(key:String,columns:List<String>,records:List<ComparisonRow>,onOpen:(String)->Unit,onEdit:((String,String,String)->Unit)?=null) {
 val store=comparisonStorage(key+".columns")
 val saved=remember(key){runCatching{JSONObject(store.read())}.getOrDefault(JSONObject())}
 var order by remember(key){mutableStateOf(saved.optJSONArray("order")?.let{a->(0 until a.length()).map{a.getString(it)}.filter{it in columns}}?.takeIf{it.isNotEmpty()} ?: columns)}
 var hidden by remember(key){mutableStateOf(saved.optJSONArray("hidden")?.let{a->(0 until a.length()).map{a.getString(it)}.toSet()} ?: emptySet<String>())}
 var widths by remember(key){mutableStateOf(saved.optJSONObject("widths")?.let{o->o.keys().asSequence().associateWith{o.getDouble(it).toFloat()}} ?: emptyMap<String,Float>())}
 var customize by remember{mutableStateOf(false)}
 val all=order+columns.filter{it !in order};val shown=all.filter{it !in hidden}.ifEmpty{listOf(columns.first())}
 fun width(c:String)=(widths[c] ?: if(c=="Name")240f else 145f).coerceIn(90f,420f)
 fun persist(){store.write(JSONObject().put("order",org.json.JSONArray(all)).put("hidden",org.json.JSONArray(hidden.toList())).put("widths",JSONObject(widths)).toString())}
 fun move(c:String,delta:Int){val copy=all.toMutableList();val i=copy.indexOf(c);if(i+delta in copy.indices){java.util.Collections.swap(copy,i,i+delta);order=copy;persist()}}
 Column(Modifier.fillMaxSize()) {
  TextButton(onClick={customize=true}){Text("Columns & layout")}
  Row(Modifier.horizontalScroll(rememberScrollState()).weight(1f)) {
   Column(Modifier.width(shown.sumOf{width(it).toDouble()}.dp)) {
    Row {shown.forEach{c->Text(c,modifier=Modifier.width(width(c).dp).padding(horizontal=8.dp,vertical=8.dp),style=MaterialTheme.typography.labelMedium)}}
    HorizontalDivider()
    LazyColumn {items(records,key={it.id}){record->
     Row(verticalAlignment=Alignment.CenterVertically) {shown.forEach{c->
      val original=record.values[c] ?: "Unknown"
      if(onEdit!=null && c in listOf("Price / kg","Stock (g)","Nickname","Notes")) {
       var value by remember(record.id,c,original){mutableStateOf(original)}
       OutlinedTextField(value,{value=it},singleLine=true,modifier=Modifier.width(width(c).dp).padding(4.dp),label={Text(c)},keyboardOptions=KeyboardOptions(imeAction=ImeAction.Done),keyboardActions=KeyboardActions(onDone={onEdit(record.id,c,value)}))
      } else Text(original,modifier=Modifier.width(width(c).dp).clickable{onOpen(record.id)}.padding(horizontal=8.dp,vertical=12.dp),maxLines=3,style=MaterialTheme.typography.bodyMedium)
     }}
     HorizontalDivider()
    }}
   }
  }
 }
 if(customize)AlertDialog(onDismissRequest={customize=false},title={Text("Comparison columns")},text={LazyColumn(Modifier.heightIn(max=420.dp)){
  item{Text("Show/hide, reorder and resize columns. Layout is remembered on this device.")}
  items(all){c->Column {Row(verticalAlignment=Alignment.CenterVertically){Checkbox(c !in hidden,onCheckedChange={enabled->if(enabled)hidden=hidden-c else if(shown.size>1)hidden=hidden+c;persist()});Text(c,Modifier.weight(1f));TextButton(onClick={move(c,-1)}){Text("←")};TextButton(onClick={move(c,1)}){Text("→")}};Slider(width(c),onValueChange={widths=widths+(c to it)},onValueChangeFinished={persist()},valueRange=90f..420f);Text("Width: ${width(c).toInt()} points")}}
  item{TextButton(onClick={order=columns;hidden=emptySet();widths=emptyMap();persist()}){Text("Reset layout")}}
 }},confirmButton={TextButton(onClick={customize=false}){Text("Done")}})
}
