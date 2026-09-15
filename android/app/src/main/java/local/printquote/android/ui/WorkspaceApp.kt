package local.printquote.android.ui

import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.graphics.Color
import local.printquote.android.R
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import local.printquote.android.data.*
import local.printquote.android.model.*
import local.printquote.android.pricing.*
import local.printquote.android.viewmodel.*
import org.json.JSONObject
import java.math.BigDecimal
import java.text.NumberFormat
import java.util.Currency

fun money(value:BigDecimal, currency:String="USD"):String = NumberFormat.getCurrencyInstance().apply {this.currency=Currency.getInstance(currency)}.format(value)
fun name(o:JSONObject,kind:String):String=when(kind) {"printers"->o.text("manufacturer")+" "+o.text("model");"filaments"->o.text("manufacturer")+" "+o.text("productName")+" · "+o.text("colorName");"quotes"->o.text("number")+" · "+o.text("projectName");else->o.text("name")}
val destinations=listOf("Dashboard","New Estimate","Quotes","Customers","Materials","Printers","Presets","Settings","Pricing Sources")

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun WorkspaceApp(vm:WorkspaceViewModel) {
    var menu by remember {mutableStateOf(false)}
    var discard by remember {mutableStateOf<(() -> Unit)?>(null)}
    fun navigate(to:String) {
        fun perform() { vm.editor=null;vm.product=null;vm.picker=null; if(to=="New Estimate") vm.newQuote() else {vm.quote=null;vm.screen=to}; if(to=="Settings") vm.edit("settings",vm.library!!.getJSONObject("settings")) }
        if(vm.quote!=null || vm.editor!=null) discard={perform()} else perform()
    }
    fun back() {when { vm.editor!=null -> discard={vm.editor=null};vm.product!=null -> vm.product=null; vm.picker!=null -> vm.picker=null;vm.quote!=null -> discard={vm.quote=null;vm.screen="Dashboard"};else->vm.screen="Dashboard"}}
    BackHandler(vm.screen!="Dashboard" || vm.editor!=null || vm.product!=null || vm.picker!=null) { back() }
    MaterialTheme(colorScheme=darkColorScheme(primary=Color(0xFF7AC6FF), onPrimary=Color(0xFF003352), secondary=Color(0xFF5CDCEB), tertiary=Color(0xFF9BDCF5))) {
        Scaffold(topBar={TopAppBar(title={Text(if(vm.editor!=null) "Edit ${when(vm.editorKind){"filaments"->"material";"printers"->"printer";"presets"->"preset";else->"settings"}}" else if(vm.product!=null) "Catalog material" else if(vm.picker!=null) "Choose ${vm.picker}" else vm.screen)},
            navigationIcon={TextButton(onClick={if(vm.editor!=null || vm.product!=null || vm.picker!=null) back() else menu=true}) {Text(if(vm.editor!=null || vm.product!=null || vm.picker!=null) "Back" else "Menu")}},actions={
                if(vm.editor!=null) TextButton(enabled=!vm.busy,onClick={vm.save(vm.editorKind,vm.editor!!.json)}) {Text("Save")}
                else if(vm.quote!=null && vm.product==null && vm.picker==null) TextButton(enabled=!vm.busy,onClick={vm.saveQuote()}) {Text("Save quote")}
            })}) { padding ->
            Column(Modifier.padding(padding).fillMaxSize()) {
                if(vm.busy) LinearProgressIndicator(Modifier.fillMaxWidth())
                if(vm.library==null) {
                    Column(Modifier.padding(24.dp)) {Text(if(vm.busy) "Loading your workshop…" else "Workspace unavailable");if(!vm.busy) Button(onClick=vm::reload) {Text("Retry")}}
                } else when {
                    vm.editor!=null -> DocumentEditor(vm)
                    vm.product!=null -> ProductDetail(vm)
                    vm.picker=="printer" -> EntityList(vm,"printers",onSelect=vm::selectPrinter)
                    vm.picker=="material" -> MaterialsWorkspace(vm,true)
                    vm.picker=="preset" -> EntityList(vm,"presets",onSelect=vm::preset)
                    vm.screen=="Inspect Model" -> ModelInspectionScreen()
                    vm.screen=="New Estimate" -> QuoteScreen(vm)
                    vm.screen=="Printers" -> EntityList(vm,"printers")
                    vm.screen=="Materials" -> MaterialsWorkspace(vm)
                    vm.screen=="Presets" -> EntityList(vm,"presets")
                    vm.screen=="Quotes" -> QuoteList(vm)
                    vm.screen=="Customers" -> Customers(vm)
                    vm.screen=="Pricing Sources" -> Sources(vm)
                    else -> Dashboard(vm)
                }
            }
        }
        if(menu) AlertDialog(onDismissRequest={menu=false},title={Text("PrintQuote 3D")},text={Column(Modifier.heightIn(max=500.dp).verticalScroll(rememberScrollState())) {destinations.forEach {to->TextButton(onClick={menu=false;navigate(to)},enabled=vm.library!=null,modifier=Modifier.fillMaxWidth()) {Text(to)}}}},confirmButton={TextButton(onClick={menu=false}) {Text("Close")}})
        if(discard!=null) AlertDialog(onDismissRequest={discard=null},title={Text("Leave this draft?")},text={Text("Unsaved edits will be discarded.")},confirmButton={TextButton(onClick={val action=discard;discard=null;action?.invoke()}) {Text("Discard")}},dismissButton={TextButton(onClick={discard=null}) {Text("Keep editing")}})
        vm.error?.let {message->AlertDialog(onDismissRequest={vm.error=null},title={Text("Unable to complete action")},text={Text(message)},confirmButton={TextButton(onClick={vm.error=null}) {Text("OK")}})}
    }
}

@Composable fun Dashboard(vm:WorkspaceViewModel) {
    val quotes=vm.entries("quotes"); val currency=vm.library!!.getJSONObject("settings").text("currency","USD")
    LazyColumn(Modifier.fillMaxSize(),contentPadding=PaddingValues(20.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        item {
            Row(verticalAlignment=androidx.compose.ui.Alignment.CenterVertically, horizontalArrangement=Arrangement.spacedBy(12.dp), modifier=Modifier.fillMaxWidth()) {
                Image(painterResource(R.drawable.brand_mark), contentDescription=null, modifier=Modifier.size(40.dp), contentScale=androidx.compose.ui.layout.ContentScale.Fit)
                Column(Modifier.weight(1f), verticalArrangement=Arrangement.spacedBy(4.dp)) {
                    Text("PrintQuote 3D", style=MaterialTheme.typography.titleLarge)
                    Text("Real parts. Real prices. Faster.", style=MaterialTheme.typography.bodySmall, color=MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
        item {Text("Your workshop, in focus.",style=MaterialTheme.typography.headlineMedium);Text(vm.library!!.getJSONObject("settings").text("businessName"))}
        item {Text("${quotes.size} saved quotes · ${vm.entries("printers").size} printer profiles · ${vm.entries("filaments").size} saved materials")}
        item {OutlinedButton(onClick={vm.screen="Inspect Model"},modifier=Modifier.fillMaxWidth()) {Text("Inspect STL / 3MF")}}
        item {Button(onClick=vm::newQuote,modifier=Modifier.fillMaxWidth()) {Text("Create estimate")}}
        item {Text("Enter material, machine time and labor to build a complete pricing snapshot. Imported profiles require review of actual shop costs.")}
        item {Heading("Recent quotes")}
        if(quotes.isEmpty()) item {Text("Your first saved quote will appear here.")}
        items(quotes.take(5),key={it.text("id")}) {q->QuoteRow(q) {vm.openQuote(q)}}
        item {Heading("Workshop libraries")}
        items(listOf("Materials","Printers","Presets")) {destination->OutlinedButton(onClick={vm.screen=destination},modifier=Modifier.fillMaxWidth()) {Text(destination)}}
        item {Text("Local workspace · all catalogs work offline",style=MaterialTheme.typography.bodySmall)}
    }
}
@Composable fun QuoteRow(q:JSONObject,click:()->Unit) {
    OutlinedCard(onClick=click,modifier=Modifier.fillMaxWidth()) {Column(Modifier.padding(16.dp)) {
        Text(name(q,"quotes"),style=MaterialTheme.typography.titleMedium);Text(q.text("customer","No customer")+" · "+q.text("status"))
        Text(money(q.optJSONObject("result")?.decimal("total") ?: BigDecimal.ZERO,q.text("currency","USD")),style=MaterialTheme.typography.titleLarge)
    }}
}
@Composable fun QuoteList(vm:WorkspaceViewModel,customer:String?=null) {
    var search by rememberSaveable {mutableStateOf("")}
    Column {OutlinedTextField(search,onValueChange={search=it},label={Text("Search quotes, customer or status")},modifier=Modifier.fillMaxWidth().padding(12.dp))
        LazyColumn(contentPadding=PaddingValues(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
            val quotes=vm.entries("quotes").filter {(customer==null || it.text("customer")==customer) && listOf(it.text("number"),it.text("projectName"),it.text("customer"),it.text("status")).any {v->v.contains(search,true)}}
            if(quotes.isEmpty()) item {Text("No matching saved quotes.")}
            items(quotes,key={it.text("id")}) {q->QuoteRow(q) {vm.openQuote(q)}}
        }
    }
}
@Composable fun Customers(vm:WorkspaceViewModel) {
    var selected by rememberSaveable {mutableStateOf<String?>(null)}
    Column {if(selected!=null) {TextButton(onClick={selected=null}) {Text("All customers")};Text(selected!!);QuoteList(vm,selected)} else {
        val customers=vm.entries("quotes").map {it.text("customer")}.filter {it.isNotBlank()}.distinct().sorted()
        LazyColumn(contentPadding=PaddingValues(16.dp)) {if(customers.isEmpty()) item {Text("Customers appear when you save a quote with a customer name.")};items(customers) {customer->TextButton(onClick={selected=customer},modifier=Modifier.fillMaxWidth()) {Text(customer)}}}
    }}
}
@Composable fun EntityList(vm:WorkspaceViewModel,kind:String,onSelect:((JSONObject)->Unit)?=null) {
    var query by rememberSaveable(kind) {mutableStateOf("")}
    val values=remember(vm.library,query,kind) {vm.entries(kind).filter {name(it,kind).contains(query,true)}.sortedBy {name(it,kind).lowercase()}}
    Column {
        OutlinedTextField(query,onValueChange={query=it},label={Text(if(kind=="printers") "Search manufacturer, model or nozzle" else "Search ${if(kind=="filaments") "materials" else "presets"}")},modifier=Modifier.fillMaxWidth().padding(12.dp))
        Row(Modifier.fillMaxWidth().padding(horizontal=16.dp),horizontalArrangement=Arrangement.SpaceBetween) {Text("${values.size} of ${vm.entries(kind).size}");TextButton(onClick={vm.edit(kind,when(kind){"printers"->Defaults.printer();"filaments"->Defaults.material();else->Defaults.preset()})}) {Text("Add ${when(kind){"printers"->"printer";"filaments"->"material";else->"preset"}}")}}
        LazyColumn(contentPadding=PaddingValues(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
            if(values.isEmpty()) item {Text("No matches. Add a record or change the search.")}
            items(values,key={it.text("id")}) {o->OutlinedCard(onClick={if(onSelect!=null) onSelect(o) else vm.edit(kind,o)},modifier=Modifier.fillMaxWidth()) {Column(Modifier.padding(12.dp)) {
                Text(name(o,kind),style=MaterialTheme.typography.titleMedium)
                when(kind) {"printers"->Text("${o.optJSONObject("toolSystem")?.text("availableToolheadCount","1")} tools · ${o.optJSONObject("toolSystem")?.text("architecture","custom")}")
                    "filaments"->{Text("${o.text("materialFamily")} · ${o.text("pricePerKG")} / kg");o.optJSONObject("stock")?.let {Text("${it.text("remainingGrams")} g · ${it.text("location")}")}}
                    else->Text("${o.text("mode")} · ${o.text("rate")}")}
            }}}
        }
    }
}
@Composable fun DocumentEditor(vm:WorkspaceViewModel) {
    val d=vm.editor!!;var confirmDelete by remember {mutableStateOf(false)}
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
        LibraryEditor(d,vm.editorKind)
        Button(enabled=!vm.busy,onClick={vm.save(vm.editorKind,d.json)},modifier=Modifier.fillMaxWidth()) {Text("Save ${when(vm.editorKind){"printers"->"printer";"filaments"->"material";"presets"->"preset";else->"settings"}}")}
        if(vm.editorKind!="settings") {
            OutlinedButton(onClick={val copy=d.json.copy().put("id",uuid());if(vm.editorKind=="presets") copy.put("name",copy.text("name")+" copy");vm.edit(vm.editorKind,copy)},modifier=Modifier.fillMaxWidth()) {Text("Duplicate")}
            if(!(vm.editorKind=="printers" && d.json.has("externalProfile")) && vm.entries(vm.editorKind).any {it.text("id")==d.json.text("id")}) TextButton(onClick={confirmDelete=true}) {Text("Delete saved record")}
        }
    }
    if(confirmDelete) AlertDialog(onDismissRequest={confirmDelete=false},title={Text("Delete saved record?")},text={Text("Existing quote snapshots will be retained.")},confirmButton={TextButton(enabled=!vm.busy,onClick={vm.delete(vm.editorKind,d.json.text("id"));confirmDelete=false}) {Text("Delete")}},dismissButton={TextButton(onClick={confirmDelete=false}) {Text("Cancel")}})
}
@Composable fun MaterialsWorkspace(vm:WorkspaceViewModel,picking:Boolean=false) {
    var catalog by rememberSaveable {mutableStateOf(false)}
    Column {
        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceEvenly) {FilterChip(!catalog,onClick={catalog=false},label={Text("My materials")});FilterChip(catalog,onClick={catalog=true},label={Text("Browse catalog")})}
        if(!catalog) EntityList(vm,"filaments",if(picking) vm::selectMaterial else null) else {
            var query by rememberSaveable {mutableStateOf("")}
            OutlinedTextField(query,onValueChange={query=it},label={Text("Search brand, product or material family")},modifier=Modifier.fillMaxWidth().padding(12.dp))
            val filtered=remember(vm.catalogIndex,query) {vm.catalogIndex.filter {"${it.brand} ${it.name} ${it.family}".contains(query,true)}}
            Text("${filtered.size} catalog products",modifier=Modifier.padding(horizontal=16.dp))
            LazyColumn(contentPadding=PaddingValues(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {items(filtered,key={it.id}) {entry->OutlinedCard(onClick={vm.showProduct(entry.id)},modifier=Modifier.fillMaxWidth()) {Column(Modifier.padding(12.dp)) {Text(entry.name);Text("${entry.brand} · ${entry.family}",style=MaterialTheme.typography.bodySmall)}}}}
        }
    }
}
@Composable fun Select(title:String,options:List<Pair<String,String>>,value:String,onSelect:(String)->Unit) {
    var open by remember {mutableStateOf(false)}
    OutlinedButton(onClick={open=true},modifier=Modifier.fillMaxWidth()) {Text("$title: ${options.firstOrNull {it.first==value}?.second ?: "Choose"}")}
    if(open) AlertDialog(onDismissRequest={open=false},title={Text(title)},text={Column(Modifier.heightIn(max=400.dp).verticalScroll(rememberScrollState())) {options.forEach {(id,name)->TextButton(onClick={onSelect(id);open=false},modifier=Modifier.fillMaxWidth()) {Text(name)}}}},confirmButton={TextButton(onClick={open=false}) {Text("Close")}})
}
@Composable fun ProductDetail(vm:WorkspaceViewModel) {
    val (product,metadata)=vm.product!!
    val variants=product.array("variants")
    var variantID by rememberSaveable(product.text("id")) {mutableStateOf(variants.firstOrNull()?.text("id") ?: "")}
    val variant=variants.firstOrNull {it.text("id")==variantID};val sizes=variant?.array("sizes") ?: emptyList()
    var sizeID by rememberSaveable(variantID) {mutableStateOf(sizes.firstOrNull()?.text("id") ?: "")}
    var price by rememberSaveable(product.text("id")) {mutableStateOf("")}
    val size=sizes.firstOrNull {it.text("id")==sizeID}; val existing=vm.entries("filaments").firstOrNull {it.text("id")==sizeID}
    val uri=LocalUriHandler.current
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        Text(product.text("name"),style=MaterialTheme.typography.headlineSmall);Text("${product.text("brand")} · ${product.text("materialFamily")}")
        Select("Color",variants.map {it.text("id") to it.text("name")},variantID) {variantID=it}
        Select("Spool",sizes.map {it.text("id") to "${it.text("diameterMM","?")} mm · ${it.text("netWeightGrams","?")} g"},sizeID) {sizeID=it}
        if(existing!=null) {
            Text("This spool is already in My materials at ${existing.text("pricePerKG")} / kg.")
            Button(onClick={vm.product=null;if(vm.picker=="material") vm.selectMaterial(existing) else vm.edit("filaments",existing)}) {Text(if(vm.picker=="material") "Use saved material" else "Edit saved material")}
        } else {
            OutlinedTextField(price,onValueChange={price=it},label={Text("Your price per kg")},modifier=Modifier.fillMaxWidth())
            Text("Enter your purchase cost. Catalog purchase links are references, not live prices.")
            Button(enabled=!vm.busy && size!=null && price.toBigDecimalOrNull()?.signum()==1,onClick={try {
                val material=MaterialCatalogRepository.material(product,variant!!,size!!,metadata,price)
                vm.save("filaments",material) {vm.product=null;if(vm.picker=="material") vm.selectMaterial(material) else vm.edit("filaments",material)}
            } catch(e:Exception) {vm.error=e.message}},modifier=Modifier.fillMaxWidth()) {Text(if(vm.picker=="material") "Save and use material" else "Save to My materials")}
            if(size!=null && (size.isNull("diameterMM") || size.isNull("netWeightGrams"))) Text("Spool dimensions are unknown. Add a manual material with verified dimensions.")
        }
        TechnicalFields(product.optJSONObject("fields"));TechnicalFields(variant?.optJSONObject("fields"));TechnicalFields(size?.optJSONObject("fields"))
        size?.optJSONArray("purchaseURLs")?.let {urls->(0 until urls.length()).forEach {index->val url=urls.getString(index);if(url.startsWith("https://") || url.startsWith("http://")) TextButton(onClick={try{uri.openUri(url)}catch(e:Exception){vm.error=e.message}}) {Text(url)}}}
        Text("${metadata.text("sourceName")} · ${metadata.text("sourceLicense")} · ${metadata.text("upstreamVersion")}\nRetrieved ${metadata.text("retrievedAt")}",style=MaterialTheme.typography.bodySmall)
    }
}
@Composable fun Sources(vm:WorkspaceViewModel) {
    var query by rememberSaveable {mutableStateOf("")};var technical by rememberSaveable {mutableStateOf(false)}
    val uri=LocalUriHandler.current
    Column {
        Row {FilterChip(!technical,onClick={technical=false},label={Text("Source directory")});FilterChip(technical,onClick={technical=true},label={Text("Orca profiles")})}
        OutlinedTextField(query,onValueChange={query=it},label={Text("Search sources and technical profiles")},modifier=Modifier.fillMaxWidth().padding(12.dp))
        LazyColumn(contentPadding=PaddingValues(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
            item {Text("${vm.catalogIndex.size} offline filament products · ${vm.technical.size} pinned technical profiles. Source listings do not imply live price feeds or implemented network adapters.")}
            items((if(technical) vm.technical else vm.sources).filter {it.text("name").contains(query,true)},key={it.text("id")}) {o->Fold(o.text("name")) {
                if(!technical) {Text(o.text("status"));Text(o.text("notes"));val urls=o.optJSONArray("urls");if(urls!=null) (0 until urls.length()).forEach {index->val url=urls.getString(index);if(url.startsWith("http://") || url.startsWith("https://")) TextButton(onClick={try{uri.openUri(url)}catch(e:Exception){vm.error=e.message}}) {Text(url)}}}
                else {
                    Text("${o.text("kind")} · ${o.text("vendor")}");Text(o.optJSONArray("reviewReasons")?.toString() ?: "")
                    TechnicalFields(o.optJSONObject("technicalValues"));Text(o.optJSONObject("source")?.toString(2) ?: "")
                    if(o.text("kind")=="machine") TextButton(onClick={val p=vm.entries("printers").firstOrNull {it.text("id")==o.text("id")} ?: WorkspaceRepository.convertPrinter(o);vm.edit("printers",p)}) {Text("Review printer")}
                    else TextButton(onClick={val m=Defaults.material().put("id",o.text("id")).put("manufacturer",o.text("vendor")).put("productName",o.text("name")).put("materialFamily",o.text("materialFamily","Unknown")).put("externalProfile",o.getJSONObject("source").copy()).put("pricePerKG",0);vm.edit("filaments",vm.entries("filaments").firstOrNull {it.text("id")==o.text("id")} ?: m)}) {Text("Add material and enter cost")}
                }
            }}
        }
    }
}
