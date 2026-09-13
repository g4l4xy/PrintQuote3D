import XCTest
import QuoteDomain
import QuoteData
final class ToolSystemTests: XCTestCase {
    func testOneThroughTwelve() throws {
        var s = PrinterToolSystem(); s.architecture = .toolChanger; s.sharedNozzle = false
        for n in 1...12 { s.resize(to:n); try s.validate(); XCTAssertEqual(s.toolheads.count,n); XCTAssertTrue(s.toolheads.last!.needsReview) }
        s.availableToolheadCount = 13; XCTAssertThrowsError(try s.validate())
        s.resize(to:2); s.simultaneousToolUseCount = 3; XCTAssertThrowsError(try s.validate())
    }
    func testSlotsNeverBecomeToolheads() throws {
        var s = PrinterToolSystem(); s.architecture = .singleNozzleSwitcher; s.feederSlotCount = 12; s.filamentInputCount = 12; s.maxAutomaticSelectableMaterials = 12
        try s.validate(); XCTAssertEqual(s.availableToolheadCount,1)
        s.resize(to:12); XCTAssertThrowsError(try s.validate())
    }
    func job(_ architecture: ToolArchitecture) -> ToolJob {
        var j = ToolJob(); j.system.architecture = architecture
        if architecture != .singleNozzleSwitcher { j.system.resize(to:2); j.system.sharedNozzle = false }
        j.system.materialSwitchSeconds = 60; j.system.purgeGramsPerMaterialSwitch = 10
        for n in j.system.toolheads.indices { j.system.toolheads[n].changeOverheadSeconds = 6; j.system.toolheads[n].purgeGramsPerActivation = 1; j.system.toolheads[n].parkedHeaterWatts = 50 }
        var a = ToolMaterialAssignment(); a.grams = 200; a.activeHours = 1; a.activationCount = 10
        j.assignments = [a]; return j
    }
    func testArchitectureChangesWasteTimeAndEnergy() throws {
        let shared = try ToolCostEngine.calculate(job(.singleNozzleSwitcher),printHours:2)
        let changer = try ToolCostEngine.calculate(job(.toolChanger),printHours:2)
        let idex = try ToolCostEngine.calculate(job(.idex),printHours:2)
        let fixed = try ToolCostEngine.calculate(job(.fixedMultiNozzle),printHours:2)
        XCTAssertEqual(shared.totalGrams,300); XCTAssertEqual(changer.totalGrams,210)
        XCTAssertGreaterThan(shared.changeHours,changer.changeHours)
        XCTAssertEqual(changer.additionalEnergyKWh,0)
        XCTAssertEqual(idex.additionalEnergyKWh,Decimal(string:"0.15"))
        XCTAssertEqual(fixed.additionalEnergyKWh,idex.additionalEnergyKWh)
        // Equal physical assumptions can legitimately produce equal costs.
    }
    func testPerToolMaterialPricesAndIntegratedPricing() throws {
        var j = job(.toolChanger)
        var b = ToolMaterialAssignment(); b.toolIndex = 2; b.grams = 100; b.pricePerKG = 40; b.role = .support
        j.assignments.append(b)
        var i = PricingInput(); i.printHours = 2; i.toolJob = j
        let t = try ToolCostEngine.calculate(j,printHours:2)
        XCTAssertEqual(t.materialCost,Decimal(string:"8.2"))
        let r = try PricingEngine.calculate(i)
        XCTAssertEqual(r.totalGrams,310)
        XCTAssertTrue(r.components.contains {$0.name.contains("Tool 2") && $0.amount == 4})
    }
    func testInvalidAssignments() {
        var j = job(.toolChanger); j.assignments[0].toolIndex = 12
        XCTAssertThrowsError(try ToolCostEngine.calculate(j,printHours:2))
        j.assignments[0].toolIndex = 1; j.assignments[0].activeHours = 3
        XCTAssertThrowsError(try ToolCostEngine.calculate(j,printHours:2))
        j.assignments[0].activeHours = 1; j.assignments[0].feederSlot = 4
        XCTAssertThrowsError(try ToolCostEngine.calculate(j,printHours:2))
    }
    func testLegacyLibraryStillDecodes() throws {
        let old = try SeedLoader.load()
        XCTAssertNil(old.printers[0].toolSystem)
        let data = try JSONEncoder().encode(old)
        let copy = try JSONDecoder().decode(LibrarySnapshot.self,from:data)
        XCTAssertEqual(copy.printers.count,3)
        XCTAssertEqual(try PricingEngine.calculate(PricingInput()).total,Decimal(string:"55.52"))
    }
}

final class PortableToolFixtureTests: XCTestCase {
    struct Fixtures: Decodable {
        struct Case: Decodable { var name:String; var input:PricingInput; var expectedTotal:String; var expectedTotalGrams:Decimal }
        var cases:[Case]
    }
    func testPortableToolFixtures() throws {
        let url=try XCTUnwrap(Bundle.module.url(forResource:"tool_calculation_fixtures_v2",withExtension:"json",subdirectory:"Fixtures"))
        let fixtures=try JSONDecoder().decode(Fixtures.self,from:Data(contentsOf:url))
        for fixture in fixtures.cases {
            let result=try PricingEngine.calculate(fixture.input)
            XCTAssertEqual(result.total,Decimal(string:fixture.expectedTotal),fixture.name)
            XCTAssertEqual(result.totalGrams,fixture.expectedTotalGrams,fixture.name)
        }
    }
}
