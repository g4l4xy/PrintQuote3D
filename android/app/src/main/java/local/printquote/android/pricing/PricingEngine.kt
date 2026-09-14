package local.printquote.android.pricing

import local.printquote.android.model.*
import org.json.JSONObject
import org.json.JSONArray
import java.math.BigDecimal
import java.math.MathContext
import java.math.RoundingMode

private val ZERO = BigDecimal.ZERO
private val ONE = BigDecimal.ONE
private fun div(a: BigDecimal, b: BigDecimal) = a.divide(b, MathContext(38, RoundingMode.HALF_UP))
private fun BigDecimal.over(n: Int) = div(this, n.toBigDecimal())
fun rounded(value: BigDecimal): BigDecimal = value.setScale(2, RoundingMode.HALF_UP)

object PricingEngine {
    fun nonnegative(obj: JSONObject, keys: List<String>) { keys.forEach { require(obj.decimal(it) >= ZERO) { "$it must be nonnegative" } } }
    fun validateSystem(s: JSONObject) {
        val count = s.number("availableToolheadCount",1); val tools = s.array("toolheads")
        require(count in 1..12 && tools.size==count) { "Physical toolheads must number 1–12 and match tool records." }
        val inputs = s.number("filamentInputCount",1)
        require(s.number("simultaneousToolUseCount",1) in 1..count && inputs>=1 && s.number("feederSlotCount")>=0 && s.number("maxSimultaneousMaterials",1) in 1..inputs && s.number("maxAutomaticSelectableMaterials",1) in 1..inputs) { "Tool, input and material counts are inconsistent." }
        require(tools.map { it.text("id") }.toSet().size==count && tools.map { it.number("index") }.sorted()==(1..count).toList()) { "Tool IDs and indices must be unique and sequential." }
        val arch=s.text("architecture"); val shared=s.optBoolean("sharedNozzle",true)
        require(arch in listOf("singleTool","singleNozzleSwitcher","idex","dualExtruder","fixedMultiNozzle","toolChanger","mixingHotend","custom")) { "Unknown tool architecture" }
        if(arch in listOf("singleTool","singleNozzleSwitcher")) require(count==1 && shared) { "Single-tool architectures require one shared nozzle." }
        if(arch=="idex") require(count==2 && !shared) { "IDEX requires two independent tools." }
        if(arch in listOf("toolChanger","fixedMultiNozzle","dualExtruder")) require(!shared) { "This architecture uses independent nozzles." }
        nonnegative(s,listOf("materialSwitchSeconds","purgeGramsPerMaterialSwitch"))
        tools.forEach { t ->
            nonnegative(t,listOf("nozzleDiameterMM","maxNozzleTemperatureC","changeOverheadSeconds","purgeGramsPerActivation","wipeGramsPerActivation","additionalHeaterWatts","parkedHeaterWatts","maintenancePerHour","nozzleReplacementCost","nozzleLifeHours","abrasiveWearMultiplier"))
            require(t.decimal("nozzleDiameterMM")>ZERO && t.decimal("nozzleLifeHours")>ZERO && t.decimal("abrasiveWearMultiplier")>=ONE) { "Nozzle diameter/life must be positive; wear multiplier must be at least 1." }
        }
    }
    fun calculate(input: JSONObject): JSONObject {
        val i=Defaults.input().apply { input.keys().forEach { put(it,input.get(it)) } }
        val n=Defaults.inputNumbers.keys.associateWith { i.decimal(it) }
        fun v(key: String)=n.getValue(key)
        nonnegative(i,Defaults.inputNumbers.keys.toList())
        val mode=i.text("pricingMode")
        require(mode in listOf("margin","markup")) { "Unknown pricing method" }
        require(mode=="markup" || v("profitRate")<ONE) { "Target margin must be below 100%." }
        listOf("failureProbability","discountRate","taxRate").forEach { require(v(it)<=ONE) { "$it must be between 0 and 1." } }
        listOf("dryingSharedJobs","rushMultiplier","materialMultiplier").forEach { require(v(it)>=ONE) { "$it must be at least 1." } }
        val components=mutableListOf<JSONObject>(); val warnings=mutableSetOf<String>()
        fun add(name:String,amount:BigDecimal) { components.add(doc("name" to name,"amount" to amount)) }
        var grams=ZERO; var finalGrams=ZERO; var changeHours=ZERO; var energy=ZERO; var maintenance=ZERO; var wear=ZERO
        val job=i.optJSONObject("toolJob")
        if(job==null) {
            listOf(Triple("Model material","modelGrams","pricePerKG"),Triple("Support material","supportGrams","supportPricePerKG"),Triple("Support interface","interfaceGrams","interfacePricePerKG"),Triple("Purge / flush","purgeGrams","pricePerKG"),Triple("Prime tower","towerGrams","pricePerKG"),Triple("Startup purge","startupGrams","pricePerKG")).forEach { (label,g,p) -> add(label,v(g).over(1000)*v(p)); grams+=v(g) }
            finalGrams=v("modelGrams")
        } else {
            val s=job.getJSONObject("system"); validateSystem(s)
            val tools=s.array("toolheads"); val assignments=job.array("assignments"); require(assignments.isNotEmpty()) { "Add at least one material assignment." }
            val hours=mutableMapOf<Int,BigDecimal>(); val shared=s.optBoolean("sharedNozzle",true)
            assignments.forEach { a ->
                val index=a.number("toolIndex",1); val t=tools.firstOrNull { it.number("index")==index } ?: error("Assignment references an unavailable tool.")
                val changes=a.number("activationCount"); require(changes>=0) { "Change count must be nonnegative." }
                nonnegative(a,listOf("grams","pricePerKG","activeHours"))
                if(!a.isNull("feederSlot")) require(a.number("feederSlot") in 1..s.number("feederSlotCount")) { "Assignment feeder slot is outside configured slots." }
                val active=a.decimal("activeHours"); hours[index]=(hours[index] ?: ZERO)+active
                val purge=changes.toBigDecimal() * if(shared) s.decimal("purgeGramsPerMaterialSwitch") else t.decimal("purgeGramsPerActivation")+t.decimal("wipeGramsPerActivation")
                val seconds=changes.toBigDecimal() * if(shared) s.decimal("materialSwitchSeconds") else t.decimal("changeOverheadSeconds")
                changeHours+=seconds.over(3600)
                val price=a.decimal("pricePerKG"); val weight=a.decimal("grams")
                add("Tool $index · ${a.text("materialName")} · ${a.text("role")} · ${a.text("id").take(4)}",weight.over(1000)*price)
                add("Change waste · ${a.text("id").take(4)}",purge.over(1000)*price)
                grams+=weight+purge; if(a.text("role")=="model") finalGrams+=weight
                energy+=t.decimal("additionalHeaterWatts").over(1000)*active
                maintenance+=t.decimal("maintenancePerHour")*active
                wear+=div(t.decimal("nozzleReplacementCost"),t.decimal("nozzleLifeHours"))*active*(if(a.optBoolean("abrasive")) t.decimal("abrasiveWearMultiplier") else ONE)
                if(s.text("architecture")=="singleTool" && changes>0) warnings.add("Single-tool changes are manual; include operator labor separately.")
                if(a.optBoolean("abrasive") && !t.optBoolean("abrasiveMaterialsAllowed")) warnings.add("Tool $index: abrasive compatibility is unconfirmed or disallowed.")
                if(a.optBoolean("flexible") && !t.optBoolean("flexibleMaterialsAllowed")) warnings.add("Tool $index: flexible compatibility is unconfirmed or disallowed.")
                val families=t.optJSONArray("supportedMaterialFamilies") ?: JSONArray()
                if((0 until families.length()).none { families.getString(it)==a.text("materialFamily") }) warnings.add("Tool $index: review ${a.text("materialFamily")} capability.")
            }
            require(hours.values.all { it<=v("printHours") } && hours.values.fold(ZERO,BigDecimal::add)<=v("printHours")*s.number("simultaneousToolUseCount",1).toBigDecimal()) { "Assigned tool hours exceed print time or simultaneous tool capacity." }
            if(s.text("architecture") in listOf("idex","dualExtruder","fixedMultiNozzle")) tools.forEach { t -> energy+=(v("printHours")-(hours[t.number("index")] ?: ZERO)).max(ZERO)*t.decimal("parkedHeaterWatts").over(1000) }
            if(s.optBoolean("needsReview",true) || tools.any { it.optBoolean("needsReview",true) }) warnings.add("Review tool configuration and change/purge assumptions before quoting.")
        }
        fun sum()=components.fold(ZERO) { total,c -> total+c.decimal("amount") }
        val materialCost=sum(); val charged=v("printHours")+changeHours
        add("Electricity",v("averageWatts").over(1000)*charged*v("electricityRate"))
        add("Drying",div(v("dryerWatts").over(1000)*v("dryingHours")*v("electricityRate"),v("dryingSharedJobs")))
        add("Machine",v("machineRate")*charged); add("Maintenance",v("maintenanceRate")*charged); add("Nozzle / consumable wear",v("wearCost"))
        if(job!=null) { add("Additional tool energy",energy*v("electricityRate")); add("Tool maintenance",maintenance); add("Tool nozzle wear",wear) }
        add("Labor",v("laborMinutes").over(60)*v("laborRate")); add("Failure reserve",sum()*v("failureProbability"))
        add("Packaging",v("packaging")); add("Outside services",v("outsideServices")); add("Other direct costs",v("otherCosts"))
        val production=sum(); val overhead=production*v("overheadRate"); val basis=production+overhead+materialCost*(v("materialMultiplier")-ONE)
        val price=if(mode=="margin") div(basis,ONE-v("profitRate")) else basis*(ONE+v("profitRate"))
        val subtotal=rounded(price.max(v("minimumCharge"))*v("rushMultiplier")); val discount=rounded(subtotal*v("discountRate")); val tax=rounded((subtotal-discount)*v("taxRate")); val shipping=rounded(v("shipping"))
        return doc("components" to array(components),"totalGrams" to grams,"materialEfficiency" to if(grams.signum()==0) ZERO else div(finalGrams,grams),"productionCost" to production,"overhead" to overhead,"minimumApplied" to (price<v("minimumCharge")),"subtotal" to subtotal,"discount" to discount,"tax" to tax,"shipping" to shipping,"total" to subtotal-discount+tax+shipping,"changeHours" to changeHours,"warnings" to JSONArray(warnings.toList()))
    }
}
