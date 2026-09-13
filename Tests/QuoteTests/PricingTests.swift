import XCTest
import QuoteDomain
import QuoteData

final class PricingTests: XCTestCase {
    func testBriefFixture() throws {
        let r = try PricingEngine.calculate(PricingInput())
        XCTAssertEqual(r.productionCost, Decimal(string: "33.31"))
        XCTAssertEqual(r.total, Decimal(string: "55.52"))
        XCTAssertEqual(r.totalGrams, 280)
    }
    func testMarginAndMarkup() throws {
        var i = PricingInput()
        i.modelGrams = 1000; i.supportGrams = 0; i.purgeGrams = 0
        i.printHours = 0; i.laborMinutes = 0; i.profitRate = Decimal(string: "0.5")!
        XCTAssertEqual(try PricingEngine.calculate(i).total, 40)
        i.pricingMode = .markup
        XCTAssertEqual(try PricingEngine.calculate(i).total, 30)
    }
    func testInvalidInput() {
        var i = PricingInput(); i.profitRate = 1
        XCTAssertThrowsError(try PricingEngine.calculate(i))
        i.profitRate = 0; i.modelGrams = -1
        XCTAssertThrowsError(try PricingEngine.calculate(i))
        i.modelGrams = 0; i.dryingSharedJobs = 0
        XCTAssertThrowsError(try PricingEngine.calculate(i))
    }
    func testMinimumRushDiscountTaxShipping() throws {
        var i = PricingInput(); i.minimumCharge = 100; i.rushMultiplier = Decimal(string:"1.5")!
        i.discountRate = Decimal(string:"0.1")!; i.taxRate = Decimal(string:"0.08")!; i.shipping = 5
        let r = try PricingEngine.calculate(i)
        XCTAssertTrue(r.minimumApplied); XCTAssertEqual(r.total, Decimal(string:"150.8"))
    }
    func testDryingAndRisk() throws {
        var i = PricingInput(); i.dryerWatts = 100; i.dryingHours = 10; i.dryingSharedJobs = 2
        i.failureProbability = Decimal(string:"0.1")!
        let r = try PricingEngine.calculate(i)
        XCTAssertEqual(r.components.first {$0.name == "Drying"}?.amount, Decimal(string:"0.07"))
        XCTAssertEqual(r.productionCost, Decimal(string:"36.718"))
    }
    @MainActor func testDiskPersistenceAndQuoteSnapshot() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("test.store")
        var library = try SeedLoader.load()
        var quote = Quote(); quote.customer = "Fixture customer"; quote.printer = library.printers[0]
        quote.result = try PricingEngine.calculate(quote.input); library.quotes = [quote]
        do { let repo = try SwiftDataLibraryRepository(url:url); try repo.save(library) }
        let reopened = try SwiftDataLibraryRepository(url:url).load()
        XCTAssertEqual(reopened?.quotes.first?.result?.total, Decimal(string:"55.52"))
        XCTAssertEqual(reopened?.quotes.first?.customer, "Fixture customer")
        XCTAssertEqual(reopened?.printers.count, 3)
    }
}

final class PortableFixtureTests: XCTestCase {
    struct Fixtures: Decodable {
        struct Case: Decodable { let name: String; let input: PricingInput; let expectedProductionCost: String; let expectedTotal: String }
        let schemaVersion: Int
        let cases: [Case]
    }
    func testPortableFixtures() throws {
        let url = try XCTUnwrap(TestResources.bundle.url(forResource:"calculation_fixtures",withExtension:"json",subdirectory:"Fixtures"))
        let fixtures = try JSONDecoder().decode(Fixtures.self,from:Data(contentsOf:url))
        XCTAssertEqual(fixtures.schemaVersion,1)
        for fixture in fixtures.cases {
            let result = try PricingEngine.calculate(fixture.input)
            XCTAssertEqual(result.productionCost,Decimal(string:fixture.expectedProductionCost),fixture.name)
            XCTAssertEqual(result.total,Decimal(string:fixture.expectedTotal),fixture.name)
        }
    }
    func testZeroConsumption() throws {
        var input = PricingInput(); input.modelGrams = 0; input.supportGrams = 0; input.purgeGrams = 0
        input.printHours = 0; input.laborMinutes = 0
        let result = try PricingEngine.calculate(input)
        XCTAssertEqual(result.total,0); XCTAssertEqual(result.materialEfficiency,0)
    }
}
