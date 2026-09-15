package local.printquote.android.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.compose.ui.unit.dp
import local.printquote.android.model.*
import local.printquote.android.pricing.*
import local.printquote.android.viewmodel.*
import org.json.JSONObject
import java.time.LocalDate
import java.time.ZoneOffset
import java.math.BigDecimal

@Composable fun QuoteScreen(vm:WorkspaceViewModel) {
    val d=vm.quote ?: return; d.revision
    LaunchedEffect(d.revision){if(d.revision>0)vm.autosave(d.json.toString())}
    var tab by rememberSaveable(d.json.text("id")) {mutableStateOf("Details")}
    val result=remember(d.revision) {runCatching {PricingEngine.calculate(d.json.getJSONObject("input"))}}
    var modelReview by remember{mutableStateOf(false)}
    if(modelReview)Dialog(onDismissRequest={modelReview=false},properties=DialogProperties(usePlatformDefaultWidth=false)){Surface(Modifier.fillMaxSize()){Column{TextButton(onClick={modelReview=false}){Text("Back to quote")};ModelInspectionScreen()}}}
    Column(Modifier.fillMaxSize()) {
      PQGlassSurface(Modifier.fillMaxWidth().padding(PQSpacing.md)){FlowRow(Modifier.padding(PQSpacing.sm)){TextButton(onClick={modelReview=true}){Text("Model & source")};Text(vm.autosaveStatus,Modifier.padding(PQSpacing.sm),style=MaterialTheme.typography.labelLarge)}}
      BoxWithConstraints(Modifier.weight(1f)) {
        val wideWorkspace=maxWidth>=PQLayout.wide
        if(maxWidth>=PQLayout.expanded && androidx.compose.ui.platform.LocalDensity.current.fontScale<1.5f) Row {
            if(wideWorkspace)Column(Modifier.width(220.dp).padding(PQSpacing.lg)){PQSectionHeader("Model & source",d.json.optJSONObject("manufacturingImport")?.text("filename") ?: "Manual estimate");Text("Inspect source evidence before changing quote values.",color=MaterialTheme.colorScheme.onSurfaceVariant)}
            Column(Modifier.weight(1f)) {QuoteDetails(vm,d)};VerticalDivider();Surface(Modifier.width(320.dp)) {Breakdown(d,result)}}
        else Column {Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceEvenly) {listOf("Details","Price breakdown").forEach {FilterChip(tab==it,onClick={tab=it},label={Text(it)})}};if(tab=="Details") QuoteDetails(vm,d) else Breakdown(d,result)}
      }
    }
}
@Composable fun QuoteDetails(vm:WorkspaceViewModel,d:Draft) {
    val q=d.json;val i=q.getJSONObject("input");d.revision
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(PQSpacing.lg),verticalArrangement=Arrangement.spacedBy(10.dp)) {
        Text(q.text("number"),style=MaterialTheme.typography.titleLarge)
        Text(vm.autosaveStatus,style=MaterialTheme.typography.bodySmall)
        Heading("Project")
        Field(d,q,"projectName","Project name");Field(d,q,"customer");Choice(d,q,"status",listOf("draft","sent","approved","rejected","expired","convertedToJob"))
        val date=d.expiryText ?: java.time.Instant.ofEpochSecond(q.decimal("expiresAt").toLong()+978307200).atZone(ZoneOffset.UTC).toLocalDate().toString()
        val invalidDate=!d.expiryValid
        OutlinedTextField(date,onValueChange={value->d.expiryText=value;try {val parsed=LocalDate.parse(value);d.change {q.put("expiresAt",parsed.atStartOfDay(ZoneOffset.UTC).toEpochSecond()-978307200)};d.expiryValid=true}catch(_:Exception){d.expiryValid=false}},label={Text("Expires (YYYY-MM-DD)")},isError=invalidDate,modifier=Modifier.fillMaxWidth())
        if(invalidDate) Text("Enter a valid date; the previous expiry is retained.",color=MaterialTheme.colorScheme.error)
        Field(d,q,"notes");Choice(d,q,"currency",listOf("USD","CAD","EUR","GBP","AUD"))
        Heading("Equipment and material")
        OutlinedButton(onClick={vm.picker="printer"},modifier=Modifier.fillMaxWidth()) {Text(q.optJSONObject("printer")?.let {name(it,"printers")} ?: "Select printer")}
        OutlinedButton(onClick={vm.picker="material"},modifier=Modifier.fillMaxWidth()) {Text(q.optJSONObject("filament")?.let {name(it,"filaments")} ?: "Choose material")}
        OutlinedButton(onClick={vm.picker="preset"},modifier=Modifier.fillMaxWidth()) {Text(q.optJSONObject("preset")?.text("name") ?: "Apply pricing preset")}
        if(q.optJSONObject("printer")?.optJSONObject("externalProfile")?.optBoolean("userOverride")==false) Text("Imported technical profile: enter average power, machine and maintenance rates. Review the tool setup.")
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween) {Text("Assign materials to tools",modifier=Modifier.weight(1f));Switch(i.optJSONObject("toolJob")!=null,onCheckedChange={enabled->d.change {if(enabled) Defaults.enableTools(q) else i.remove("toolJob")}})}
        if(i.optJSONObject("toolJob")!=null) {
            Text("Enter base print hours excluding change time. Tool active hours must fit within that base time.",style=MaterialTheme.typography.bodySmall)
            val job=i.getJSONObject("toolJob")
            Fold("Quote tool-system snapshot") {ToolSystemFields(d,job.getJSONObject("system"))}
            Assignments(vm,d,job)
        } else Fold("Material consumption",true) {Fields(d,i,listOf("modelGrams","supportGrams","interfaceGrams","purgeGrams","towerGrams","startupGrams","pricePerKG","supportPricePerKG","interfacePricePerKG"))}
        Fold("Machine, electricity and labor",true) {Fields(d,i,listOf("printHours","averageWatts","electricityRate","machineRate","maintenanceRate","laborMinutes","laborRate"))}
        Fold("Drying and direct costs") {Fields(d,i,listOf("dryerWatts","dryingHours","dryingSharedJobs","wearCost","packaging","outsideServices","otherCosts"))}
        Fold("Pricing rules",true) {Text("Rates are decimal fractions: 0.40 = 40%.");Choice(d,i,"pricingMode",listOf("margin","markup"));Fields(d,i,listOf("profitRate","failureProbability","overheadRate","materialMultiplier","minimumCharge","rushMultiplier","discountRate","taxRate","shipping"))}
        Button(enabled=!vm.busy && !invalidDate,onClick=vm::saveQuote,modifier=Modifier.fillMaxWidth()) {Text("Save quote")}
    }
}
@Composable fun Assignments(vm:WorkspaceViewModel,d:Draft,job:JSONObject) {
    d.revision
    job.array("assignments").forEach {a->key(a.text("id")) {Fold("Assignment: ${a.text("materialName")} · ${a.text("role")}",true) {
        var choosing by remember {mutableStateOf(false)}
        TextButton(onClick={choosing=true}) {Text("Choose saved material for assignment")}
        if(choosing) AlertDialog(onDismissRequest={choosing=false},title={Text("Assignment material")},text={Column(Modifier.heightIn(max=320.dp).verticalScroll(rememberScrollState())) {vm.entries("filaments").forEach {m->TextButton(onClick={d.change {a.put("materialID",m.text("id")).put("materialName",name(m,"filaments")).put("materialFamily",m.text("materialFamily")).put("colorName",m.text("colorName")).put("pricePerKG",m.decimal("pricePerKG"))};choosing=false}) {Text(name(m,"filaments"))}}}},confirmButton={TextButton(onClick={choosing=false}) {Text("Close")}})
        Field(d,a,"materialName");Field(d,a,"materialFamily");Field(d,a,"colorName")
        Field(d,a,"toolIndex","Physical tool index (1–12)",true);Field(d,a,"feederSlot","Feeder slot (optional)",true,true)
        Choice(d,a,"role",listOf("model","support","interface","waste"))
        Fields(d,a,listOf("grams","pricePerKG","activeHours","activationCount"));Toggle(d,a,"abrasive");Toggle(d,a,"flexible")
        TextButton(onClick={d.change {job.put("assignments",array(job.array("assignments").filterNot {it.text("id")==a.text("id")}))}}) {Text("Remove assignment")}
    } } }
    OutlinedButton(onClick={d.change {job.put("assignments",array(job.array("assignments")+Defaults.assignment()))}},modifier=Modifier.fillMaxWidth()) {Text("Add material assignment")}
}
@Composable fun Breakdown(d:Draft,result:Result<JSONObject>) {
    val currency=d.json.text("currency","USD")
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(PQSpacing.xl),verticalArrangement=Arrangement.spacedBy(PQSpacing.md)) {
        result.fold(onSuccess={r->
            Text("CUSTOMER PRICE",style=MaterialTheme.typography.labelLarge);Text(money(r.decimal("total"),currency),style=MaterialTheme.typography.headlineLarge.copy(fontFeatureSettings="tnum"),color=MaterialTheme.colorScheme.primary);HorizontalDivider();Heading("Cost breakdown")
            r.array("components").filter {it.decimal("amount").signum()!=0}.forEach {c->CostRow(c.text("name"),c.decimal("amount"),currency)}
            HorizontalDivider();CostRow("Production cost",r.decimal("productionCost"),currency);CostRow("Overhead",r.decimal("overhead"),currency)
            listOf("subtotal","discount","tax","shipping").forEach {CostRow(label(it),r.decimal(it)*(if(it=="discount") BigDecimal(-1) else BigDecimal.ONE),currency)}
            if(r.optBoolean("minimumApplied")) Text("Minimum charge applied")
            Text("Consumed: ${r.decimal("totalGrams").stripTrailingZeros().toPlainString()} g")
            Text("Material efficiency: ${rounded(r.decimal("materialEfficiency")*BigDecimal(100))}%")
            if(d.json.getJSONObject("input").optJSONObject("toolJob")!=null) Text("Added change time: ${rounded(r.decimal("changeHours")*BigDecimal(60))} minutes")
            val warnings=r.getJSONArray("warnings");(0 until warnings.length()).forEach {Text(warnings.getString(it),color=MaterialTheme.colorScheme.tertiary,style=MaterialTheme.typography.bodySmall)}
            val i=d.json.getJSONObject("input");if(i.optJSONObject("toolJob")==null && i.decimal("purgeGrams")>i.decimal("modelGrams")) Text("Purge exceeds final-part weight",color=MaterialTheme.colorScheme.tertiary)
            Text("Manual estimate: verify slicer data and actual operating costs. Incremental tool energy must exclude power already included in average printer draw.",style=MaterialTheme.typography.bodySmall)
        },onFailure={Text(it.message ?: "Invalid pricing inputs",color=MaterialTheme.colorScheme.error)})
    }
}
@Composable fun CostRow(title:String,value:BigDecimal,currency:String) {Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.spacedBy(PQSpacing.md)) {Text(title,modifier=Modifier.weight(1f));Text(money(value,currency))}}
