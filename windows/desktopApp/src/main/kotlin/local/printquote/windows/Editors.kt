package local.printquote.windows

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import local.printquote.android.model.*
import local.printquote.android.viewmodel.Draft
import org.json.JSONObject
import org.json.JSONArray

fun label(key:String)=key.replace(Regex("([a-z])([A-Z])"),"$1 $2").replace("MM"," (mm)").replace("KG","kg").replaceFirstChar { it.uppercase() }
@Composable fun Heading(text:String) { Text(text,style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(top=12.dp)) }
@Composable fun Fields(d:Draft,o:JSONObject,keys:List<String>,numeric:Boolean=true) { keys.forEach { Field(d,o,it,label(it),numeric) } }
@Composable fun Field(d:Draft,o:JSONObject,key:String,title:String=label(key),numeric:Boolean=false,optional:Boolean=false) {
    d.revision
    if(optional && o.isNull(key)) {
        TextButton(onClick={d.change{o.put(key,if(numeric) 0 else "")}}){Text("Set $title")}
    } else {
        FormRow(d,o,key,title,numeric)
        if(optional) TextButton(onClick={d.change{o.remove(key)}}){Text("Clear $title")}
    }
}
@Composable fun Toggle(d:Draft,o:JSONObject,key:String,title:String=label(key)) {
    d.revision
    Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) { Text(title,modifier=Modifier.weight(1f)); Switch(o.optBoolean(key),onCheckedChange={d.change { o.put(key,it) }}) }
}
@Composable fun Choice(d:Draft,o:JSONObject,key:String,options:List<String>,title:String=label(key)) {
    d.revision; var open by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(),verticalAlignment=androidx.compose.ui.Alignment.CenterVertically) {
        Text(title,Modifier.weight(1f),fontSize=14.sp)
        Box { TextButton(onClick={open=true}) {Text(o.text(key))}
            DropdownMenu(open,{open=false},modifier=Modifier.heightIn(max=320.dp)) {
                options.forEach {option->DropdownMenuItem(text={Text(option)},onClick={d.change{o.put(key,option)};open=false})}
            }
        }
    }
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
@Composable fun TechnicalFields(fields:JSONObject?) {
    if(fields!=null) Fold("Technical specifications and field sources") { fields.keys().asSequence().sorted().forEach { k ->
        val f=fields.optJSONObject(k)
        Text("${label(k)}: ${f?.text("value") ?: fields.opt(k)}",style=MaterialTheme.typography.bodyMedium)
        if(f!=null) Text("Source: ${f.text("sourcePath")} · priority ${f.text("sourcePriority")}${if(f.optBoolean("userOverride")) " · user override" else ""}",style=MaterialTheme.typography.bodySmall)
    } }
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
