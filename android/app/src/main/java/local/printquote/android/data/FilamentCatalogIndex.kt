package local.printquote.android.data

import java.text.Normalizer
import java.util.UUID
import local.printquote.android.model.*
import org.json.JSONObject

data class CatalogRecord(val id:String,val name:String,val brand:String,val family:String,val productID:String=id,val variantID:String="",val color:String="",val spool:String="",val tokens:String="",val difficulty:String="",val drying:String="")
data class CatalogRejection(val sourceID:String,val reason:String,val count:Int=1)
data class CatalogDiagnostics(var products:Int=0,var variants:Int=0,var discovered:Int=0,var decoded:Int=0,var normalized:Int=0,var rejected:Int=0,var inserted:Int=0,var updated:Int=0,var duplicates:Int=0,var stored:Int=0,val quarantine:MutableList<CatalogRejection> = mutableListOf())
data class CatalogQuery(val text:String="",val families:Set<String> = emptySet(),val brands:Set<String> = emptySet(),val favoritesOnly:Boolean=false,val recentOnly:Boolean=false,val sort:String="Name",val offset:Int=0,val limit:Int=100)
data class CatalogPage(val rows:List<CatalogRecord>,val matches:Int,val total:Int)

/** One identity per spool option. Product, color and spool IDs remain independent. */
class CatalogNormalizer {
 val diagnostics=CatalogDiagnostics()
 private val seen=mutableSetOf<String>()
 fun product(product:JSONObject):List<CatalogRecord> {
  diagnostics.products++;val result=mutableListOf<CatalogRecord>()
  if(product.array("variants").isEmpty())diagnostics.quarantine.add(CatalogRejection(product.text("id"),"Product has no color variants or searchable spool options",0))
  for(variant in product.array("variants")) {
   if(variant.array("sizes").isEmpty())diagnostics.quarantine.add(CatalogRejection(variant.text("id"),"Color variant has no spool sizes",0))
   diagnostics.variants++
   for(size in variant.array("sizes")) {
    if(Thread.currentThread().isInterrupted)throw InterruptedException("Catalog refresh canceled")
    diagnostics.discovered++;diagnostics.decoded++
    val id=size.text("id")
    val reason=when {
     listOf(product.text("id"),variant.text("id"),id).any{value->!runCatching{UUID.fromString(value).toString().equals(value,true)}.getOrDefault(false)}->"Invalid identifier"
     product.text("materialFamily").isBlank()->"Missing material family"
     product.text("brand").isBlank() || product.text("name").isBlank()->"Missing brand or product name"
     variant.text("colorHex").isNotBlank() && !variant.text("colorHex").removePrefix("#").matches(Regex("(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})"))->"Malformed color value"
     (!size.isNull("diameterMM") && (!size.optDouble("diameterMM",0.0).isFinite() || size.optDouble("diameterMM",0.0)<=0)) || (!size.isNull("netWeightGrams") && (!size.optDouble("netWeightGrams",0.0).isFinite() || size.optDouble("netWeightGrams",0.0)<=0))->"Invalid spool size"
     else->null
    }
    if(reason!=null){diagnostics.rejected++;diagnostics.quarantine.add(CatalogRejection(id,reason));continue}
    if(!seen.add(id.lowercase())){diagnostics.duplicates++;diagnostics.quarantine.add(CatalogRejection(id,"Duplicate external spool ID"));continue}
    val evidence=listOf(product,variant,size).joinToString(" "){it.optJSONObject("fields")?.toString().orEmpty()}
    fun field(key:String)=listOf(size,variant,product).firstNotNullOfOrNull{it.optJSONObject("fields")?.optJSONObject(key)?.optString("value")?.takeIf{v->v.isNotBlank()}} ?: ""
    result.add(CatalogRecord(id,product.text("name"),product.text("brand"),product.text("materialFamily"),product.text("id"),variant.text("id"),variant.text("name"),"${size.text("diameterMM")} mm · ${size.text("netWeightGrams")} g",evidence,field("difficulty"),field("drying_required")))
    diagnostics.normalized++;diagnostics.inserted++;diagnostics.stored++
   }
  }
  return result
 }
}
/** Repository-level inverted token and dimension indexes. Only a bounded page reaches Compose. */
class FilamentCatalogIndex(private val rows:List<CatalogRecord>) {
 private val words=sortedMapOf<String,MutableSet<Int>>()
 private val brands=mutableMapOf<String,MutableSet<Int>>()
 private val families=mutableMapOf<String,MutableSet<Int>>()
 init {rows.forEachIndexed{i,r->if(Thread.currentThread().isInterrupted)throw InterruptedException("Index rebuild canceled");tokens("${r.brand} ${r.name} ${r.family} ${r.color} ${r.tokens}").forEach{words.getOrPut(it){mutableSetOf()}.add(i)};brands.getOrPut(r.brand){mutableSetOf()}.add(i);families.getOrPut(r.family){mutableSetOf()}.add(i)}}
 val manufacturers:List<String> get()=brands.keys.sorted()
 val materialFamilies:List<String> get()=families.keys.sorted()
 fun search(q:CatalogQuery,favorites:Set<String> = emptySet(),recent:Map<String,Long> = emptyMap(),prices:Map<String,Double> = emptyMap()):CatalogPage {
  var candidates:Set<Int>?=null
  fun narrow(ids:Set<Int>){candidates=candidates?.intersect(ids) ?: ids}
  for(word in tokens(q.text).take(20)){val ids=mutableSetOf<Int>();for((key,value) in words.tailMap(word)){if(!key.startsWith(word))break;ids.addAll(value)};narrow(ids)}
  if(q.brands.isNotEmpty())narrow(q.brands.flatMap{brands[it].orEmpty()}.toSet())
  if(q.families.isNotEmpty())narrow(q.families.flatMap{families[it].orEmpty()}.toSet())
  val selected=(candidates ?: rows.indices.toSet()).asSequence().map{rows[it]}.filter{!q.favoritesOnly || it.id in favorites}.filter{!q.recentOnly || it.id in recent}.toList()
  val comparator=when(q.sort){"Price / kg"->compareBy<CatalogRecord>{prices[it.id] ?: Double.POSITIVE_INFINITY}.thenBy{it.name};"Difficulty"->compareBy<CatalogRecord>{it.difficulty.isBlank()}.thenBy{it.difficulty.lowercase()}.thenBy{it.name};"Drying Requirement"->compareBy<CatalogRecord>{it.drying.isBlank()}.thenBy{it.drying.lowercase()}.thenBy{it.name};"Manufacturer"->compareBy<CatalogRecord>{it.brand.lowercase()}.thenBy{it.name.lowercase()};"Material"->compareBy<CatalogRecord>{it.family}.thenBy{it.name};"Favorite"->compareByDescending<CatalogRecord>{it.id in favorites}.thenBy{it.name};"Recently Used"->compareByDescending<CatalogRecord>{recent[it.id] ?: 0}.thenBy{it.name};else->compareBy<CatalogRecord>{it.name.lowercase()}.thenBy{it.color.lowercase()}.thenBy{it.id}}
  return CatalogPage(selected.sortedWith(comparator).drop(q.offset.coerceAtLeast(0)).take(q.limit.coerceIn(1,200)),selected.size,rows.size)
 }
 companion object {fun tokens(text:String)=Normalizer.normalize(text,Normalizer.Form.NFD).replace(Regex("\\p{M}+"),"").lowercase().split(Regex("[^\\p{L}\\p{N}]+")).filter{it.isNotEmpty()}.toSet()}
}

/** Diagnostic export intentionally excludes quotes, customer names and inventory prices. */
fun CatalogDiagnostics.supportJSON(displayed:Int):String=JSONObject().put("appVersion","0.4.0").put("schemaVersion",2).put("database","bundled-open-filaments-v2")
 .put("products",products).put("variants",variants).put("discovered",discovered).put("decoded",decoded).put("normalized",normalized).put("rejected",rejected).put("inserted",inserted).put("updated",updated).put("duplicates",duplicates).put("stored",stored).put("displayedAfterFilters",displayed)
 .put("quarantine",org.json.JSONArray(quarantine.map{JSONObject().put("sourceID",it.sourceID).put("reason",it.reason).put("count",it.count)})).toString(2)

fun inlineMaterialEdit(original:JSONObject,column:String,value:String):JSONObject {
 val edited=original.copy()
 when(column){
  "Price / kg"->{val amount=value.toBigDecimalOrNull();require(amount!=null && amount.signum()>=0){"Enter a valid nonnegative price per kg"};edited.put("pricePerKG",amount)}
  "Stock (g)"->{val amount=value.toBigDecimalOrNull();require(amount!=null && amount.signum()>=0){"Enter valid nonnegative remaining grams"};val stock=edited.optJSONObject("stock") ?: doc("spoolCount" to 0,"remainingGrams" to 0,"location" to "","notes" to "");stock.put("remainingGrams",amount);edited.put("stock",stock)}
  "Nickname"->{require(value.isNotBlank()){ "Enter a product nickname" };edited.put("productName",value)}
  "Notes"->{val stock=edited.optJSONObject("stock") ?: doc("spoolCount" to 0,"remainingGrams" to 0,"location" to "","notes" to "");stock.put("notes",value);edited.put("stock",stock)}
 }
 return edited
}

fun sortDiscoveryRecords(kind:String,rows:List<JSONObject>,sort:String,favorites:Set<String> = emptySet(),recent:Map<String,Long> = emptyMap()):List<JSONObject> {
 fun name(o:JSONObject)=when(kind){"printers"->o.text("manufacturer")+" "+o.text("model");"filaments"->o.text("manufacturer")+" "+o.text("productName");else->o.text("name",o.text("projectName"))}.lowercase()
 val comparator=when(sort){
  "Manufacturer"->compareBy<JSONObject>{it.text("manufacturer").lowercase()}.thenBy{ name(it) }
  "Material"->compareBy<JSONObject>{it.text("materialFamily").lowercase()}.thenBy{ name(it) }
  "Price / kg"->compareBy<JSONObject>{it.decimal("pricePerKG")}.thenBy{ name(it) }
  "Build Volume"->compareByDescending<JSONObject>{it.optDouble("buildVolumeXMM",0.0)*it.optDouble("buildVolumeYMM",0.0)*it.optDouble("buildVolumeZMM",0.0)}.thenBy{ name(it) }
  "Toolheads"->compareByDescending<JSONObject>{it.optJSONObject("toolSystem")?.optInt("availableToolheadCount",1) ?: 1}.thenBy{ name(it) }
  "Recently Used"->compareByDescending<JSONObject>{recent[it.text("id")] ?: 0L}.thenBy{ name(it) }
  "Favorite"->compareByDescending<JSONObject>{it.text("id") in favorites}.thenBy{ name(it) }
  else->compareBy<JSONObject>{name(it)}
 }
 return rows.sortedWith(comparator.thenBy{it.text("id")})
}
