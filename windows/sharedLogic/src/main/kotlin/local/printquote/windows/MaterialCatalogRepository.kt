package local.printquote.windows

import com.google.gson.stream.JsonReader
import com.google.gson.stream.JsonToken
import local.printquote.android.model.*
import org.json.JSONObject
import org.json.JSONArray
import java.io.Reader

data class CatalogEntry(val id:String,val name:String,val brand:String,val family:String)

/** Stream the large shared OFD catalog; keep only its small searchable index in memory. */
class MaterialCatalogRepository(private val open:()->Reader) {
    fun index():List<CatalogEntry> = open().use { reader ->
        val json=JsonReader(reader); val result=mutableListOf<CatalogEntry>(); json.beginObject()
        while(json.hasNext()) {
            if(json.nextName()!="products") { json.skipValue(); continue }
            json.beginArray()
            while(json.hasNext()) {
                var id=""; var name=""; var brand=""; var family=""; json.beginObject()
                while(json.hasNext()) when(json.nextName()) { "id"->id=json.nextString(); "name"->name=json.nextString(); "brand"->brand=json.nextString(); "materialFamily"->family=json.nextString(); else->json.skipValue() }
                json.endObject(); result.add(CatalogEntry(id,name,brand,family))
            }; json.endArray()
        }; json.endObject(); result
    }
    fun product(id:String):Pair<JSONObject,JSONObject> = open().use { reader ->
        val json=JsonReader(reader); val metadata=JSONObject(); var found:JSONObject?=null; json.beginObject()
        while(json.hasNext()) {
            val key=json.nextName()
            if(key!="products") { metadata.put(key,readValue(json)); continue }
            json.beginArray()
            while(json.hasNext()) {
                // Materialize one product at a time; never retain the whole catalog.
                val product=readValue(json) as JSONObject
                if(product.text("id")==id) found=product
            }; json.endArray()
        }; json.endObject(); Pair(found ?: error("Catalog product not found"),metadata)
    }
    private fun readValue(r:JsonReader):Any = when(r.peek()) {
        JsonToken.BEGIN_OBJECT -> JSONObject().apply { r.beginObject(); while(r.hasNext()) put(r.nextName(),readValue(r)); r.endObject() }
        JsonToken.BEGIN_ARRAY -> JSONArray().apply { r.beginArray(); while(r.hasNext()) put(readValue(r)); r.endArray() }
        JsonToken.BOOLEAN -> r.nextBoolean()
        JsonToken.NULL -> { r.nextNull(); JSONObject.NULL }
        JsonToken.NUMBER -> r.nextString().toBigDecimal()
        else -> r.nextString()
    }
    companion object {
        fun material(product:JSONObject,variant:JSONObject,size:JSONObject,metadata:JSONObject,price:String):JSONObject {
            val fields=JSONObject()
            listOf(product,variant,size).forEach { o -> o.optJSONObject("fields")?.let { fs -> fs.keys().forEach { k ->
                val old=fields.optJSONObject(k); val incoming=fs.getJSONObject(k)
                if(old==null || (!old.optBoolean("userOverride") && (incoming.optBoolean("userOverride") || incoming.number("sourcePriority")<=old.number("sourcePriority")))) fields.put(k,incoming.copy())
            } } }
            val snapshot=metadata.copy().put("productID",product.text("id")).put("variantID",variant.text("id")).put("sizeID",size.text("id")).put("fields",fields).put("userOverride",false)
            return Defaults.material().put("id",size.text("id")).put("manufacturer",product.text("brand")).put("productName",product.text("name")).put("materialFamily",product.text("materialFamily"))
                .put("colorName",variant.text("name")).put("diameterMM",size.decimal("diameterMM")).put("netWeightGrams",size.decimal("netWeightGrams")).put("pricePerKG",price.toBigDecimal())
                .put("catalogSnapshot",snapshot).put("source",doc("name" to metadata.text("sourceName"),"url" to metadata.text("sourceURL"),"sourceType" to "catalog","notes" to "Offline catalog. Price entered by user. ${metadata.text("sourceLicense")} license."))
        }
    }
}
