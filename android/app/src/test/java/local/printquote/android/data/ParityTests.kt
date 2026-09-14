package local.printquote.android.data

import local.printquote.android.model.*
import local.printquote.android.pricing.*
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.nio.file.Files
import java.math.BigDecimal

class ParityTests {
    private fun asset(name:String)=javaClass.classLoader!!.getResourceAsStream(name)!!.bufferedReader().use {it.readText()}
    private fun same(expected:String,actual:BigDecimal) {assertEquals(expected,0,expected.toBigDecimal().compareTo(actual))}
    @Test fun sharedSwiftAggregateAndToolFixturesMatch() {
        listOf("calculation_fixtures.json","tool_calculation_fixtures_v2.json").forEach {file->JSONObject(asset(file)).array("cases").forEach {case->
            val result=PricingEngine.calculate(case.getJSONObject("input"))
            same(case.text("expectedTotal"),result.decimal("total"))
            if(case.has("expectedProductionCost")) same(case.text("expectedProductionCost"),result.decimal("productionCost"))
            if(case.has("expectedTotalGrams")) same(case.text("expectedTotalGrams"),result.decimal("totalGrams"))
        }}
    }
    @Test fun markupAndMarginDiffer() {
        val i=Defaults.input();same("55.52",PricingEngine.calculate(i).decimal("total"))
        i.put("pricingMode","markup");same("46.63",PricingEngine.calculate(i).decimal("total"))
    }
    @Test fun minimumRushDiscountTaxShippingOrder() {
        val i=Defaults.input().put("minimumCharge",100).put("rushMultiplier",1.5).put("discountRate",0.1).put("taxRate",0.08).put("shipping",5)
        val r=PricingEngine.calculate(i);same("150",r.decimal("subtotal"));same("15",r.decimal("discount"));same("10.80",r.decimal("tax"));same("150.80",r.decimal("total"));assertTrue(r.getBoolean("minimumApplied"))
    }
    @Test fun zeroGramsWithDecimalScaleDoesNotDivideByZero() {val i=Defaults.input();listOf("modelGrams","supportGrams","interfaceGrams","purgeGrams","towerGrams","startupGrams").forEach {i.put(it,BigDecimal("0.00"))};same("0",PricingEngine.calculate(i).decimal("materialEfficiency"))}
    @Test fun invalidInputsRejected() {
        listOf("modelGrams" to "-1","printHours" to "NaN","profitRate" to "1","taxRate" to "1.1","dryingSharedJobs" to "0","rushMultiplier" to "0.5").forEach {(k,v)->assertThrows(IllegalArgumentException::class.java) {try {PricingEngine.calculate(Defaults.input().put(k,v))} catch(e:IllegalStateException){throw IllegalArgumentException(e)}}}
    }
    @Test fun twelveToolsAndCapacityValidation() {
        val s=Defaults.system().put("architecture","toolChanger").put("sharedNozzle",false);Defaults.resize(s,12);PricingEngine.validateSystem(s)
        val a=Defaults.assignment().put("toolIndex",12).put("grams",100).put("activeHours",2)
        val i=Defaults.input().put("printHours",2).put("toolJob",doc("system" to s,"assignments" to array(listOf(a))))
        assertNotNull(PricingEngine.calculate(i));a.put("activeHours",3);assertThrows(IllegalArgumentException::class.java) {PricingEngine.calculate(i)}
    }
    @Test fun invalidArchitectureAndSlotRejected() {
        val s=Defaults.system();Defaults.resize(s,2);assertThrows(IllegalArgumentException::class.java) {PricingEngine.validateSystem(s)}
        val i=Defaults.input().put("toolJob",doc("system" to Defaults.system(),"assignments" to array(listOf(Defaults.assignment().put("feederSlot",1)))))
        assertThrows(IllegalArgumentException::class.java) {PricingEngine.calculate(i)}
    }
    @Test fun catalogProfilesAndUserOverridesPersistWithoutChangingQuotesOrStock() {
        val dir=Files.createTempDirectory("printquote-test").toFile()
        try {
            val repo=WorkspaceRepository(dir.resolve("workspace.json"),::asset);val l=repo.load();assertEquals(1007,l.array("printers").size)
            val p=l.array("printers").first();p.put("machineRate",123)
            val m=l.array("filaments").first();m.put("stock",doc("spoolCount" to 2,"remainingGrams" to 500,"location" to "Shelf"))
            val q=Defaults.quote(l);q.put("result",PricingEngine.calculate(q.getJSONObject("input")));val savedPrice=q.getJSONObject("result").decimal("total")
            l.put("quotes",array(listOf(q)));repo.save(l)
            p.put("machineRate",999);repo.save(l)
            val restored=repo.load();same("999",restored.array("printers").first().decimal("machineRate"));same(savedPrice.toPlainString(),restored.array("quotes").first().getJSONObject("result").decimal("total"))
            same("500",restored.array("filaments").first().getJSONObject("stock").decimal("remainingGrams"));same("123",restored.array("quotes").first().getJSONObject("printer").decimal("machineRate"))
        } finally {dir.deleteRecursively()}
    }
    @Test fun corruptStorageIsNotOverwritten() {
        val dir=Files.createTempDirectory("printquote-corrupt").toFile();try {val f=dir.resolve("workspace.json");f.writeText("corrupt");assertThrows(Exception::class.java) {WorkspaceRepository(f,::asset).load()};assertEquals("corrupt",f.readText())} finally {dir.deleteRecursively()}
    }
    @Test fun invalidMaterialNeverPassesValidation() {val m=Defaults.material().put("pricePerKG",-1);assertThrows(IllegalArgumentException::class.java) {WorkspaceRepository.validate("filaments",m)}}
}
