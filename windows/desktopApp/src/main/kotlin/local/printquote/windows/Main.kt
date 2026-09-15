package local.printquote.windows

import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.painter.BitmapPainter
import androidx.compose.ui.graphics.toComposeImageBitmap
import androidx.compose.ui.input.key.*
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import androidx.compose.ui.window.*
import local.printquote.android.model.*
import local.printquote.android.data.inlineMaterialEdit
import local.printquote.android.data.sortDiscoveryRecords
import local.printquote.android.viewmodel.Draft
import local.printquote.android.pricing.PricingEngine
import local.printquote.android.pricing.rounded
import org.json.JSONObject
import javax.imageio.ImageIO
import java.time.*
import java.time.format.DateTimeFormatter

val Graphite:Color @Composable get()=MaterialTheme.colorScheme.background
val Panel:Color @Composable get()=MaterialTheme.colorScheme.surface
val Blue:Color @Composable get()=MaterialTheme.colorScheme.primary
val Muted:Color @Composable get()=MaterialTheme.colorScheme.onSurfaceVariant
val LocalSearchRequest = compositionLocalOf { 0 }
val routes=listOf("Dashboard","Quotes","New Estimate","Customers","Jobs","Inventory","Materials","Printers","Presets","Analytics","Settings","Pricing Sources")
fun title(o:JSONObject,k:String)=when(k){"printers"->o.text("manufacturer")+" "+o.text("model");"filaments"->o.text("manufacturer")+" "+o.text("productName")+" · "+o.text("colorName");"quotes"->o.text("projectName");else->o.text("name")}
fun money(o:JSONObject,k:String,currency:String="USD")=try {java.text.NumberFormat.getCurrencyInstance(java.util.Locale.US).apply{this.currency=java.util.Currency.getInstance(currency)}.format(o.decimal(k))}catch(_:Exception){o.text(k)}
fun main()=application {
 val scope=rememberCoroutineScope()
 val w=remember{Workspace(scope)}
 var confirmExit by remember{mutableStateOf(false)}
 var confirmEditorClose by remember{mutableStateOf(false)}
 val closeEditor:()->Unit={if((w.editor?.revision ?: 0)>0)confirmEditorClose=true else w.editor=null}
 Window(onCloseRequest={if((w.draft?.revision ?: 0)>0 && w.autosaveStatus!="Saved" || (w.editor?.revision ?: 0)>0)confirmExit=true else exitApplication()},icon=remember{BitmapPainter(ImageIO.read(resource("app-icon.png")).toComposeImageBitmap())},title="PrintQuote 3D",state=rememberWindowState(width=1100.dp,height=800.dp),onPreviewKeyEvent={e->
  if(e.type==KeyEventType.KeyDown && e.isCtrlPressed && e.key==Key.N){w.newQuote();true}
  else if(e.type==KeyEventType.KeyDown && e.isCtrlPressed && e.key==Key.S){if(w.editor!=null)w.save(w.kind,w.editor!!.json) else w.saveQuote();true}
  else if(e.type==KeyEventType.KeyDown && e.isCtrlPressed && e.key==Key.O){w.screen="Inspect Model";true}
  else if(e.type==KeyEventType.KeyDown && e.isCtrlPressed && e.key==Key.K){w.commandPalette=true;true}
  else if(e.type==KeyEventType.KeyDown && e.isCtrlPressed && e.key==Key.F){w.searchRequest++;true}
  else if(e.type==KeyEventType.KeyDown && e.key==Key.Escape){closeEditor();w.picker=null;w.product=null;true}else false
 }) {
  window.minimumSize=java.awt.Dimension(600,500)
  PQTheme {
   if(confirmEditorClose)AlertDialog(onDismissRequest={confirmEditorClose=false},title={Text("Discard unsaved changes?")},text={Text("Your saved record will stay unchanged.")},confirmButton={TextButton(onClick={w.editor=null;confirmEditorClose=false}){Text("Discard changes")}},dismissButton={TextButton(onClick={confirmEditorClose=false}){Text("Keep editing")}})
   if(confirmExit)AlertDialog(onDismissRequest={confirmExit=false},title={Text("Edits are not fully saved")},text={Text("${w.autosaveStatus}. Stay here to save your changes. Quote recovery drafts are separate from saved quotes; unsaved library edits may be lost.")},confirmButton={TextButton(onClick={confirmExit=false}){Text("Keep editing")}},dismissButton={TextButton(onClick={exitApplication()}){Text("Close anyway")}})

   CompositionLocalProvider(LocalSearchRequest provides w.searchRequest, LocalScrollbarStyle provides defaultScrollbarStyle().copy(unhoverColor=Muted.copy(alpha=0.65f),hoverColor=MaterialTheme.colorScheme.onSurface)){Surface(Modifier.fillMaxSize(),color=Graphite) {WorkspaceView(w,closeEditor)}}
  }
 }
}
@Composable fun Action(text:String,onClick:()->Unit){Button(onClick=onClick,shape=RoundedCornerShape(6.dp),contentPadding=PaddingValues(horizontal=14.dp,vertical=7.dp)){Text(text)}}
@Composable fun Block(title:String,content:@Composable ColumnScope.()->Unit){Column(Modifier.fillMaxWidth().padding(bottom=20.dp)){Text(title,fontWeight=FontWeight.SemiBold,modifier=Modifier.padding(start=10.dp,bottom=10.dp));Column(Modifier.fillMaxWidth().background(Panel,RoundedCornerShape(12.dp)).padding(horizontal=12.dp,vertical=4.dp),content=content)}}
@Composable fun WorkspaceView(w:Workspace,closeEditor:()->Unit) {
 var settingsSearch by remember{mutableStateOf("")}
 var inlineInspector by remember{mutableStateOf(false)}
 LaunchedEffect(w.message){if(w.message!=null){kotlinx.coroutines.delay(3500);w.message=null}}
 Column(Modifier.fillMaxSize()) {
  if(w.recoveredDrafts.isNotEmpty())Row{Text("Recovered drafts found");w.recoveredDrafts.take(3).forEach{q->TextButton(onClick={w.open(q);w.recoveredDrafts=w.recoveredDrafts.filterNot{it.text("id")==q.text("id")}}){Text("Restore ${q.text("projectName")}")};TextButton(onClick={w.discardRecovery(q.text("id"))}){Text("Discard")}}}
 BoxWithConstraints(Modifier.weight(1f)) {
 val sidebarWidth=if(maxWidth>=PQLayout.expanded)208.dp else 156.dp
 SideEffect{inlineInspector=maxWidth>=PQLayout.wide}
 Row(Modifier.fillMaxSize()) {
  Column(Modifier.width(sidebarWidth).fillMaxHeight().background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(PQSpacing.md)) {
   Row(Modifier.padding(top=12.dp,bottom=4.dp),verticalAlignment=Alignment.CenterVertically){val logo=remember{ImageIO.read(resource("brand-mark.png")).toComposeImageBitmap()};Image(BitmapPainter(logo),null,Modifier.size(34.dp));Spacer(Modifier.width(10.dp));Text("PrintQuote3D",fontWeight=FontWeight.Bold,fontSize=18.sp)}
   Text("Real parts. Real prices. Faster.",color=Muted,fontSize=11.sp,modifier=Modifier.padding(bottom=26.dp))
   Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {routes.forEach {s->
    if(s in listOf("Dashboard","Inventory","Analytics"))Text(when(s){"Dashboard"->"WORKSPACE";"Inventory"->"LIBRARY";else->"UTILITY"},style=MaterialTheme.typography.labelSmall,color=Muted,modifier=Modifier.padding(vertical=PQSpacing.md))
    NavigationDrawerItem(label={Text(s,style=MaterialTheme.typography.bodyMedium)},selected=w.screen==s,onClick={if(s=="New Estimate" && w.draft==null)w.newQuote()else w.screen=s},modifier=Modifier.height(40.dp).padding(vertical=PQSpacing.xs))
   }}
   Text("WORKSPACE · V4",fontSize=10.sp,color=Muted,modifier=Modifier.padding(top=16.dp))
  }
  VerticalDivider(color=MaterialTheme.colorScheme.outlineVariant)
  Column(Modifier.weight(1f).fillMaxHeight()) {
   FlowRow(Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(horizontal=PQSpacing.lg,vertical=PQSpacing.xs),horizontalArrangement=Arrangement.spacedBy(PQSpacing.sm)){TextButton(onClick={w.commandPalette=true}){Text("Search / Ctrl+K")};TextButton(onClick={w.screen="Inspect Model"}){Text("Inspect STL / 3MF")};if(w.busy)Text("Working…",color=Muted);w.message?.let{Text(it,color=Blue)}}
   HorizontalDivider(color=MaterialTheme.colorScheme.outlineVariant)
   if(w.library==null)Box(Modifier.fillMaxSize(),contentAlignment=Alignment.Center){Column(horizontalAlignment=Alignment.CenterHorizontally){Text(if(!w.loadFailed)"Loading your workshop…" else "Workspace could not be loaded. Your existing data has been preserved.");if(w.loadFailed)TextButton(onClick={w.openRecoveryFolder()}){Text("Open recovery folder")}}}
   else when(w.screen){
    "Inspect Model"->ModelInspection()
    "Dashboard"->Dashboard(w)
    "New Estimate"->w.draft?.let{QuoteEditor(w,it)}
    "Quotes"->Library(w,"quotes")
    "Materials"->Materials(w)
    "Printers"->Library(w,"printers")
    "Presets"->Library(w,"presets")
    "Settings"->Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(PQSpacing.section)){PQAppearanceControls();HorizontalDivider(Modifier.padding(vertical=PQSpacing.section));Text("Settings",fontSize=28.sp,fontWeight=FontWeight.Bold);Text("PrintQuote 3D · 0.4.0 · Workspace schema 2");Text("Printers: ${w.entries("printers").size} · Products: ${w.catalogDiagnostics.products} · Colors: ${w.catalogDiagnostics.variants} · Spool options: ${w.catalogDiagnostics.stored}");TextButton(onClick={w.screen="Pricing Sources"}){Text("Validate database, rebuild index & export diagnostics")};Spacer(Modifier.height(20.dp));Action("Edit business defaults"){w.edit("settings",w.library!!.getJSONObject("settings"))};Spacer(Modifier.height(12.dp));Action("Export backup"){
     val owner=java.awt.Frame.getFrames().firstOrNull {it.isVisible && it.title=="PrintQuote 3D"}
     val chooser=javax.swing.JFileChooser().apply {
      dialogTitle="Export workspace backup"
      selectedFile=java.io.File("PrintQuote3D-backup-${java.time.LocalDate.now()}.sqlite")
     }
     if(chooser.showSaveDialog(owner)==javax.swing.JFileChooser.APPROVE_OPTION)w.exportBackup(chooser.selectedFile.toPath())
    };TextButton(onClick={w.openRecoveryFolder()}){Text("Open recovery folder")};Text("Backups contain your workshop and customer data. Store them privately.",color=Muted);Text("Data stored in ${dataHome()}",color=Muted,modifier=Modifier.padding(top=24.dp))}
    "Customers"->Column(Modifier.padding(PQSpacing.section)){Text("Customers",fontSize=28.sp);w.entries("quotes").map{it.text("customer")}.filter{it.isNotBlank()}.distinct().forEach{customer->Row{Text(customer,Modifier.weight(1f).padding(PQSpacing.md));TextButton(onClick={w.favoriteEntity("customers",customer)}){Text(if(w.isFavorite("customers",customer))"★" else "☆")};TextButton(onClick={w.entries("quotes").firstOrNull{it.text("customer")==customer}?.let{w.duplicateEntity("quotes",it)}}){Text("Duplicate latest setup")}}};Text("Customers are collected from your saved quotes.",color=Muted)}
    "Pricing Sources"->Sources(w)
    else->Column(Modifier.padding(PQSpacing.section)){Text(w.screen,fontSize=28.sp,fontWeight=FontWeight.Bold);Text("${w.screen} workspace",Modifier.padding(top=20.dp));Text("This section is reserved for the next release, matching the current Mac application.",color=Muted)}
   }
  }
  if(inlineInspector && w.editor!=null){VerticalDivider();PQRecordInspector(w,closeEditor,Modifier.width(360.dp).fillMaxHeight())}
 }
 }
 }
 if(w.commandPalette)CommandPalette(w)
 if(w.error!=null && w.editor==null && w.product==null)AlertDialog(onDismissRequest={w.error=null},title={Text("Unable to complete action")},text={Text(w.error!!)},confirmButton={TextButton(onClick={w.error=null}){Text("OK")}})
 if(!inlineInspector)w.editor?.let{d->DialogWindow(onCloseRequest=closeEditor,onPreviewKeyEvent={e->if(e.type==KeyEventType.KeyDown && e.isCtrlPressed && e.key==Key.S){w.save(w.kind,d.json);true}else if(e.type==KeyEventType.KeyDown && e.key==Key.Escape){closeEditor();true}else false},title="Edit ${w.kind}",state=rememberDialogState(width=700.dp,height=760.dp)){PQTheme{Surface{Column(Modifier.fillMaxSize().padding(PQSpacing.xl)){Row(verticalAlignment=Alignment.CenterVertically){Text("Edit ${if(w.kind=="filaments")"material" else w.kind}",fontSize=24.sp);Spacer(Modifier.weight(1f));Action("Save"){w.save(w.kind,d.json)};if(w.kind=="filaments")TextButton(onClick={w.save("filaments",d.json){w.useMaterial(d.json)}}){Text("Save & use")}};w.error?.let{Text(it,color=MaterialTheme.colorScheme.error)};Column(Modifier.weight(1f).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(10.dp)){if(w.kind=="settings")SearchField(settingsSearch,{settingsSearch=it},"Search settings");CompositionLocalProvider(LocalSettingsSearch provides (if(w.kind=="settings")settingsSearch else "")){LibraryEditor(d,w.kind)}};TextButton(onClick=closeEditor){Text("Cancel")}}}}}}
 w.picker?.let{k->DialogWindow(onCloseRequest={w.picker=null},onPreviewKeyEvent={dismissOnEscape(it){w.picker=null}},title="Choose ${if(k=="filaments")"material"else k}",state=rememberDialogState(width=700.dp,height=650.dp)){PQTheme{Surface{Column(Modifier.padding(PQSpacing.xl)){
 if(k=="filaments"){
  var group by remember{mutableStateOf("Recently Used")}
  FlowRow{listOf("Recently Used","Favorites","Recommended","My Inventory","All Filaments").forEach{label->TextButton(onClick={group=label}){Text(label)}}}
  if(group=="All Filaments")Materials(w)
  else {val inventory=w.entries(k);val rows=when(group){"Recently Used"->inventory.filter{it.text("id") in w.recentFilaments}.sortedByDescending{w.recentFilaments[it.text("id")] ?: 0L};"Favorites"->inventory.filter{it.text("id") in w.favoriteFilaments};"Recommended"->inventory.filter{it.text("id") in w.favoriteFilaments || it.text("id") in w.recentFilaments};else->inventory};if(group=="Recommended")Text("Suggestions use saved history; verify printer compatibility separately.");if(rows.isEmpty())Text("No saved spools in this group. Choose My Inventory or All Filaments.");LibraryRows(rows,k){w.useMaterial(it);w.picker=null}}
 }else LibraryRows(w.discoveryOrder(k,w.entries(k)),k){w.choose(it)}
}}}}}
 w.product?.let{ProductDialog(w,it)}
}
@Composable fun Dashboard(w:Workspace){Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(PQSpacing.section)){
 Text("Your workshop, in focus.",fontSize=30.sp,fontWeight=FontWeight.Bold);Text("Turn production costs into clear, confident quotes.",color=Muted,modifier=Modifier.padding(top=6.dp,bottom=24.dp))
 FlowRow(horizontalArrangement=Arrangement.spacedBy(PQSpacing.md),verticalArrangement=Arrangement.spacedBy(PQSpacing.md)){PQMetric("Saved quotes",w.entries("quotes").size.toString());PQMetric("Printer profiles",w.entries("printers").size.toString());PQMetric("Catalog spools",w.catalogDiagnostics.stored.toString())}
 Spacer(Modifier.height(PQSpacing.section));PQGlassSurface(Modifier.fillMaxWidth()){FlowRow(Modifier.padding(PQSpacing.md),horizontalArrangement=Arrangement.spacedBy(PQSpacing.sm)){Action("Create estimate"){w.newQuote()};OutlinedButton(onClick={w.screen="Inspect Model"}){Text("Inspect STL / 3MF")};TextButton(onClick={w.screen="Materials"}){Text("Browse materials")}}};Spacer(Modifier.height(PQSpacing.section))
 Block("Workshop activity"){Text("${w.catalogDiagnostics.stored} catalog spool options available offline");Text("Material alerts: ${w.entries("filaments").count{it.optJSONObject("stock")?.optDouble("remainingGrams",1000.0)?.let{g->g<100} ?: false}} saved spools below 100 g");Text("Printer status: local profiles available. Live monitoring is not connected.");Text("Active jobs: no job tracker connected.");Text("Recent customers: "+w.entries("quotes").map{it.text("customer")}.filter{it.isNotBlank()}.distinct().take(5).joinToString(", "))}
 Block("Recent quotes"){if(w.entries("quotes").isEmpty())Text("Your saved quotes will appear here.",color=Muted,modifier=Modifier.padding(PQSpacing.md));w.entries("quotes").take(5).forEach{q->Row(Modifier.fillMaxWidth().clickable{w.open(q)}.padding(PQSpacing.md)){Text(q.text("projectName"),Modifier.weight(1f));Text(q.optJSONObject("result")?.let{money(it,"total",q.text("currency","USD"))}?:"Draft")}}}
}}
@Composable fun Library(w:Workspace,k:String){Column(Modifier.fillMaxSize().padding(PQSpacing.section)){Row(verticalAlignment=Alignment.CenterVertically){Text(if(k=="filaments")"Saved materials" else k.replaceFirstChar{it.uppercase()},fontSize=28.sp,fontWeight=FontWeight.Bold);Spacer(Modifier.weight(1f));Action(if(k=="quotes")"New estimate" else "Add ${if(k=="printers")"printer"else if(k=="filaments")"material"else "preset"}"){when(k){"quotes"->w.newQuote();"printers"->w.edit(k,Defaults.printer());"filaments"->w.edit(k,Defaults.material());else->w.edit(k,Defaults.preset())}}};Spacer(Modifier.height(16.dp));LibraryRows(w.discoveryOrder(k,w.entries(k)),k,workspace=w,onDelete={w.delete(k,it.text("id"))}){if(k=="quotes")w.open(it)else w.edit(k,it)}}}
@Composable fun LibraryRows(entries:List<JSONObject>,k:String,onDelete:((JSONObject)->Unit)?=null,workspace:Workspace?=null,onOpen:(JSONObject)->Unit){var query by remember{mutableStateOf("")};var remove by remember{mutableStateOf<JSONObject?>(null)}
 SearchField(query,{query=it},"Search ${if(k=="filaments")"materials"else k}");Text("${entries.size} records",color=Muted,fontSize=12.sp,modifier=Modifier.padding(vertical=10.dp))
 var sort by remember(k){mutableStateOf("Favorite")}
 val sorts=if(k=="printers")listOf("Name","Manufacturer","Build Volume","Toolheads","Recently Used","Favorite")else if(k=="filaments")listOf("Name","Manufacturer","Material","Price / kg","Recently Used","Favorite")else listOf("Name","Recently Used","Favorite")
 Select("Sort",sorts,sorts.indexOf(sort).coerceAtLeast(0)){sort=sorts[it]}
 var filtered by remember(k){mutableStateOf<List<JSONObject>>(emptyList())}
 LaunchedEffect(entries,query,sort,workspace?.entityFavorites,workspace?.entityRecent,workspace?.favoriteFilaments,workspace?.recentFilaments){kotlinx.coroutines.delay(200);filtered=kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default){val rows=entries.filter{title(it,k).contains(query,true)};workspace?.sortedRecords(k,rows,sort) ?: sortDiscoveryRecords(k,rows,sort)}}
 val table=if(k in listOf("filaments","printers"))ComparisonMode(k)else false
 if(table)ComparisonTable(k,if(k=="printers")listOf("Name","Manufacturer","Build volume","Toolheads")else listOf("Name","Material","Color","Price / kg","Stock (g)","Nickname","Notes"),filtered.map{comparisonRow(it,k)},onOpen={id->entries.firstOrNull{it.text("id")==id}?.let(onOpen)},onEdit=if(k=="filaments" && workspace!=null) {id,column,value->entries.firstOrNull{it.text("id")==id}?.let{original->runCatching{inlineMaterialEdit(original,column,value)}.onSuccess{workspace.save(k,it){workspace.message="Inventory field saved"}}.onFailure{workspace.error=it.message}}}else null)
 else LazyColumn(Modifier.fillMaxSize()){items(filtered,key={it.text("id")}){o->ContextMenuArea(items={listOf(ContextMenuItem("Open"){onOpen(o)}) + if(workspace==null)emptyList() else  (if(k=="printers")listOf(ContextMenuItem("New Quote"){workspace.quickQuoteFor(o)},ContextMenuItem("Maintenance settings"){workspace.edit(k,o)})else emptyList()) + listOf(ContextMenuItem(if(workspace.isFavorite(k,o.text("id")))"Remove favorite" else "Favorite"){workspace.favoriteEntity(k,o.text("id"))},ContextMenuItem("Duplicate"){workspace.duplicateEntity(k,o)})}){Row(Modifier.fillMaxWidth().clickable{onOpen(o)}.padding(vertical=12.dp),verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Text(title(o,k),fontWeight=FontWeight.Medium);Text(when(k){"printers"->"${o.text("buildVolumeXMM")} × ${o.text("buildVolumeYMM")} × ${o.text("buildVolumeZMM")} mm";"filaments"->"${o.text("materialFamily")} · ${money(o,"pricePerKG")}/kg";"quotes"->"${o.text("number")} · ${o.text("customer")} · ${o.text("status")}";else->o.text("mode")},color=Muted,fontSize=12.sp)};if(k=="quotes")o.optJSONObject("result")?.let{Text(money(it,"total",o.text("currency","USD")),color=Blue)};if(onDelete!=null)TextButton(onClick={remove=o}){Text("Delete",color=Muted)}}};HorizontalDivider(color=MaterialTheme.colorScheme.outlineVariant)}}
 remove?.let{o->AlertDialog(onDismissRequest={remove=null},title={Text("Delete ${title(o,k)}?")},text={Text(if(k=="quotes")"This quote and its saved cost snapshot will be deleted."else "Existing quote snapshots will be retained.")},confirmButton={TextButton(onClick={onDelete?.invoke(o);remove=null}){Text("Delete")}},dismissButton={TextButton(onClick={remove=null}){Text("Cancel")}})}
}

@Composable fun SearchField(value:String,onChange:(String)->Unit,placeholder:String){
 val requester=remember{FocusRequester()};val request=LocalSearchRequest.current
 LaunchedEffect(request){if(request>0)requester.requestFocus()}
 OutlinedTextField(value,onChange,placeholder={Text(placeholder)},singleLine=true,modifier=Modifier.fillMaxWidth().focusRequester(requester))
}

fun dismissOnEscape(e:KeyEvent,close:()->Unit):Boolean {if(e.type==KeyEventType.KeyDown && e.key==Key.Escape){close();return true};return false}

@Composable fun PQRecordInspector(w:Workspace,closeEditor:()->Unit,modifier:Modifier=Modifier){
 val d=w.editor ?: return
 Surface(modifier,color=MaterialTheme.colorScheme.surface){Column(Modifier.padding(PQSpacing.lg)){
  PQSectionHeader("Details",when(w.kind){"printers"->"Printer configuration";"filaments"->"Material & inventory";"settings"->"Business defaults";else->"Pricing preset"})
  Row{TextButton(onClick={w.save(w.kind,d.json)}){Text("Save")};TextButton(onClick=closeEditor){Text("Close")}}
  w.error?.let{Text(it,color=MaterialTheme.colorScheme.error)}
  Column(Modifier.weight(1f).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(PQSpacing.md)){LibraryEditor(d,w.kind)}
 }}
}
