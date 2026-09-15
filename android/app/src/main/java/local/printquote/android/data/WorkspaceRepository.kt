package local.printquote.android.data

import local.printquote.android.model.*
import local.printquote.android.pricing.PricingEngine
import org.json.JSONObject
import org.json.JSONArray
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/** Atomic private storage. Read failures never silently overwrite an existing workspace. */
class WorkspaceRepository(private val file: File, private val readAsset: (String)->String) {
    fun load(): JSONObject {
        val library=if(file.exists()) JSONObject(file.readText()) else JSONObject(readAsset("library_seed_v1.json"))
        require(library.number("schemaVersion",1) in 1..2) { "Unsupported workspace version" }
        val printers=library.array("printers").toMutableList(); val ids=printers.map { it.text("id").lowercase() }.toMutableSet()
        printers.forEach { if(it.optJSONObject("toolSystem")==null) it.put("toolSystem",Defaults.system().put("architecture","custom")) }
        listOf("orca_profiles_v2.json","manufacturer_printers_v2.json").forEach { name ->
            JSONObject(readAsset(name)).array("profiles").filter { it.text("kind")=="machine" }.forEach { p -> if(ids.add(p.text("id").lowercase())) printers.add(convertPrinter(p)) }
        }
        library.put("printers",array(printers)).put("schemaVersion",2)
        listOf("filaments","presets","quotes").forEach { if(library.optJSONArray(it)==null) library.put(it,JSONArray()) }
        save(library)
        return library
    }
    @Synchronized fun save(library: JSONObject) {
        file.parentFile?.mkdirs()
        val temp=File(file.parentFile,file.name+".tmp")
        temp.outputStream().use { stream -> stream.write(library.toString().toByteArray(Charsets.UTF_8)); stream.fd.sync() }
        Files.move(temp.toPath(),file.toPath(),StandardCopyOption.ATOMIC_MOVE,StandardCopyOption.REPLACE_EXISTING)
    }
    fun printerCatalog()=importedPrinters(readAsset)
    companion object {
        fun importedPrinters(read:(String)->String):List<JSONObject> = listOf("orca_profiles_v2.json","manufacturer_printers_v2.json").flatMap { name ->
            val root=JSONObject(read(name));require(root.number("schemaVersion",2)==2){"Unsupported printer catalog schema"}
            root.array("profiles").filter{it.text("kind")=="machine"}.map{if(Thread.currentThread().isInterrupted)throw InterruptedException("Printer refresh canceled");convertPrinter(it)}
        }

        fun convertPrinter(p:JSONObject): JSONObject {
            val vendor=if(p.text("vendor")=="BBL") "Bambu Lab" else p.text("vendor")
            val name=p.text("name"); val model=if(name.startsWith("$vendor ",ignoreCase=true)) name.substring(vendor.length+1) else name
            val source=p.getJSONObject("source"); val path=source.text("sourcePath"); val manufacturer=path.startsWith("https://")
            val system=Defaults.system().put("architecture","custom"); Defaults.resize(system,p.number("physicalToolheadCount",1))
            p.optJSONArray("nozzleDiametersMM")?.let { if(it.length()>0) system.array("toolheads").first().put("nozzleDiameterMM",it.get(0)) }
            val values=p.optJSONObject("technicalValues") ?: JSONObject()
            val arch=values.optJSONArray("physical_tool_architecture")?.optString(0)
            if(manufacturer && !arch.isNullOrEmpty()) system.put("architecture",arch).put("sharedNozzle",false).put("filamentInputCount",system.number("availableToolheadCount")).put("maxAutomaticSelectableMaterials",system.number("availableToolheadCount")).put("automaticMaterialSwitching",true)
            val hardware=Defaults.hardware(); val fields=hardware.getJSONObject("fieldSources")
            values.keys().forEach { key -> fields.put(key,doc("value" to values.getJSONArray(key).let { a -> (0 until a.length()).joinToString(", ") { a.getString(it) } },"sourcePath" to (p.optJSONObject("fieldSourcePaths")?.text(key,path) ?: path),"sourcePriority" to if(manufacturer) 1 else 3,"userOverride" to false)) }
            val dual=values.optJSONArray("dual_build_volume_mm")
            if(dual!=null && dual.length()==3) hardware.put("buildVolumeByOperatingMode",array(listOf(
                doc("id" to uuid(),"mode" to "singleExtrusion","shape" to "rectangular","widthMM" to p.optDouble("buildXMM",0.0),"depthMM" to p.optDouble("buildYMM",0.0),"heightMM" to p.optDouble("buildZMM",0.0),"notes" to "Manufacturer single-extrusion volume"),
                doc("id" to uuid(),"mode" to "dualExtrusion","shape" to "rectangular","widthMM" to dual.getString(0).toDouble(),"depthMM" to dual.getString(1).toDouble(),"heightMM" to dual.getString(2).toDouble(),"notes" to "Manufacturer dual-extrusion volume"))))
            return Defaults.printer().put("id",p.text("id")).put("manufacturer",vendor).put("model",model)
                .put("buildVolumeXMM",p.decimal("buildXMM")).put("buildVolumeYMM",p.decimal("buildYMM")).put("buildVolumeZMM",p.decimal("buildZMM"))
                .put("typicalPowerWatts",0).put("machineRate",0).put("maintenanceRate",0).put("externalProfile",source.copy()).put("toolSystem",system).put("hardware",hardware)
                .put("source",doc("name" to source.text("sourceName"),"url" to if(manufacturer) path else source.text("repositoryURL")+"/blob/"+source.text("commitSHA")+"/"+path,
                    "sourceType" to if(manufacturer) "manufacturerSpecifications" else "slicerProfile","retrievedAt" to source.opt("importedAt"),"notes" to p.optJSONArray("reviewReasons")?.let { a -> (0 until a.length()).joinToString("\n") { a.getString(it) } }))
        }
        fun validate(kind:String,value:JSONObject) {
            fun positive(key:String) { require(value.decimal(key).signum()>0) { "$key must be positive" } }
            when(kind) {
                "printers" -> {
                    require(value.text("manufacturer").isNotBlank() && value.text("model").isNotBlank()) { "Enter manufacturer and model." }
                    PricingEngine.nonnegative(value,listOf("buildVolumeXMM","buildVolumeYMM","buildVolumeZMM","typicalPowerWatts","machineRate","maintenanceRate"))
                    value.optJSONObject("toolSystem")?.let(PricingEngine::validateSystem)
                    value.optJSONObject("hardware")?.let { h ->
                        PricingEngine.nonnegative(h,listOf("ratedMaximumPowerWatts","idlePowerWatts","maximumBedTemperatureC","maximumChamberTemperatureC","physicalBuildHeightMM"))
                        h.array("buildVolumeByOperatingMode").forEach { m ->
                            require(listOf("widthMM","depthMM","heightMM").all { m.decimal(it).signum()>0 }) { "Mode dimensions must be positive" }
                            if(m.text("shape")=="circular") require(m.decimal("diameterMM").signum()>0) { "Circular beds need a positive diameter" }
                        }
                    }
                }
                "filaments" -> {
                    require(value.text("manufacturer").isNotBlank() && value.text("productName").isNotBlank()) { "Enter manufacturer and product name" }
                    positive("diameterMM"); positive("netWeightGrams"); PricingEngine.nonnegative(value,listOf("pricePerKG"))
                    value.optJSONObject("stock")?.let { require(it.number("spoolCount")>=0 && it.decimal("remainingGrams").signum()>=0) { "Stock cannot be negative" } }
                }
                "presets" -> {
                    require(value.text("name").isNotBlank()) { "Enter a preset name" }
                    PricingEngine.calculate(Defaults.input().put("pricingMode",value.text("mode")).put("profitRate",value.decimal("rate")).apply { listOf("materialMultiplier","machineRate","laborRate","minimumCharge","rushMultiplier").forEach { put(it,value.decimal(it)) } })
                }
                "quotes" -> PricingEngine.calculate(value.getJSONObject("input"))
                "settings" -> {
                    require(value.text("currency") in listOf("USD","CAD","EUR","GBP","AUD")) { "Select a supported currency" }
                    require(value.decimal("taxRate") in java.math.BigDecimal.ZERO..java.math.BigDecimal.ONE && value.decimal("electricityRate").signum()>=0 && value.number("expirationDays") in 1..365) { "Check tax, electricity rate and expiration days (1–365)." }
                }
            }
        }
    }
}
