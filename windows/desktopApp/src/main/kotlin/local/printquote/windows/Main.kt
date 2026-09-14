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
import local.printquote.android.viewmodel.Draft
import local.printquote.android.pricing.PricingEngine
import local.printquote.android.pricing.rounded
import org.json.JSONObject
import javax.imageio.ImageIO
import java.time.*
import java.time.format.DateTimeFormatter

val Graphite=Color(0xff232728);val Panel=Color(0xff2b2f30);val Blue=Color(0xff009dff);val Muted=Color(0xffa0a4a6)
val LocalSearchRequest = compositionLocalOf { 0 }
val routes=listOf("Dashboard","Quotes","New Estimate","Customers","Jobs","Inventory","Materials","Printers","Presets","Analytics","Settings","Pricing Sources")
fun title(o:JSONObject,k:String)=when(k){"printers"->o.text("manufacturer")+" "+o.text("model");"filaments"->o.text("manufacturer")+" "+o.text("productName")+" · "+o.text("colorName");"quotes"->o.text("projectName");else->o.text("name")}
fun money(o:JSONObject,k:String,currency:String="USD")=try {java.text.NumberFormat.getCurrencyInstance(java.util.Locale.US).apply{this.currency=java.util.Currency.getInstance(currency)}.format(o.decimal(k))}catch(_:Exception){o.text(k)}
fun main()=application {
 val scope=rememberCoroutineScope()
 val w=remember{Workspace(scope)}
 Window(onCloseRequest=::exitApplication,icon=remember{BitmapPainter(ImageIO.read(resource("app-icon.png")).toComposeImageBitmap())},title="PrintQuote 3D",state=rememberWindowState(width=1100.dp,height=800.dp),onPreviewKeyEvent={e->
  if(e.type==KeyEventType.KeyDown && e.isCtrlPressed && e.key==Key.N){w.newQuote();true}
  else if(e.type==KeyEventType.KeyDown && e.isCtrlPressed && e.key==Key.S){if(w.editor!=null)w.save(w.kind,w.editor!!.json) else w.saveQuote();true}
  else if(e.type==KeyEventType.KeyDown && e.isCtrlPressed && e.key==Key.O){w.screen="Quotes";true}
  else if(e.type==KeyEventType.KeyDown && e.isCtrlPressed && e.key==Key.F){w.searchRequest++;true}
  else if(e.type==KeyEventType.KeyDown && e.key==Key.Escape){w.editor=null;w.picker=null;w.product=null;true}else false
 }) {
  window.minimumSize=java.awt.Dimension(850,600)
  MaterialTheme(colorScheme=workshopColors()) {
   CompositionLocalProvider(LocalSearchRequest provides w.searchRequest, LocalScrollbarStyle provides defaultScrollbarStyle().copy(unhoverColor=Muted.copy(alpha=0.65f),hoverColor=Color.White)){Surface(Modifier.fillMaxSize(),color=Graphite) {WorkspaceView(w)}}
  }
 }
}
@Composable fun Action(text:String,onClick:()->Unit){Button(onClick=onClick,shape=RoundedCornerShape(6.dp),contentPadding=PaddingValues(horizontal=14.dp,vertical=7.dp)){Text(text)}}
@Composable fun Block(title:String,content:@Composable ColumnScope.()->Unit){Column(Modifier.fillMaxWidth().padding(bottom=20.dp)){Text(title,fontWeight=FontWeight.SemiBold,modifier=Modifier.padding(start=10.dp,bottom=10.dp));Column(Modifier.fillMaxWidth().background(Panel,RoundedCornerShape(12.dp)).padding(horizontal=12.dp,vertical=4.dp),content=content)}}
@Composable fun WorkspaceView(w:Workspace) {
 Row(Modifier.fillMaxSize()) {
  Column(Modifier.width(220.dp).fillMaxHeight().background(Color(0xff2c3031)).padding(12.dp)) {
   Row(Modifier.padding(top=12.dp,bottom=4.dp),verticalAlignment=Alignment.CenterVertically){val logo=remember{ImageIO.read(resource("brand-mark.png")).toComposeImageBitmap()};Image(BitmapPainter(logo),null,Modifier.size(34.dp));Spacer(Modifier.width(10.dp));Text("PrintQuote3D",fontWeight=FontWeight.Bold,fontSize=18.sp)}
   Text("Real parts. Real prices. Faster.",color=Muted,fontSize=11.sp,modifier=Modifier.padding(bottom=26.dp))
   Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {routes.forEach {s->Text(s,Modifier.fillMaxWidth().background(if(w.screen==s)Color(0xff075ccb)else Color.Transparent,RoundedCornerShape(7.dp)).clickable{if(s=="New Estimate" && w.draft==null)w.newQuote()else w.screen=s}.padding(horizontal=10.dp,vertical=10.dp),fontSize=14.sp)}}
   Text("WORKSPACE · V2",fontSize=10.sp,color=Muted,modifier=Modifier.padding(top=16.dp))
  }
  VerticalDivider(color=Color(0xff414546))
  Column(Modifier.weight(1f).fillMaxHeight()) {
   Row(Modifier.fillMaxWidth().height(48.dp).padding(horizontal=24.dp),verticalAlignment=Alignment.CenterVertically){Text("PrintQuote 3D",fontWeight=FontWeight.SemiBold);Spacer(Modifier.weight(1f));if(w.busy)Text("Working…",color=Muted);w.message?.let{Text(it,color=Blue)}}
   HorizontalDivider(color=Color(0xff363b3c))
   if(w.library==null)Box(Modifier.fillMaxSize(),contentAlignment=Alignment.Center){Text(if(w.error==null)"Loading your workshop…" else "Workspace could not be loaded. Your existing data has been preserved.")}
   else when(w.screen){
    "Dashboard"->Dashboard(w)
    "New Estimate"->w.draft?.let{QuoteEditor(w,it)}
    "Quotes"->Library(w,"quotes")
    "Materials"->Materials(w)
    "Printers"->Library(w,"printers")
    "Presets"->Library(w,"presets")
    "Settings"->Column(Modifier.padding(24.dp)){Text("Settings",fontSize=28.sp,fontWeight=FontWeight.Bold);Spacer(Modifier.height(20.dp));Action("Edit business defaults"){w.edit("settings",w.library!!.getJSONObject("settings"))};Text("Data stored in ${dataHome()}",color=Muted,modifier=Modifier.padding(top=24.dp))}
    "Customers"->Column(Modifier.padding(24.dp)){Text("Customers",fontSize=28.sp);w.entries("quotes").map{it.text("customer")}.filter{it.isNotBlank()}.distinct().forEach{Text(it,Modifier.padding(12.dp))};Text("Customers are collected from your saved quotes.",color=Muted)}
    "Pricing Sources"->Sources(w)
    else->Column(Modifier.padding(24.dp)){Text(w.screen,fontSize=28.sp,fontWeight=FontWeight.Bold);Text("${w.screen} workspace",Modifier.padding(top=20.dp));Text("This section is reserved for the next release, matching the current Mac application.",color=Muted)}
   }
  }
 }
 if(w.error!=null && w.editor==null && w.product==null)AlertDialog(onDismissRequest={w.error=null},title={Text("Unable to complete action")},text={Text(w.error!!)},confirmButton={TextButton(onClick={w.error=null}){Text("OK")}})
 w.editor?.let{d->DialogWindow(onCloseRequest={w.editor=null},onPreviewKeyEvent={e->if(e.type==KeyEventType.KeyDown && e.isCtrlPressed && e.key==Key.S){w.save(w.kind,d.json);true}else if(e.type==KeyEventType.KeyDown && e.key==Key.Escape){w.editor=null;true}else false},title="Edit ${w.kind}",state=rememberDialogState(width=700.dp,height=760.dp)){MaterialTheme(colorScheme=workshopColors()){Surface{Column(Modifier.fillMaxSize().padding(20.dp)){Row(verticalAlignment=Alignment.CenterVertically){Text("Edit ${if(w.kind=="filaments")"material" else w.kind}",fontSize=24.sp);Spacer(Modifier.weight(1f));Action("Save"){w.save(w.kind,d.json)};if(w.kind=="filaments")TextButton(onClick={w.save("filaments",d.json){w.useMaterial(d.json)}}){Text("Save & use")}};w.error?.let{Text(it,color=MaterialTheme.colorScheme.error)};Column(Modifier.weight(1f).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(10.dp)){LibraryEditor(d,w.kind)};TextButton(onClick={w.editor=null}){Text("Cancel")}}}}}}
 w.picker?.let{k->DialogWindow(onCloseRequest={w.picker=null},onPreviewKeyEvent={dismissOnEscape(it){w.picker=null}},title="Choose ${if(k=="filaments")"material"else k}",state=rememberDialogState(width=700.dp,height=650.dp)){MaterialTheme(colorScheme=workshopColors()){Surface{Column(Modifier.padding(20.dp)){LibraryRows(w.entries(k),k){w.choose(it)}}}}}}
 w.product?.let{ProductDialog(w,it)}
}
@Composable fun Dashboard(w:Workspace){Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp)){
 Text("Your workshop, in focus.",fontSize=30.sp,fontWeight=FontWeight.Bold);Text("Turn production costs into clear, confident quotes.",color=Muted,modifier=Modifier.padding(top=6.dp,bottom=24.dp))
 Row(horizontalArrangement=Arrangement.spacedBy(14.dp)){listOf("Saved quotes" to "quotes","Printer profiles" to "printers","Saved materials" to "filaments").forEach{(label,k)->Column(Modifier.weight(1f).background(Panel,RoundedCornerShape(12.dp)).padding(20.dp)){Text(label,color=Muted);Text(w.entries(k).size.toString(),fontSize=32.sp,fontWeight=FontWeight.Bold,modifier=Modifier.padding(top=12.dp))}}}
 Spacer(Modifier.height(24.dp));Block("Start with the production cost"){Text("Account for material, machine time, energy, labor and your margin.",color=Muted,modifier=Modifier.padding(vertical=12.dp));Action("Create estimate"){w.newQuote()};Spacer(Modifier.height(12.dp))}
 Block("Recent quotes"){if(w.entries("quotes").isEmpty())Text("Your saved quotes will appear here.",color=Muted,modifier=Modifier.padding(12.dp));w.entries("quotes").take(5).forEach{q->Row(Modifier.fillMaxWidth().clickable{w.open(q)}.padding(12.dp)){Text(q.text("projectName"),Modifier.weight(1f));Text(q.optJSONObject("result")?.let{money(it,"total",q.text("currency","USD"))}?:"Draft")}}}
}}
@Composable fun Library(w:Workspace,k:String){Column(Modifier.fillMaxSize().padding(24.dp)){Row(verticalAlignment=Alignment.CenterVertically){Text(if(k=="filaments")"Saved materials" else k.replaceFirstChar{it.uppercase()},fontSize=28.sp,fontWeight=FontWeight.Bold);Spacer(Modifier.weight(1f));Action(if(k=="quotes")"New estimate" else "Add ${if(k=="printers")"printer"else if(k=="filaments")"material"else "preset"}"){when(k){"quotes"->w.newQuote();"printers"->w.edit(k,Defaults.printer());"filaments"->w.edit(k,Defaults.material());else->w.edit(k,Defaults.preset())}}};Spacer(Modifier.height(16.dp));LibraryRows(w.entries(k),k,onDelete={w.delete(k,it.text("id"))}){if(k=="quotes")w.open(it)else w.edit(k,it)}}}
@Composable fun LibraryRows(entries:List<JSONObject>,k:String,onDelete:((JSONObject)->Unit)?=null,onOpen:(JSONObject)->Unit){var query by remember{mutableStateOf("")};var remove by remember{mutableStateOf<JSONObject?>(null)}
 SearchField(query,{query=it},"Search ${if(k=="filaments")"materials"else k}");Text("${entries.size} records",color=Muted,fontSize=12.sp,modifier=Modifier.padding(vertical=10.dp))
 LazyColumn(Modifier.fillMaxSize()){items(entries.filter{title(it,k).contains(query,true)},key={it.text("id")}){o->Row(Modifier.fillMaxWidth().clickable{onOpen(o)}.padding(vertical=12.dp),verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Text(title(o,k),fontWeight=FontWeight.Medium);Text(when(k){"printers"->"${o.text("buildVolumeXMM")} × ${o.text("buildVolumeYMM")} × ${o.text("buildVolumeZMM")} mm";"filaments"->"${o.text("materialFamily")} · ${money(o,"pricePerKG")}/kg";"quotes"->"${o.text("number")} · ${o.text("customer")} · ${o.text("status")}";else->o.text("mode")},color=Muted,fontSize=12.sp)};if(k=="quotes")o.optJSONObject("result")?.let{Text(money(it,"total",o.text("currency","USD")),color=Blue)};if(onDelete!=null)TextButton(onClick={remove=o}){Text("Delete",color=Muted)}};HorizontalDivider(color=Color(0xff363b3c))}}
 remove?.let{o->AlertDialog(onDismissRequest={remove=null},title={Text("Delete ${title(o,k)}?")},text={Text("Existing quote snapshots will be retained.")},confirmButton={TextButton(onClick={onDelete?.invoke(o);remove=null}){Text("Delete")}},dismissButton={TextButton(onClick={remove=null}){Text("Cancel")}})}
}

@Composable fun SearchField(value:String,onChange:(String)->Unit,placeholder:String){
 val requester=remember{FocusRequester()};val request=LocalSearchRequest.current
 LaunchedEffect(request){if(request>0)requester.requestFocus()}
 OutlinedTextField(value,onChange,placeholder={Text(placeholder)},singleLine=true,modifier=Modifier.fillMaxWidth().focusRequester(requester))
}

fun workshopColors()=darkColorScheme(primary=Blue,onPrimary=Color.White,background=Graphite,surface=Graphite,onSurface=Color(0xffeeeeee),surfaceVariant=Panel)
fun dismissOnEscape(e:KeyEvent,close:()->Unit):Boolean {if(e.type==KeyEventType.KeyDown && e.key==Key.Escape){close();return true};return false}
