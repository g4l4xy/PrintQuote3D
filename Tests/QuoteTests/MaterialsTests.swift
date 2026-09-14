import XCTest
import QuoteDomain
import QuoteData

final class MaterialsTests: XCTestCase {
    func testLegacySeedMaterialsRemainCompatibleWithoutStock() throws {
        let library = try SeedLoader.load()
        let material = try XCTUnwrap(library.filaments.first)

        XCTAssertNil(material.stock)

        let restored = try JSONDecoder().decode(FilamentProduct.self, from: JSONEncoder().encode(material))
        XCTAssertEqual(restored, material)
        XCTAssertNil(restored.stock)
    }

    func testMaterialValidationAllowsKnownInventoryAndZeroUserCost() throws {
        var material = FilamentProduct()
        material.manufacturer = "Example Filaments"
        material.productName = "PLA Matte"
        material.pricePerKG = 0
        material.stock = FilamentStock()
        material.stock?.spoolCount = 2
        material.stock?.remainingGrams = 1350
        material.stock?.location = "Shelf A"
        material.stock?.notes = "Opened spool first"

        XCTAssertNoThrow(try material.validateMaterial())

        let restored = try JSONDecoder().decode(FilamentProduct.self, from: JSONEncoder().encode(material))
        XCTAssertEqual(restored.stock, material.stock)
    }

    func testMaterialValidationRejectsInvalidPhysicalOrInventoryValues() {
        var material = FilamentProduct()
        material.manufacturer = "   "
        XCTAssertThrowsError(try material.validateMaterial())

        material.manufacturer = "Example"
        material.productName = "PLA"
        material.diameterMM = 0
        XCTAssertThrowsError(try material.validateMaterial())

        material.diameterMM = 1.75
        material.netWeightGrams = 0
        XCTAssertThrowsError(try material.validateMaterial())

        material.netWeightGrams = 1000
        material.stock = FilamentStock()
        material.stock?.spoolCount = -1
        XCTAssertThrowsError(try material.validateMaterial())

        material.stock?.spoolCount = 1
        material.stock?.remainingGrams = -1
        XCTAssertThrowsError(try material.validateMaterial())
    }

    @MainActor
    func testSavingQuoteDoesNotConsumeMaterialStock() throws {
        var material = FilamentProduct()
        material.stock = FilamentStock()
        material.stock?.spoolCount = 1
        material.stock?.remainingGrams = 625
        let expectedStock = material.stock

        var quote = Quote()
        quote.filament = material
        quote.result = try PricingEngine.calculate(quote.input)

        var library = LibrarySnapshot()
        library.filaments = [material]
        library.quotes = [quote]
        let repository = try SwiftDataLibraryRepository(inMemory: true)
        try repository.save(library)

        let loaded = try XCTUnwrap(repository.load())
        XCTAssertEqual(loaded.filaments.first?.stock, expectedStock)
        XCTAssertEqual(loaded.quotes.first?.filament?.stock, expectedStock)
    }
}
