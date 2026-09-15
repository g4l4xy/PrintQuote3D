package local.printquote.windows
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.unit.*
import androidx.compose.ui.window.*
import local.printquote.android.model.*
import org.json.JSONObject
import local.printquote.android.data.CatalogQuery
import local.printquote.android.data.supportJSON
import java.awt.Desktop
import java.net.URI

@Composable fun Materials(w:Workspace){var tab by remember{mutableIntStateOf(1)};Column(Modifier.fillMaxSize()){
 Row{TextButton(onClick={tab=0}){Text("My Inventory")};TextButton(onClick={tab=1}){Text("All Filaments")}}
 if(tab==0)Library(w,"filaments") else Column(Modifier.padding(16.dp)){
  val q=w.catalogQuery;val page=w.catalogPage
  SearchField(q.text,{w.searchCatalog(q.copy(text=it,offset=0))},"Search brand, product, color, SKU or tags")
  Row{CatalogFilter("Materials",w.catalogFamilies,q.families){w.searchCatalog(q.copy(families=it,offset=0))};CatalogFilter("Manufacturers",w.catalogBrands,q.brands){w.searchCatalog(q.copy(brands=it,offset=0))};FilterChip(q.favoritesOnly,onClick={w.searchCatalog(q.copy(favoritesOnly=!q.favoritesOnly,offset=0))},label={Text("Favorites")});FilterChip(q.recentOnly,onClick={w.searchCatalog(q.copy(recentOnly=!q.recentOnly,offset=0))},label={Text("Recent")});TextButton(onClick={w.searchCatalog(CatalogQuery())}){Text("Reset Filters")}}
  val sorts=listOf("Name","Manufacturer","Material","Price / kg","Favorite","Recently Used","Difficulty","Drying Requirement");Select("Sort",sorts,sorts.indexOf(q.sort).coerceAtLeast(0)){w.searchCatalog(q.copy(sort=sorts[it],offset=0))}
  Text("Unknown values sort last. Prices use saved inventory; difficulty/drying require explicit source data.",style=MaterialTheme.typography.bodySmall)
  Text("${page.matches} of ${page.total} spool options · ${w.catalogDiagnostics.products} products · ${w.catalogDiagnostics.variants} colors",color=Muted)
  if(w.catalogLoading)Row{Text(w.catalogStage);TextButton(onClick={w.cancelCatalogRefresh()}){Text("Cancel")}}
  if(page.matches==0 && !w.catalogLoading)Text("No filaments match these filters. Clear manufacturer or reset all filters.")
  Row{TextButton(enabled=q.offset>0,onClick={w.searchCatalog(q.copy(offset=(q.offset-100).coerceAtLeast(0)))}){Text("Previous")};Text("Page ${q.offset/100+1}");TextButton(enabled=q.offset+100<page.matches,onClick={w.searchCatalog(q.copy(offset=q.offset+100))}){Text("Next")}}
  val table=ComparisonMode("catalog")
  if(table)ComparisonTable("catalog",listOf("Name","Manufacturer","Material","Color","Spool"),page.rows.map{p->ComparisonRow(p.id,mapOf("Name" to p.name,"Manufacturer" to p.brand,"Material" to p.family,"Color" to p.color,"Spool" to p.spool))},onOpen={id->page.rows.firstOrNull{it.id==id}?.let{p->w.selectedCatalogVariant=p.variantID;w.selectedCatalogSize=p.id;w.showProduct(p.productID)}})
  else LazyColumn{items(page.rows,key={it.id}){p->Row(Modifier.fillMaxWidth().padding(12.dp)){Column(Modifier.weight(1f).clickable{w.selectedCatalogVariant=p.variantID;w.selectedCatalogSize=p.id;w.showProduct(p.productID)}){Text("${p.brand} ${p.name}");Text("${p.family} · ${p.color} · ${p.spool}",color=Muted,fontSize=12.sp)};TextButton(onClick={w.favoriteFilament(p.id)}){Text(if(p.id in w.favoriteFilaments)"★ Favorite" else "☆ Favorite")}};HorizontalDivider()}}
 }
}}
@Composable fun CatalogFilter(title:String,options:List<String>,selected:Set<String>,onChange:(Set<String>)->Unit){var open by remember{mutableStateOf(false)};TextButton(onClick={open=true}){Text("$title (${selected.size})")};if(open)AlertDialog(onDismissRequest={open=false},title={Text(title)},text={LazyColumn(Modifier.heightIn(max=350.dp)){items(options){value->Row{Checkbox(value in selected,onCheckedChange={onChange(if(it)selected+value else selected-value)});Text(value)}}}},confirmButton={TextButton(onClick={open=false}){Text("Done")}})}
@Composable fun Select(title:String,options:List<String>,selected:Int,onSelect:(Int)->Unit){var open by remember{mutableStateOf(false)};Box{OutlinedButton(onClick={open=true}){Text("$title: ${options.getOrNull(selected)?:"None"}")};DropdownMenu(open,{open=false},modifier=Modifier.heightIn(max=320.dp)){options.forEachIndexed{i,t->DropdownMenuItem(text={Text(t)},onClick={onSelect(i);open=false})}}}}
@Composable fun ProductDialog(w:Workspace,pair:Pair<JSONObject,JSONObject>){val(product,metadata)=pair
 DialogWindow(onCloseRequest={w.product=null},onPreviewKeyEvent={dismissOnEscape(it){w.product=null}},title="Material catalog",state=rememberDialogState(width=700.dp,height=700.dp)){PQTheme{Surface{Column(Modifier.padding(24.dp).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(12.dp)){
  w.error?.let{Text(it,color=MaterialTheme.colorScheme.error)}
  Text("${product.text("brand")} ${product.text("name")}",fontSize=24.sp)
  Text("${product.text("materialFamily")} · ${metadata.text("sourceName")}",color=Muted)
  val variants=product.array("variants");var vi by remember(product){mutableIntStateOf(variants.indexOfFirst{it.text("id")==w.selectedCatalogVariant}.coerceAtLeast(0))};var si by remember(product,vi){mutableIntStateOf(variants.getOrNull(vi)?.array("sizes")?.indexOfFirst{it.text("id")==w.selectedCatalogSize}?.coerceAtLeast(0) ?: 0)}
  Select("Color / variant",variants.map{it.text("name")},vi){vi=it}
  val variant=variants.getOrNull(vi);val sizes=variant?.array("sizes").orEmpty()
  Select("Spool",sizes.map{"${it.text("diameterMM")} mm · ${it.text("netWeightGrams")} g"},si){si=it}
  var price by remember(product){mutableStateOf("")};OutlinedTextField(price,{price=it},label={Text("Your purchase price per kg")},singleLine=true,modifier=Modifier.fillMaxWidth())
  Text("Catalog specifications are bundled offline. Enter your actual price before saving.",color=Muted)
  Compatibility(product.optJSONObject("fields"))
  TechnicalFields(product.optJSONObject("fields"));variant?.let{TechnicalFields(it.optJSONObject("fields"))}
  val existing=w.entries("filaments").firstOrNull{it.text("id")==sizes.getOrNull(si)?.text("id")}
  if(existing!=null){
   Text("This size is already saved. Your price, stock and overrides are preserved.",color=Muted)
   Action("Use saved material in estimate"){w.useMaterial(existing)}
   TextButton(onClick={w.product=null;w.edit("filaments",existing)}){Text("Edit saved material")}
  }else{
   fun saveMaterial(use:Boolean){
    try{require(price.toBigDecimal().signum()>=0){"Price cannot be negative"};val m=MaterialCatalogRepository.material(product,checkNotNull(variant),sizes[si],metadata,price);w.save("filaments",m){if(use)w.useMaterial(m)else w.product=null}}catch(e:Exception){w.error=e.message}
   }
   Action("Save to My materials"){saveMaterial(false)}
   TextButton(onClick={saveMaterial(true)}){Text("Save and use in estimate")}
  }
  TextButton(onClick={w.product=null}){Text("Cancel")}
 }}}}
}
@Composable fun Sources(w:Workspace){Column(Modifier.fillMaxSize().padding(24.dp)){
 Text("Data & Pricing Sources",fontSize=28.sp)
 var logs by remember{mutableStateOf(false)}
 if(logs)AlertDialog(onDismissRequest={logs=false},title={Text("Local database log")},text={Column(Modifier.heightIn(max=420.dp).verticalScroll(rememberScrollState())){Text(w.catalogStage);Text(w.printerStatus);Text("Indexed: ${w.catalogDiagnostics.stored} · Rejected: ${w.catalogDiagnostics.rejected} · Duplicates: ${w.catalogDiagnostics.duplicates}\n"+w.catalogDiagnostics.quarantine.take(200).joinToString("\n"){it.sourceID+": "+it.reason}+"\nExport a support bundle for all diagnostics.")}},confirmButton={TextButton(onClick={logs=false}){Text("Done")}})

 val c=w.catalogDiagnostics
 Text("Filament source: ${c.discovered} · Decoded: ${c.decoded} · Normalized: ${c.normalized} · Rejected: ${c.rejected} · Inserted: ${c.inserted} · Updated: ${c.updated} · Duplicates: ${c.duplicates} · Indexed: ${c.stored}")
 TextButton(onClick={w.refreshFilaments()},enabled=!w.catalogLoading){Text("Validate database / rebuild index")}
 if(w.catalogLoading)TextButton(onClick={w.cancelCatalogRefresh()}){Text("Cancel refresh")}
 TextButton(onClick={val chooser=javax.swing.JFileChooser().apply{selectedFile=java.io.File("PrintQuote-V4-diagnostics.json")};if(chooser.showSaveDialog(null)==javax.swing.JFileChooser.APPROVE_OPTION)runCatching{chooser.selectedFile.writeText(c.supportJSON(w.catalogPage.matches))}.onFailure{w.error="Could not export diagnostics: ${it.message}"}}){Text("Create Support Bundle")}

 Text(w.printerStatus)
 TextButton(onClick={w.refreshPrinters()},enabled=!w.printerLoading){Text("Refresh Printer Data")}
 if(w.printerLoading)TextButton(onClick={w.cancelPrinterRefresh()}){Text("Cancel printer refresh")}
 TextButton(onClick={logs=true}){Text("Open Logs")}
 Fold("Quarantine (${c.quarantine.size})"){c.quarantine.take(100).forEach{Text("${it.sourceID}: ${it.reason}")}}
 var query by remember{mutableStateOf("")}
 SearchField(query,{query=it},"Find source or manufacturer")
 LazyColumn{items(w.sources.filter{it.text("name").contains(query,true)}){s->
  Fold(s.text("name")){
   Text(s.text("status"),color=Muted,fontSize=12.sp)
   val links=s.optJSONArray("urls")
   if(links!=null)(0 until links.length()).forEach{i->val url=links.getString(i);TextButton(onClick={runCatching{Desktop.getDesktop().browse(URI(url))}.onFailure{w.error=it.message}}){Text(url,fontSize=12.sp)}}
   Text(s.text("notes"),color=Muted,fontSize=12.sp)
  };HorizontalDivider()
 }}
}}

@Composable fun CommandPalette(w:Workspace){
 var query by remember{mutableStateOf("")};var hits by remember{mutableStateOf<List<Pair<String,JSONObject>>>(emptyList())}
 LaunchedEffect(query,w.library){kotlinx.coroutines.delay(200);val snapshot=listOf("quotes","printers","filaments","presets").flatMap{k->w.entries(k).map{k to it.copy()}};hits=kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default){snapshot.filter{(k,o)->query.isNotBlank() && (title(o,k)+" "+o.text("customer")).contains(query,true)}.take(40)}}
 DialogWindow(onCloseRequest={w.commandPalette=false},title="Search & Commands",state=rememberDialogState(width=720.dp,height=620.dp)){PQTheme{Surface{Column(Modifier.padding(20.dp)){
  SearchField(query,{query=it},"Search commands, quotes, customers, printers or materials")
  LazyColumn {
   items(listOf("New Quote","Import 3MF","Search Filaments","Search Printers","Settings","Refresh Data").filter{query.isBlank() || it.contains(query,true)}){command->TextButton(onClick={w.commandPalette=false;when(command){"New Quote"->w.newQuote();"Import 3MF"->w.screen="Inspect Model";"Search Filaments"->w.screen="Materials";"Search Printers"->w.screen="Printers";"Settings"->w.screen="Settings";else->w.refreshFilaments()}}){Text(command)}}
   if(query.isNotBlank())item{TextButton(onClick={w.commandPalette=false;w.searchCatalog(CatalogQuery(text=query));w.screen="Materials"}){Text("Search all filament variants for “$query”")}}
   items(hits){(kind,o)->TextButton(onClick={w.commandPalette=false;if(kind=="quotes")w.open(o)else w.edit(kind,o)}){Text("$kind · ${title(o,kind)}")}}
  }
 }}}}
}
