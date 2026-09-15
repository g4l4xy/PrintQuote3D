package local.printquote.android.ui

import androidx.compose.foundation.Image
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.graphics.Color
import local.printquote.android.R
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.*
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
    var commands by remember {mutableStateOf(false)}
    var discard by remember {mutableStateOf<(() -> Unit)?>(null)}
    fun navigate(to:String) {
        fun perform() { vm.editor=null;vm.product=null;vm.picker=null; if(to=="New Estimate") vm.newQuote() else {vm.quote=null;vm.screen=to}; if(to=="Settings") vm.edit("settings",vm.library!!.getJSONObject("settings")) }
        if((vm.quote?.revision ?: 0)>0 && vm.autosaveStatus!="Saved" || (vm.editor?.revision ?: 0)>0) discard={perform()} else perform()
    }
    fun back() {when { vm.editor!=null -> discard={vm.editor=null};vm.product!=null -> vm.product=null; vm.picker!=null -> vm.picker=null;vm.quote!=null -> discard={vm.quote=null;vm.screen="Dashboard"};else->vm.screen="Dashboard"}}
    BackHandler(vm.screen!="Dashboard" || vm.editor!=null || vm.product!=null || vm.picker!=null) { back() }
    if(commands)V4Commands(vm){commands=false}
    val snackbar=remember{SnackbarHostState()}
    LaunchedEffect(vm.savedMessage){vm.savedMessage?.let{snackbar.showSnackbar(it);vm.savedMessage=null}}
    PQTheme {
      BoxWithConstraints(Modifier.fillMaxSize()) {
        val compact=maxWidth<PQLayout.medium
        val expanded=maxWidth>=PQLayout.expanded
        Scaffold(containerColor=MaterialTheme.colorScheme.background,bottomBar={
            if(compact && vm.editor==null && vm.product==null && vm.picker==null) NavigationBar {
                listOf("Dashboard","Quotes","Materials","More").forEach { to -> NavigationBarItem(selected=vm.screen==to,onClick={if(to=="More")menu=true else navigate(to)},icon={Text(when(to){"Dashboard"->"⌂";"Quotes"->"≡";"Materials"->"◉";else->"•••"})},label={Text(to)}) }
            }
        },snackbarHost={SnackbarHost(snackbar)},topBar={TopAppBar(title={Text(if(vm.editor!=null) "Edit ${when(vm.editorKind){"filaments"->"material";"printers"->"printer";"presets"->"preset";else->"settings"}}" else if(vm.product!=null) "Catalog material" else if(vm.picker!=null) "Choose ${vm.picker}" else vm.screen)},
            navigationIcon={TextButton(onClick={if(vm.editor!=null || vm.product!=null || vm.picker!=null) back() else menu=true}) {Text(if(vm.editor!=null || vm.product!=null || vm.picker!=null) "Back" else "Menu")}},actions={
                if(vm.editor!=null) TextButton(enabled=!vm.busy,onClick={vm.save(vm.editorKind,vm.editor!!.json)}) {Text("Save")}
                else if(vm.quote!=null && vm.product==null && vm.picker==null) TextButton(enabled=!vm.busy,onClick={vm.saveQuote()}) {Text("Save quote")}
                TextButton(onClick={commands=true}){Text("Search")}
            })}) { padding ->
            Row(Modifier.padding(padding).fillMaxSize()) {
              if(!compact) {
                if(expanded) Column(Modifier.width(208.dp).fillMaxHeight().verticalScroll(rememberScrollState()).padding(PQSpacing.md),verticalArrangement=Arrangement.spacedBy(PQSpacing.xs)) {
                    Text("PrintQuote 3D",style=MaterialTheme.typography.titleMedium,modifier=Modifier.padding(PQSpacing.md))
                    destinations.forEach {to->NavigationDrawerItem(label={Text(to)},selected=vm.screen==to,onClick={navigate(to)},modifier=Modifier.fillMaxWidth())}
                } else NavigationRail {listOf("Dashboard","Quotes","Materials","More").forEach{to->NavigationRailItem(selected=vm.screen==to,onClick={if(to=="More")menu=true else navigate(to)},icon={Text(when(to){"Dashboard"->"⌂";"Quotes"->"≡";"Materials"->"◉";else->"•••"})},label={Text(to)})}}
                VerticalDivider()
              }
              Column(Modifier.weight(1f).fillMaxHeight()) {
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
        }
      }
        if(menu) AlertDialog(onDismissRequest={menu=false},title={Text("PrintQuote 3D")},text={Column(Modifier.heightIn(max=500.dp).verticalScroll(rememberScrollState())) {destinations.forEach {to->TextButton(onClick={menu=false;navigate(to)},enabled=vm.library!=null,modifier=Modifier.fillMaxWidth()) {Text(to)}}}},confirmButton={TextButton(onClick={menu=false}) {Text("Close")}})
        if(discard!=null) AlertDialog(onDismissRequest={discard=null},title={Text("Leave this draft?")},text={Text(if(vm.quote!=null)"${vm.autosaveStatus}. Quote recovery drafts are kept separately. Wait for Saved before leaving, or keep editing to resolve a save failure." else "Unsaved library edits will be discarded.")},confirmButton={TextButton(onClick={val action=discard;discard=null;action?.invoke()}) {Text("Leave")}},dismissButton={TextButton(onClick={discard=null}) {Text("Keep editing")}})
        vm.error?.let {message->AlertDialog(onDismissRequest={vm.error=null},title={Text("Unable to complete action")},text={Text(message)},confirmButton={TextButton(onClick={vm.error=null}) {Text("OK")}})}
    }
}

@Composable fun Dashboard(vm:WorkspaceViewModel) {
    var showCommands by remember{mutableStateOf(false)}
    if(showCommands)V4Commands(vm){showCommands=false}
    val quotes=vm.entries("quotes"); val currency=vm.library!!.getJSONObject("settings").text("currency","USD")
    LazyColumn(Modifier.fillMaxSize(),contentPadding=PaddingValues(PQSpacing.section),verticalArrangement=Arrangement.spacedBy(PQSpacing.md)) {
        item { TextButton(onClick={showCommands=true}){Text("Search & Commands")} }
        items(vm.recoveredDrafts,key={it.text("id")}){q->Text("Recovered draft: ${q.text("projectName")}");Row{TextButton(onClick={vm.openQuote(q);vm.recoveredDrafts=vm.recoveredDrafts.filterNot{it.text("id")==q.text("id")}}){Text("Restore")};TextButton(onClick={vm.discardRecovery(q.text("id"))}){Text("Discard")}}}

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
        item {BoxWithConstraints{val wide=maxWidth>=PQLayout.medium;if(wide)Row(horizontalArrangement=Arrangement.spacedBy(PQSpacing.md)){PQMetric("Saved quotes",quotes.size.toString(),Modifier.weight(1f));PQMetric("Printer profiles",vm.entries("printers").size.toString(),Modifier.weight(1f));PQMetric("Catalog spools",vm.catalogDiagnostics.stored.toString(),Modifier.weight(1f))}else Column(verticalArrangement=Arrangement.spacedBy(PQSpacing.md)){PQMetric("Saved quotes",quotes.size.toString(),Modifier.fillMaxWidth());PQMetric("Catalog spools",vm.catalogDiagnostics.stored.toString(),Modifier.fillMaxWidth())}}}
        item {PQGlassSurface(Modifier.fillMaxWidth()){FlowRow(Modifier.padding(PQSpacing.md),horizontalArrangement=Arrangement.spacedBy(PQSpacing.sm)){Button(onClick=vm::newQuote){Text("Create estimate")};OutlinedButton(onClick={vm.screen="Inspect Model"}){Text("Inspect STL / 3MF")}}}}
        item {Text("Enter material, machine time and labor to build a complete pricing snapshot. Imported profiles require review of actual shop costs.")}
        item {Heading("Recent quotes")}
        if(quotes.isEmpty()) item {Text("Your first saved quote will appear here.")}
        items(quotes.take(5),key={it.text("id")}) {q->QuoteRow(q) {vm.openQuote(q)}}
        item {Heading("Workshop activity");Text("${vm.catalogDiagnostics.stored} catalog spool options available offline");Text("Material alerts: ${vm.entries("filaments").count{it.optJSONObject("stock")?.optDouble("remainingGrams",1000.0)?.let{g->g<100} ?: false}} saved spools below 100 g");Text("Printer status: local profiles available. Live monitoring is not connected.");Text("Active jobs: no job tracker connected.")}
        item {Heading("Recent customers");Text(quotes.map{it.text("customer")}.filter{it.isNotBlank()}.distinct().take(5).joinToString(", ").ifBlank{"Customers appear on saved quotes."})}
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
        LazyColumn(contentPadding=PaddingValues(16.dp)) {if(customers.isEmpty()) item {Text("Customers appear when you save a quote with a customer name.")};items(customers) {customer->Row{TextButton(onClick={selected=customer;vm.usedEntity("customers",customer)},modifier=Modifier.weight(1f)) {Text(customer)};TextButton(onClick={vm.favoriteEntity("customers",customer)}){Text(if(vm.isFavorite("customers",customer))"★" else "☆")};TextButton(onClick={vm.entries("quotes").firstOrNull{it.text("customer")==customer}?.let{vm.duplicateEntity("quotes",it)}}){Text("Duplicate setup")}}}}
    }}
}
@Composable fun EntityList(vm:WorkspaceViewModel,kind:String,onSelect:((JSONObject)->Unit)?=null) {
    var query by rememberSaveable(kind) {mutableStateOf("")}
    var sort by rememberSaveable(kind){mutableStateOf("Favorite")}
    var values by remember(kind){mutableStateOf<List<JSONObject>>(emptyList())}
    LaunchedEffect(vm.library,query,kind,sort,vm.entityFavorites,vm.entityRecent,vm.favoriteFilaments,vm.recentFilaments,vm.materialPickerGroup){delay(200);val rows=vm.entries(kind).filter{kind!="filaments" || onSelect==null || vm.materialPickerGroup=="all" || (vm.materialPickerGroup=="recent" && it.text("id") in vm.recentFilaments) || (vm.materialPickerGroup=="favorite" && it.text("id") in vm.favoriteFilaments) || (vm.materialPickerGroup=="recommended" && (it.text("id") in vm.favoriteFilaments || it.text("id") in vm.recentFilaments))};values=withContext(Dispatchers.Default){vm.sortedRecords(kind,rows.filter{name(it,kind).contains(query,true)},sort)}}
    Column {
        OutlinedTextField(query,onValueChange={query=it},label={Text(if(kind=="printers") "Search manufacturer, model or nozzle" else "Search ${if(kind=="filaments") "materials" else "presets"}")},modifier=Modifier.fillMaxWidth().padding(12.dp))
        Row(Modifier.fillMaxWidth().padding(horizontal=16.dp),horizontalArrangement=Arrangement.SpaceBetween) {Text("${values.size} of ${vm.entries(kind).size}");TextButton(onClick={vm.edit(kind,when(kind){"printers"->Defaults.printer();"filaments"->Defaults.material();else->Defaults.preset()})}) {Text("Add ${when(kind){"printers"->"printer";"filaments"->"material";else->"preset"}}")}}
        val sorts=if(kind=="printers")listOf("Name","Manufacturer","Build Volume","Toolheads","Recently Used","Favorite")else if(kind=="filaments")listOf("Name","Manufacturer","Material","Price / kg","Recently Used","Favorite")else listOf("Name","Recently Used","Favorite")
        Select("Sort",sorts.map{it to it},sort){sort=it}
        if(kind=="filaments" && onSelect!=null)Text(when(vm.materialPickerGroup){"recent"->"Recently Used";"favorite"->"Favorites";"recommended"->"Recommended from your history";else->"My Inventory"})
        val table=if(kind in listOf("filaments","printers"))ComparisonMode(kind) else false
        if(table)ComparisonTable(kind,if(kind=="printers")listOf("Name","Manufacturer","Build volume","Toolheads")else listOf("Name","Material","Color","Price / kg","Stock (g)","Nickname","Notes"),values.map{comparisonRow(it,kind)},onOpen={id->values.firstOrNull{it.text("id")==id}?.let{if(onSelect!=null)onSelect(it)else vm.edit(kind,it)}},onEdit=if(kind=="filaments" && onSelect==null){id,column,value->values.firstOrNull{it.text("id")==id}?.let{original->runCatching{inlineMaterialEdit(original,column,value)}.onSuccess{vm.save(kind,it){vm.savedMessage="Inventory field saved"}}.onFailure{vm.error=it.message}}}else null)
        else LazyColumn(contentPadding=PaddingValues(16.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {
            if(values.isEmpty()) item {Text("No matches. Add a record or change the search.")}
            items(values,key={it.text("id")}) {o->OutlinedCard(onClick={if(onSelect!=null) onSelect(o) else vm.edit(kind,o)},modifier=Modifier.fillMaxWidth()) {Column(Modifier.padding(12.dp)) {
                var actions by remember{mutableStateOf(false)}
                Row{Text(name(o,kind),style=MaterialTheme.typography.titleMedium,modifier=Modifier.weight(1f));Box{TextButton(onClick={actions=true}){Text("⋯")};DropdownMenu(actions,{actions=false}){if(kind=="printers"){DropdownMenuItem(text={Text("New Quote")},onClick={vm.quickQuoteFor(o);actions=false});DropdownMenuItem(text={Text("Maintenance settings")},onClick={vm.edit(kind,o);actions=false})};DropdownMenuItem(text={Text(if(vm.isFavorite(kind,o.text("id")))"Remove favorite" else "Favorite")},onClick={vm.favoriteEntity(kind,o.text("id"));actions=false});DropdownMenuItem(text={Text("Duplicate")},onClick={vm.duplicateEntity(kind,o);actions=false})}}}

                when(kind) {"printers"->Text("${o.optJSONObject("toolSystem")?.text("availableToolheadCount","1")} tools · ${o.optJSONObject("toolSystem")?.text("architecture","custom")}")
                    "filaments"->{Text("${o.text("materialFamily")} · ${o.text("pricePerKG")} / kg");o.optJSONObject("stock")?.let {Text("${it.text("remainingGrams")} g · ${it.text("location")}")}}
                    else->Text("${o.text("mode")} · ${o.text("rate")}")}
            }}}
        }
    }
}
@Composable fun DocumentEditor(vm:WorkspaceViewModel) {
    var settingsSearch by remember{mutableStateOf("")}
    val d=vm.editor!!;var confirmDelete by remember {mutableStateOf(false)}
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
        if(vm.editorKind=="settings") {
            OutlinedTextField(settingsSearch,{settingsSearch=it},label={Text("Search settings")},modifier=Modifier.fillMaxWidth())
            Text("PrintQuote 3D · 0.4.0 · Workspace schema 2")
            Text("Printers: ${vm.entries("printers").size} · Products: ${vm.catalogDiagnostics.products} · Colors: ${vm.catalogDiagnostics.variants} · Spool options: ${vm.catalogDiagnostics.stored}")
            TextButton(onClick={vm.refreshFilaments()}){Text("Validate catalog / rebuild index")}
        }
        CompositionLocalProvider(LocalSettingsSearch provides settingsSearch){LibraryEditor(d,vm.editorKind)}
        Button(enabled=!vm.busy,onClick={vm.save(vm.editorKind,d.json)},modifier=Modifier.fillMaxWidth()) {Text("Save ${when(vm.editorKind){"printers"->"printer";"filaments"->"material";"presets"->"preset";else->"settings"}}")}
        if(vm.editorKind!="settings") {
            OutlinedButton(onClick={val copy=d.json.copy().put("id",uuid());if(vm.editorKind=="presets") copy.put("name",copy.text("name")+" copy");vm.edit(vm.editorKind,copy)},modifier=Modifier.fillMaxWidth()) {Text("Duplicate")}
            if(!(vm.editorKind=="printers" && d.json.has("externalProfile")) && vm.entries(vm.editorKind).any {it.text("id")==d.json.text("id")}) TextButton(onClick={confirmDelete=true}) {Text("Delete saved record")}
        }
    }
    if(confirmDelete) AlertDialog(onDismissRequest={confirmDelete=false},title={Text("Delete saved record?")},text={Text("Existing quote snapshots will be retained.")},confirmButton={TextButton(enabled=!vm.busy,onClick={vm.delete(vm.editorKind,d.json.text("id"));confirmDelete=false}) {Text("Delete")}},dismissButton={TextButton(onClick={confirmDelete=false}) {Text("Cancel")}})
}
@Composable fun MaterialsWorkspace(vm:WorkspaceViewModel,picking:Boolean=false) {
    var catalog by rememberSaveable {mutableStateOf(!picking)}
    Column {
        if(picking)Column{Text("Suggestions use saved history; verify printer compatibility separately.",style=MaterialTheme.typography.bodySmall);TextButton(onClick={catalog=false;vm.materialPickerGroup="recommended"}){Text("Recommended from history")};Row{TextButton(onClick={catalog=false;vm.materialPickerGroup="recent"}){Text("Recently Used")};TextButton(onClick={catalog=false;vm.materialPickerGroup="favorite"}){Text("Favorites")}}}
        Row {FilterChip(!catalog,onClick={catalog=false;vm.materialPickerGroup="all"},label={Text("My Inventory")});FilterChip(catalog,onClick={catalog=true},label={Text("All Filaments")})}
        if(!catalog) EntityList(vm,"filaments",if(picking) vm::selectMaterial else null) else {
            val q=vm.catalogQuery;val page=vm.catalogPage
            OutlinedTextField(q.text,onValueChange={vm.searchCatalog(q.copy(text=it,offset=0))},label={Text("Search brand, product, color, SKU or tags")},modifier=Modifier.fillMaxWidth())
            Row {CatalogFilter("Materials",vm.catalogFamilies,q.families){vm.searchCatalog(q.copy(families=it,offset=0))};CatalogFilter("Manufacturers",vm.catalogBrands,q.brands){vm.searchCatalog(q.copy(brands=it,offset=0))}}
            Row {FilterChip(q.favoritesOnly,onClick={vm.searchCatalog(q.copy(favoritesOnly=!q.favoritesOnly,offset=0))},label={Text("Favorites")});FilterChip(q.recentOnly,onClick={vm.searchCatalog(q.copy(recentOnly=!q.recentOnly,offset=0))},label={Text("Recent")});TextButton(onClick={vm.searchCatalog(CatalogQuery())}){Text("Reset")}}
            Select("Sort",listOf("Name","Manufacturer","Material","Price / kg","Favorite","Recently Used","Difficulty","Drying Requirement").map{it to it},q.sort){vm.searchCatalog(q.copy(sort=it,offset=0))}
            Text("Unknown values sort last. Prices use saved inventory; difficulty/drying require explicit source data.",style=MaterialTheme.typography.bodySmall)
            Text("${page.matches} of ${page.total} spool options · ${vm.catalogDiagnostics.products} products · ${vm.catalogDiagnostics.variants} colors")
            if(vm.catalogLoading)Row{Text(vm.catalogStage);TextButton(onClick={vm.cancelCatalogRefresh()}){Text("Cancel")}}
            if(vm.catalogSearching)LinearProgressIndicator(Modifier.fillMaxWidth())
            if(page.matches==0 && !vm.busy && !vm.catalogLoading)Text("No filaments match these filters. Reset filters or choose another manufacturer.")
            Row {TextButton(enabled=q.offset>0,onClick={vm.searchCatalog(q.copy(offset=(q.offset-100).coerceAtLeast(0)))}){Text("Previous")};Text("Page ${q.offset/100+1}");TextButton(enabled=q.offset+100<page.matches,onClick={vm.searchCatalog(q.copy(offset=q.offset+100))}){Text("Next")}}
            val table=ComparisonMode("catalog")
            if(table)ComparisonTable("catalog",listOf("Name","Manufacturer","Material","Color","Spool"),page.rows.map{p->ComparisonRow(p.id,mapOf("Name" to p.name,"Manufacturer" to p.brand,"Material" to p.family,"Color" to p.color,"Spool" to p.spool))},onOpen={id->page.rows.firstOrNull{it.id==id}?.let{p->vm.selectedCatalogVariant=p.variantID;vm.selectedCatalogSize=p.id;vm.showProduct(p.productID)}})
            else LazyColumn(contentPadding=PaddingValues(12.dp),verticalArrangement=Arrangement.spacedBy(8.dp)) {items(page.rows,key={it.id}) {entry->OutlinedCard(onClick={vm.selectedCatalogVariant=entry.variantID;vm.selectedCatalogSize=entry.id;vm.showProduct(entry.productID)},modifier=Modifier.fillMaxWidth()) {Column(Modifier.padding(12.dp)) {Text("${entry.brand} ${entry.name}");Text("${entry.family} · ${entry.color} · ${entry.spool}",style=MaterialTheme.typography.bodySmall);TextButton(onClick={vm.favoriteFilament(entry.id)}){Text(if(entry.id in vm.favoriteFilaments)"★ Favorite" else "☆ Favorite")}}}}}
        }
    }
}
@Composable fun CatalogFilter(title:String,options:List<String>,selected:Set<String>,onChange:(Set<String>)->Unit){
 var open by remember{mutableStateOf(false)}
 TextButton(onClick={open=true}){Text("$title (${selected.size})")}
 if(open)AlertDialog(onDismissRequest={open=false},title={Text(title)},text={LazyColumn(Modifier.heightIn(max=350.dp)){items(options){value->Row{Checkbox(value in selected,onCheckedChange={onChange(if(it)selected+value else selected-value)});Text(value)}}}},confirmButton={TextButton(onClick={open=false}){Text("Done")}})
}
@Composable fun Select(title:String,options:List<Pair<String,String>>,value:String,onSelect:(String)->Unit) {
    var open by remember {mutableStateOf(false)}
    OutlinedButton(onClick={open=true},modifier=Modifier.fillMaxWidth()) {Text("$title: ${options.firstOrNull {it.first==value}?.second ?: "Choose"}")}
    if(open) AlertDialog(onDismissRequest={open=false},title={Text(title)},text={Column(Modifier.heightIn(max=400.dp).verticalScroll(rememberScrollState())) {options.forEach {(id,name)->TextButton(onClick={onSelect(id);open=false},modifier=Modifier.fillMaxWidth()) {Text(name)}}}},confirmButton={TextButton(onClick={open=false}) {Text("Close")}})
}
@Composable fun ProductDetail(vm:WorkspaceViewModel) {
    val (product,metadata)=vm.product!!
    val variants=product.array("variants")
    var variantID by rememberSaveable(product.text("id")) {mutableStateOf(vm.selectedCatalogVariant ?: variants.firstOrNull()?.text("id") ?: "")}
    val variant=variants.firstOrNull {it.text("id")==variantID};val sizes=variant?.array("sizes") ?: emptyList()
    var sizeID by rememberSaveable(variantID) {mutableStateOf(vm.selectedCatalogSize?.takeIf{id->sizes.any{it.text("id")==id}} ?: sizes.firstOrNull()?.text("id") ?: "")}
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
        Compatibility(product.optJSONObject("fields"))
        TechnicalFields(product.optJSONObject("fields"));TechnicalFields(variant?.optJSONObject("fields"));TechnicalFields(size?.optJSONObject("fields"))
        size?.optJSONArray("purchaseURLs")?.let {urls->(0 until urls.length()).forEach {index->val url=urls.getString(index);if(url.startsWith("https://") || url.startsWith("http://")) TextButton(onClick={try{uri.openUri(url)}catch(e:Exception){vm.error=e.message}}) {Text(url)}}}
        Text("${metadata.text("sourceName")} · ${metadata.text("sourceLicense")} · ${metadata.text("upstreamVersion")}\nRetrieved ${metadata.text("retrievedAt")}",style=MaterialTheme.typography.bodySmall)
    }
}
@Composable fun Sources(vm:WorkspaceViewModel) {
    val context=LocalContext.current;val scope=rememberCoroutineScope()
    var logs by remember{mutableStateOf(false)}
    if(logs)AlertDialog(onDismissRequest={logs=false},title={Text("Local database log")},text={Column(Modifier.heightIn(max=420.dp).verticalScroll(rememberScrollState())){Text(vm.catalogStage);Text(vm.printerStatus);Text("Indexed: ${vm.catalogDiagnostics.stored} · Rejected: ${vm.catalogDiagnostics.rejected} · Duplicates: ${vm.catalogDiagnostics.duplicates}\n"+vm.catalogDiagnostics.quarantine.take(200).joinToString("\n"){it.sourceID+": "+it.reason}+"\nExport a support bundle for all diagnostics.")}},confirmButton={TextButton(onClick={logs=false}){Text("Done")}})

    val export=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")){uri->if(uri!=null)scope.launch{try{val data=vm.catalogDiagnostics.supportJSON(vm.catalogPage.matches);withContext(Dispatchers.IO){context.contentResolver.openOutputStream(uri)?.use{it.write(data.toByteArray())} ?: error("Cannot open export destination")};vm.savedMessage="Diagnostics exported"}catch(e:Exception){vm.error="Could not export diagnostics: ${e.message}"}}}

    var query by rememberSaveable {mutableStateOf("")};var technical by rememberSaveable {mutableStateOf(false)}
    val uri=LocalUriHandler.current
    Column {
        val c=vm.catalogDiagnostics
        Text("Source: ${c.discovered} · Decoded: ${c.decoded} · Normalized: ${c.normalized} · Rejected: ${c.rejected} · Inserted: ${c.inserted} · Updated: ${c.updated} · Duplicate IDs: ${c.duplicates} · Indexed: ${c.stored}")
        TextButton(onClick={vm.refreshFilaments()}){Text("Refresh local filament data / rebuild index")}
        TextButton(onClick={export.launch("PrintQuote-V4-diagnostics.json")}){Text("Create Support Bundle")}
 Text(vm.printerStatus)
 TextButton(onClick={vm.refreshPrinters()},enabled=!vm.printerLoading){Text("Refresh Printer Data")}
 if(vm.printerLoading)TextButton(onClick={vm.cancelPrinterRefresh()}){Text("Cancel printer refresh")}
 TextButton(onClick={logs=true}){Text("Open Logs")}
        if(c.quarantine.isNotEmpty())Text(c.quarantine.take(10).joinToString("\n"){it.sourceID+": "+it.reason})
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

@Composable fun V4Commands(vm:WorkspaceViewModel,close:()->Unit){
 var query by remember{mutableStateOf("")}
 var rows by remember{mutableStateOf<List<Pair<String,JSONObject>>>(emptyList())}
 LaunchedEffect(query,vm.library){delay(200);val snapshot=vm.library;rows=withContext(Dispatchers.Default){listOf("quotes","printers","filaments","presets").flatMap{k->snapshot?.array(k).orEmpty().map{k to it}}.filter{(k,o)->query.isNotBlank() && (name(o,k)+" "+o.text("customer")).contains(query,true)}.take(30)}}
 AlertDialog(onDismissRequest=close,title={Text("Search & Commands")},text={Column{OutlinedTextField(query,{query=it},label={Text("Search your workspace")});LazyColumn(Modifier.heightIn(max=400.dp)){
 items(listOf("New Quote","Import 3MF","Search Filaments","Search Printers","Settings","Refresh Data").filter{query.isBlank() || it.contains(query,true)}){command->TextButton(onClick={close();when(command){"New Quote"->vm.newQuote();"Import 3MF"->vm.screen="Inspect Model";"Search Filaments"->vm.screen="Materials";"Search Printers"->vm.screen="Printers";"Settings"->vm.edit("settings",vm.library!!.getJSONObject("settings"));else->vm.refreshFilaments()}}){Text(command)}}
 if(query.isNotBlank())item{TextButton(onClick={vm.searchCatalog(CatalogQuery(text=query));vm.screen="Materials";close()}){Text("Search all filaments for “$query”")}}
 items(rows){(kind,o)->TextButton(onClick={close();if(kind=="quotes")vm.openQuote(o)else vm.edit(kind,o)}){Text("$kind · ${name(o,kind)}")}}
 }}},confirmButton={TextButton(onClick=close){Text("Close")}})
}
