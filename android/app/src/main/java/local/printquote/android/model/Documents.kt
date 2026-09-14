package local.printquote.android.model

import org.json.JSONArray
import org.json.JSONObject
import java.math.BigDecimal
import java.util.UUID

// Documents retain the Swift JSON keys and unknown provenance fields on edits.
fun JSONObject.copy(): JSONObject = JSONObject(toString())
fun JSONObject.array(key: String): List<JSONObject> = optJSONArray(key)?.objects() ?: emptyList()
fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }
fun JSONObject.text(key: String, fallback: String = ""): String = if (isNull(key)) fallback else optString(key, fallback)
fun JSONObject.decimal(key: String, fallback: String = "0"): BigDecimal =
    text(key, fallback).toBigDecimalOrNull() ?: error("$key must be a valid number")
fun JSONObject.number(key: String, fallback: Int = 0): Int {
    val n = decimal(key, fallback.toString())
    return try { n.intValueExact() } catch (_: ArithmeticException) { error("$key must be a whole number") }
}
fun doc(vararg entries: Pair<String, Any?>) = JSONObject().apply { entries.forEach { (k,v) -> if(v != null) put(k,v) } }
fun array(items: List<JSONObject>) = JSONArray(items)
fun uuid() = UUID.randomUUID().toString()
fun swiftNow() = System.currentTimeMillis() / 1000.0 - 978307200
fun source() = doc("name" to "User entered", "sourceType" to "userEntered", "notes" to "Review actual shop costs before quoting.")

object Defaults {
    val inputNumbers = linkedMapOf(
        "modelGrams" to "200", "supportGrams" to "50", "interfaceGrams" to "0", "purgeGrams" to "30", "towerGrams" to "0", "startupGrams" to "0",
        "pricePerKG" to "20", "supportPricePerKG" to "20", "interfacePricePerKG" to "20", "printHours" to "10", "averageWatts" to "150",
        "electricityRate" to "0.14", "machineRate" to "1", "maintenanceRate" to "0.25", "laborMinutes" to "30", "laborRate" to "30",
        "dryerWatts" to "0", "dryingHours" to "0", "dryingSharedJobs" to "1", "wearCost" to "0", "packaging" to "0", "outsideServices" to "0", "otherCosts" to "0",
        "failureProbability" to "0", "overheadRate" to "0", "profitRate" to "0.4", "materialMultiplier" to "1", "minimumCharge" to "0", "rushMultiplier" to "1", "discountRate" to "0", "taxRate" to "0", "shipping" to "0")
    fun input() = JSONObject().apply { inputNumbers.forEach { (k,v) -> put(k, v.toBigDecimal()) }; put("pricingMode", "margin") }
    fun tool(index: Int) = doc("id" to uuid(), "index" to index, "name" to "Tool $index", "nozzleDiameterMM" to 0.4,
        "nozzleMaterial" to "unknown", "supportedMaterialFamilies" to JSONArray(), "abrasiveMaterialsAllowed" to false, "flexibleMaterialsAllowed" to false,
        "changeOverheadSeconds" to 0, "purgeGramsPerActivation" to 0, "wipeGramsPerActivation" to 0, "additionalHeaterWatts" to 0,
        "parkedHeaterWatts" to 0, "maintenancePerHour" to 0, "nozzleReplacementCost" to 0, "nozzleLifeHours" to 1000, "abrasiveWearMultiplier" to 1, "needsReview" to true)
    fun system() = doc("availableToolheadCount" to 1, "toolheads" to array(listOf(tool(1))), "architecture" to "singleTool", "simultaneousToolUseCount" to 1,
        "filamentInputCount" to 1, "feederSlotCount" to 0, "maxSimultaneousMaterials" to 1, "maxAutomaticSelectableMaterials" to 1,
        "automaticMaterialSwitching" to false, "sharedNozzle" to true, "materialSwitchSeconds" to 0, "purgeGramsPerMaterialSwitch" to 0, "needsReview" to true)
    fun resize(system: JSONObject, count: Int) {
        require(count in 1..12)
        val old = system.array("toolheads")
        system.put("toolheads", array((1..count).map { old.getOrNull(it-1) ?: tool(it) }))
        system.put("availableToolheadCount", count)
        system.put("simultaneousToolUseCount", minOf(system.number("simultaneousToolUseCount",1), count))
        system.put("maxSimultaneousMaterials", minOf(system.number("maxSimultaneousMaterials",1), count))
        system.put("needsReview", true)
    }
    fun hardware() = doc("typicalPowerQuality" to "unknown", "activeChamberHeating" to false, "buildVolumeByOperatingMode" to JSONArray(), "installedAccessories" to JSONArray(), "fieldSources" to JSONObject())
    fun printer() = doc("id" to uuid(), "manufacturer" to "Custom", "model" to "New printer", "buildVolumeXMM" to 220, "buildVolumeYMM" to 220, "buildVolumeZMM" to 250,
        "typicalPowerWatts" to 150, "machineRate" to 1, "maintenanceRate" to 0.25, "multiMaterialSystem" to "none", "source" to source(), "toolSystem" to system(), "hardware" to hardware())
    fun material() = doc("id" to uuid(), "manufacturer" to "Generic", "productName" to "New material", "materialFamily" to "PLA", "colorName" to "Natural",
        "diameterMM" to 1.75, "netWeightGrams" to 1000, "pricePerKG" to 20, "source" to source())
    fun preset() = doc("id" to uuid(), "name" to "Custom", "mode" to "margin", "rate" to 0.4, "materialMultiplier" to 1, "machineRate" to 1, "laborRate" to 30, "minimumCharge" to 10, "rushMultiplier" to 1)
    fun assignment() = doc("id" to uuid(), "toolIndex" to 1, "materialName" to "Manual material", "materialFamily" to "PLA", "colorName" to "Natural", "role" to "model",
        "grams" to 0, "pricePerKG" to 20, "activeHours" to 0, "activationCount" to 0, "abrasive" to false, "flexible" to false)
    fun selectPrinter(q: JSONObject, p: JSONObject) {
        q.put("printer", p.copy()); val i = q.getJSONObject("input")
        i.put("averageWatts", p.decimal("typicalPowerWatts")); i.put("machineRate", p.decimal("machineRate")); i.put("maintenanceRate", p.decimal("maintenanceRate"))
        i.optJSONObject("toolJob")?.put("system", (p.optJSONObject("toolSystem") ?: system()).copy())
    }
    fun selectMaterial(q: JSONObject, m: JSONObject) {
        q.put("filament", m.copy()); listOf("pricePerKG","supportPricePerKG","interfacePricePerKG").forEach { q.getJSONObject("input").put(it, m.decimal("pricePerKG")) }
    }
    fun quote(library: JSONObject): JSONObject {
        val s = library.getJSONObject("settings")
        val q = doc("id" to uuid(), "number" to "PQ-${uuid().take(8).uppercase()}", "projectName" to "Untitled project", "customer" to "", "status" to "draft",
            "createdAt" to swiftNow(), "expiresAt" to swiftNow()+s.number("expirationDays",30)*86400, "currency" to s.text("currency","USD"), "notes" to "", "schemaVersion" to 2, "input" to input())
        q.getJSONObject("input").put("electricityRate", s.decimal("electricityRate","0.14")).put("taxRate", s.decimal("taxRate"))
        library.array("printers").firstOrNull()?.let { selectPrinter(q,it) }
        library.array("filaments").firstOrNull()?.let { selectMaterial(q,it) }
        return q
    }
    fun enableTools(q: JSONObject) {
        val i = q.getJSONObject("input"); val m = q.optJSONObject("filament")
        val assignments = listOf(Triple("model","modelGrams","pricePerKG"),Triple("support","supportGrams","supportPricePerKG"),Triple("interface","interfaceGrams","interfacePricePerKG"),Triple("waste","purgeGrams","pricePerKG")).mapNotNull { (role,key,price) ->
            val grams = i.decimal(key) + if (role=="waste") i.decimal("towerGrams")+i.decimal("startupGrams") else BigDecimal.ZERO
            if(grams.signum()==0) null else assignment().put("role",role).put("grams",grams).put("pricePerKG",i.decimal(price)).apply {
                if(m!=null) { put("materialID",m.text("id")); put("materialName",m.text("manufacturer")+" "+m.text("productName")); put("materialFamily",m.text("materialFamily")); put("colorName",m.text("colorName")) }
            }
        }
        i.put("toolJob",doc("system" to (q.optJSONObject("printer")?.optJSONObject("toolSystem") ?: system()).copy(), "assignments" to array(assignments.ifEmpty { listOf(assignment()) })))
    }
}
