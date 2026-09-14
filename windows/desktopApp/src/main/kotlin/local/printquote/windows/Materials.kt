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
import java.awt.Desktop
import java.net.URI

@Composable fun Materials(w:Workspace){var tab by remember{mutableIntStateOf(0)};Column(Modifier.fillMaxSize()){
 Row(Modifier.padding(start=24.dp,top=12.dp)){TextButton(onClick={tab=0}){Text("Saved materials")};TextButton(onClick={tab=1}){Text("Browse catalog (${w.index.size})")}}
 if(tab==0)Library(w,"filaments") else Column(Modifier.padding(24.dp)){var search by remember{mutableStateOf("")};SearchField(search,{search=it},"Search brand, product or material family");Spacer(Modifier.height(12.dp));LazyColumn{items(w.index.filter{"${it.brand} ${it.name} ${it.family}".contains(search,true)},key={it.id}){p->Column(Modifier.fillMaxWidth().clickable{w.showProduct(p.id)}.padding(12.dp)){Text("${p.brand} ${p.name}");Text(p.family,color=Muted,fontSize=12.sp)};HorizontalDivider()}}}
}}
@Composable fun Select(title:String,options:List<String>,selected:Int,onSelect:(Int)->Unit){var open by remember{mutableStateOf(false)};Box{OutlinedButton(onClick={open=true}){Text("$title: ${options.getOrNull(selected)?:"None"}")};DropdownMenu(open,{open=false},modifier=Modifier.heightIn(max=320.dp)){options.forEachIndexed{i,t->DropdownMenuItem(text={Text(t)},onClick={onSelect(i);open=false})}}}}
@Composable fun ProductDialog(w:Workspace,pair:Pair<JSONObject,JSONObject>){val(product,metadata)=pair
 DialogWindow(onCloseRequest={w.product=null},onPreviewKeyEvent={dismissOnEscape(it){w.product=null}},title="Material catalog",state=rememberDialogState(width=700.dp,height=700.dp)){MaterialTheme(colorScheme=workshopColors()){Surface{Column(Modifier.padding(24.dp).verticalScroll(rememberScrollState()),verticalArrangement=Arrangement.spacedBy(12.dp)){
  w.error?.let{Text(it,color=MaterialTheme.colorScheme.error)}
  Text("${product.text("brand")} ${product.text("name")}",fontSize=24.sp)
  Text("${product.text("materialFamily")} · ${metadata.text("sourceName")}",color=Muted)
  val variants=product.array("variants");var vi by remember(product){mutableIntStateOf(0)};var si by remember(product,vi){mutableIntStateOf(0)}
  Select("Color / variant",variants.map{it.text("name")},vi){vi=it}
  val variant=variants.getOrNull(vi);val sizes=variant?.array("sizes").orEmpty()
  Select("Spool",sizes.map{"${it.text("diameterMM")} mm · ${it.text("netWeightGrams")} g"},si){si=it}
  var price by remember(product){mutableStateOf("")};OutlinedTextField(price,{price=it},label={Text("Your purchase price per kg")},singleLine=true,modifier=Modifier.fillMaxWidth())
  Text("Catalog specifications are bundled offline. Enter your actual price before saving.",color=Muted)
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
