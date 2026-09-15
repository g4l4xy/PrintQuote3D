import XCTest
import QuoteData

final class ModelInspectionTests: XCTestCase {
    func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(TestResources.bundle.url(forResource: name, withExtension: nil, subdirectory: "Fixtures/ModelImport"))
    }
    func testASCIIAndBinarySTLAgree() throws {
        for name in ["triangle.stl", "binary-solid.stl"] {
            let report = try ModelImportService.inspect(url: fixture(name))
            XCTAssertEqual(report.fields.first { $0.key == "triangles" }?.value, "1")
            XCTAssertTrue(report.fields.first { $0.key == "bounds" }?.value.contains("20.0") == true)
            XCTAssertFalse(report.fields.contains { $0.category == "Sliced results" })
        }
    }
    func testSlicerMetadataPreservesScopesAndUnknownFields() throws {
        let r = try ModelImportService.inspect(url: fixture("orca-sliced.3mf"))
        func field(_ key: String, _ value: String) -> Bool { r.fields.contains { $0.key.hasSuffix(key) && $0.value == value } }
        XCTAssertTrue(field("printer_model", "Bambu Lab X1 Carbon"))
        XCTAssertTrue(field("filament_type[1]", "PETG"))
        XCTAssertTrue(field("filament_colour[0]", "#FF0000"))
        XCTAssertTrue(field("unknown_future_field.value", "retained"))
        XCTAssertTrue(field("enable_support", "1")); XCTAssertTrue(field("enable_prime_tower", "1"))
        XCTAssertTrue(r.fields.contains { $0.category == "Sliced results" && $0.key.hasSuffix("/@used_g") && $0.value == "12.5" })
        XCTAssertTrue(field("/triangles", "1")); XCTAssertTrue(field("/@transform", "1 0 0 0 1 0 0 0 1 10 20 30"))
        XCTAssertTrue(r.fields.contains { $0.value.contains("Prime tower") })
        XCTAssertFalse(r.fields.contains { $0.key == "support grams" })
    }
    func testRejectsUnsafeMalformedAndDeepFiles() throws {
        for name in ["unsafe.3mf", "entities.3mf", "malformed.3mf", "deep.3mf", "truncated.stl"] {
            XCTAssertThrowsError(try ModelImportService.inspect(url: fixture(name)), name)
        }
    }
    func testCancellation() throws {
        XCTAssertThrowsError(try ModelImportService.inspect(url: fixture("orca-sliced.3mf"), cancelled: { true })) { XCTAssertTrue($0 is CancellationError) }
    }
}
