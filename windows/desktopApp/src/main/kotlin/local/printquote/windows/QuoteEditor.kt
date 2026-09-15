package local.printquote.windows
import androidx.compose.foundation.*
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.*
import androidx.compose.ui.graphics.*
import androidx.compose.ui.text.*
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.*
import local.printquote.android.model.*
import local.printquote.android.viewmodel.Draft
import local.printquote.android.pricing.*
import org.json.JSONObject
import java.time.*

@Composable fun FormRow(d:Draft,o:JSONObject,key:String,name:String,numeric:Boolean=false){
 d.revision
 Row(Modifier.fillMaxWidth().heightIn(min=42.dp).padding(vertical=9.dp),verticalAlignment=Alignment.CenterVertically){
  Text(name,Modifier.weight(1f),fontSize=14.sp)
  BasicTextField(o.text(key),onValueChange={v->d.change{o.put(key,if(numeric)v.toBigDecimalOrNull()?:v else v)}},textStyle=TextStyle(color=MaterialTheme.colorScheme.onSurface,fontSize=14.sp,textAlign=TextAlign.End),cursorBrush=SolidColor(Blue),singleLine=key!="notes",modifier=Modifier.weight(1f).padding(start=12.dp))
 };HorizontalDivider(color=MaterialTheme.colorScheme.outlineVariant)
}
@Composable fun QuoteEditor(w:Workspace,d:Draft){
 LaunchedEffect(d.revision){if(d.revision>0)w.autosave(d.json.toString())}
 d.revision;val q=d.json;val i=q.getJSONObject("input");val calculation=runCatching{PricingEngine.calculate(i)}
 Column(Modifier.fillMaxSize().padding(24.dp)){
  Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Text("New estimate",fontSize=28.sp,fontWeight=FontWeight.Bold);Text(q.text("number"),color=Muted)};Action("Save quote"){w.saveQuote()}}
  Text(w.autosaveStatus,color=Muted)
  Spacer(Modifier.height(24.dp))
  BoxWithConstraints(Modifier.weight(1f)){
   if(maxWidth>=710.dp)Row(Modifier.fillMaxSize(),horizontalArrangement=Arrangement.spacedBy(20.dp)){
    ScrollColumn(Modifier.weight(1.4f).fillMaxHeight()){QuoteFields(w,d)}
    VerticalDivider(color=MaterialTheme.colorScheme.outlineVariant)
    ScrollColumn(Modifier.weight(1f).fillMaxHeight()){Breakdown(calculation,q.text("currency","USD"))}
   }else ScrollColumn(Modifier.fillMaxSize()){QuoteFields(w,d);Breakdown(calculation,q.text("currency","USD"))}
  }
 }
}
@Composable fun QuoteFields(w:Workspace,d:Draft){
 d.revision;val q=d.json;val i=q.getJSONObject("input")
 Block("Project"){
  FormRow(d,q,"projectName","Project name");FormRow(d,q,"customer","Customer")
  Choice(d,q,"status",listOf("draft","sent","accepted","declined","expired"))
  var expiry by remember(d){mutableStateOf(Instant.ofEpochSecond(q.decimal("expiresAt").toLong()+978307200).atZone(ZoneId.systemDefault()).toLocalDate().toString())}
  var invalidDate by remember(d){mutableStateOf(false)}
  OutlinedTextField(expiry,{v->expiry=v;val date=runCatching{LocalDate.parse(v)}.getOrNull();invalidDate=date==null;d.change{q.put("expiresAt",date?.atStartOfDay(ZoneId.systemDefault())?.toEpochSecond()?.minus(978307200)?:v)}},label={Text("Expires (YYYY-MM-DD)")},isError=invalidDate,modifier=Modifier.fillMaxWidth(),singleLine=true)
  FormRow(d,q,"notes","Notes")
 }
 Block("Equipment & material"){
  TextButton(onClick={w.picker="printers"}){Text(q.optJSONObject("printer")?.let{title(it,"printers")}?:"Choose printer")}
  TextButton(onClick={w.picker="filaments"}){Text(q.optJSONObject("filament")?.let{title(it,"filaments")}?:"Choose material")}
  TextButton(onClick={w.picker="presets"}){Text(q.optJSONObject("preset")?.text("name")?:"Apply pricing preset")}
 }
 Block("Material consumption"){
  listOf("modelGrams" to "Model (g)","supportGrams" to "Supports (g)","interfaceGrams" to "Support interface (g)","purgeGrams" to "Purge / flush (g)","towerGrams" to "Prime tower (g)","startupGrams" to "Startup purge (g)","pricePerKG" to "Model price / kg","supportPricePerKG" to "Support price / kg","interfacePricePerKG" to "Interface price / kg").forEach{(k,t)->FormRow(d,i,k,t,true)}
 }
 Block("Tools & material assignments"){
  Row(Modifier.fillMaxWidth(),verticalAlignment=Alignment.CenterVertically){Text("Use per-tool calculation",Modifier.weight(1f));Switch(i.optJSONObject("toolJob")!=null,{enabled->d.change{if(enabled)Defaults.enableTools(q)else i.remove("toolJob")}})}
  i.optJSONObject("toolJob")?.let{job->
   Text("Assignments replace aggregate material grams above.",color=Muted,fontSize=12.sp)
   Fold("Tool configuration"){ToolSystemFields(d,job.getJSONObject("system"))}
   job.array("assignments").forEach{a->key(a.text("id")){Fold("${a.text("materialName")} · Tool ${a.text("toolIndex")}"){
    Field(d,a,"materialName");Field(d,a,"materialFamily");Field(d,a,"colorName")
    Choice(d,a,"role",listOf("model","support","interface","waste"))
    Fields(d,a,listOf("toolIndex","grams","pricePerKG","activeHours","activationCount"));Field(d,a,"feederSlot",numeric=true,optional=true)
    Toggle(d,a,"abrasive");Toggle(d,a,"flexible")
    TextButton(onClick={d.change{job.put("assignments",array(job.array("assignments").filterNot{it.text("id")==a.text("id")}))}}){Text("Remove assignment")}
   }}}
   TextButton(onClick={d.change{job.put("assignments",array(job.array("assignments")+Defaults.assignment()))}}){Text("Add material assignment")}
  }
 }
 Block("Time & operating costs"){
  listOf("printHours" to "Print time (hours)","averageWatts" to "Average power (W)","electricityRate" to "Electricity / kWh","machineRate" to "Machine / hour","maintenanceRate" to "Maintenance / hour","wearCost" to "Nozzle / consumable wear","laborMinutes" to "Labor (minutes)","laborRate" to "Labor / hour","dryerWatts" to "Dryer power (W)","dryingHours" to "Drying (hours)","dryingSharedJobs" to "Jobs sharing dryer").forEach{(k,t)->FormRow(d,i,k,t,true)}
 }
 Block("Direct costs & risk"){
  listOf("packaging" to "Packaging","outsideServices" to "Outside services","otherCosts" to "Other direct costs","failureProbability" to "Failure reserve (0–1)","overheadRate" to "Overhead rate (0–1)").forEach{(k,t)->FormRow(d,i,k,t,true)}
 }
 Block("Pricing"){
  Choice(d,i,"pricingMode",listOf("margin","markup"));Text("Rates use decimals: 0.40 = 40%.",color=Muted,fontSize=12.sp)
  listOf("profitRate" to "Profit rate","materialMultiplier" to "Material multiplier","minimumCharge" to "Minimum charge","rushMultiplier" to "Rush multiplier","discountRate" to "Discount rate","taxRate" to "Tax rate","shipping" to "Shipping").forEach{(k,t)->FormRow(d,i,k,t,true)}
 }
}
@Composable fun Breakdown(result:Result<JSONObject>,currency:String){
 if(result.isFailure){Text("Check estimate inputs",fontWeight=FontWeight.Bold,color=MaterialTheme.colorScheme.error);Text(result.exceptionOrNull()?.message?:"Invalid values",Modifier.padding(top=12.dp));return}
 val r=result.getOrThrow()
 Text("COST BREAKDOWN",color=Muted,fontSize=13.sp,fontWeight=FontWeight.Bold,modifier=Modifier.padding(bottom=14.dp))
 fun value(key:String)=money(r,key,currency)
 r.array("components").filter{it.decimal("amount").signum()!=0}.forEach{c->Amount(c.text("name"),money(c,"amount",currency))}
 HorizontalDivider(Modifier.padding(vertical=12.dp));Amount("Production cost",value("productionCost"));Amount("Overhead",value("overhead"))
 HorizontalDivider(Modifier.padding(vertical=12.dp));Text("CUSTOMER PRICE",color=Muted,fontWeight=FontWeight.Bold,fontSize=13.sp);Text(value("total"),fontSize=42.sp,fontWeight=FontWeight.Bold,color=Blue,modifier=Modifier.padding(vertical=18.dp))
 listOf("subtotal","discount","tax","shipping").forEach{Amount(it.replaceFirstChar{it.uppercase()},value(it))}
 HorizontalDivider(Modifier.padding(vertical=12.dp));Text("Consumed: ${rounded(r.decimal("totalGrams"))} g",color=Muted)
 Text("Material efficiency: ${r.decimal("materialEfficiency").multiply(100.toBigDecimal()).setScale(1,java.math.RoundingMode.HALF_UP)}%",color=Muted,modifier=Modifier.padding(top=8.dp))
 val warnings=r.optJSONArray("warnings");if(warnings!=null)(0 until warnings.length()).forEach{Text(warnings.getString(it),color=MaterialTheme.colorScheme.error,fontSize=12.sp,modifier=Modifier.padding(top=12.dp))}
}
@Composable fun Amount(name:String,value:String){Row(Modifier.fillMaxWidth().padding(vertical=8.dp),horizontalArrangement=Arrangement.spacedBy(12.dp)){Text(name,Modifier.weight(1f),fontSize=14.sp);Text(value,fontSize=14.sp)}}

@Composable fun ScrollColumn(modifier:Modifier=Modifier,content:@Composable ColumnScope.()->Unit){
 val scroll=rememberScrollState()
 Box(modifier){Column(Modifier.fillMaxSize().padding(end=12.dp).verticalScroll(scroll),content=content);VerticalScrollbar(rememberScrollbarAdapter(scroll),Modifier.align(Alignment.CenterEnd).fillMaxHeight())}
}
