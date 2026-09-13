import XCTest
import QuoteDomain
import QuoteData
import OrcaProfiles
final class ImportTests: XCTestCase {
    let sha = String(repeating:"a",count:40)
    func dto(_ name:String,_ values:[String:Any],vendor:String="Test") throws -> OrcaProfileDTO {
        try OrcaProfileDTO(path:"resources/profiles/\(vendor)/machine/\(name).json",data:JSONSerialization.data(withJSONObject:values))
    }
    func testInheritanceAndStableIdentity() throws {
        let parent=try dto("base",["name":"base","type":"machine","printable_height":"250","printable_area":["0x0","220x0","220x200","0x200"],"nozzle_diameter":["0.4"]])
        let child=try dto("printer",["name":"printer","type":"machine","inherits":"base","printable_height":"256","ams_slots":"12"])
        let importer=try OrcaProfileImporter(records:[parent,child])
        let result=try importer.importProfiles(paths:[child.path],commitSHA:sha)
        let p=try XCTUnwrap(result.profiles.first)
        XCTAssertEqual(p.buildZMM,256); XCTAssertEqual(p.buildXMM,220); XCTAssertEqual(p.source.inheritedPaths,[parent.path]); XCTAssertNil(p.physicalToolheadCount)
        let next=try importer.importProfiles(paths:[child.path],commitSHA:String(repeating:"b",count:40))
        XCTAssertEqual(next.profiles.first?.id,p.id)
    }
    func testCyclesAndMissingParentsAreDiagnostics() throws {
        let a=try dto("a",["name":"a","type":"machine","inherits":"b"])
        let b=try dto("b",["name":"b","type":"machine","inherits":"a"])
        let result=try OrcaProfileImporter(records:[a,b]).importProfiles(paths:[a.path],commitSHA:sha)
        XCTAssertEqual(result.profiles.count,0); XCTAssertEqual(result.diagnostics.count,1)
        let missing=try OrcaProfileImporter(records:[a]).importProfiles(paths:[a.path],commitSHA:sha)
        XCTAssertEqual(missing.profiles.count,0)
    }
    func testVendorScopedInheritanceAndNoRetailPricing() throws {
        let a=try dto("base",["name":"base","type":"filament","filament_type":["PLA"],"filament_cost":["2"],"filament_density":["1.24"]])
        let b=try dto("base",["name":"base","type":"filament","filament_type":["ABS"]],vendor:"Other")
        let c=try dto("child",["name":"child","type":"filament","inherits":"base"])
        let p=try XCTUnwrap(OrcaProfileImporter(records:[a,b,c]).importProfiles(paths:[c.path],commitSHA:sha).profiles.first)
        XCTAssertEqual(p.materialFamily,"PLA"); XCTAssertNil(p.technicalValues["filament_cost"])
    }
    func testBundledCatalogsAndCoverage() throws {
        let orca=try SeedLoader.resource("orca_profiles_v2",as:TechnicalProfileCatalog.self)
        XCTAssertEqual(orca.profiles.count,6)
        XCTAssertTrue(orca.profiles.allSatisfy {$0.source.commitSHA.count==40 && !$0.source.sourcePath.isEmpty})
        let filaments=try SeedLoader.resource("open_filaments_v2",as:OpenFilamentCatalog.self)
        XCTAssertGreaterThan(filaments.products.count,2000)
        XCTAssertEqual(Set(filaments.products.map(\.id)).count,filaments.products.count)
        XCTAssertEqual(filaments.sourceLicense,"MIT")
        XCTAssertTrue(filaments.products.contains {$0.brand.localizedCaseInsensitiveContains("Anycubic")})
        let sources=try SeedLoader.resource("filament_sources_v2",as:FilamentSourceCatalog.self)
        XCTAssertTrue(sources.sources.contains {$0.name.contains("Flashforge")})
        XCTAssertTrue(sources.sources.contains {$0.name.contains("Cura")})
    }
    func testOverridesAndManufacturerPrecedence() throws {
        let old=TechnicalField(value:"200",sourcePath:"user",sourcePriority:10,userOverride:true)
        let incoming=TechnicalField(value:"256",sourcePath:"manufacturer",sourcePriority:1,userOverride:false)
        XCTAssertEqual(PrinterSourceResolver.resolve(existing:["height":old],incoming:["height":incoming])["height"]?.value,"200")
        let imported=TechnicalField(value:"250",sourcePath:"orca",sourcePriority:3,userOverride:false)
        XCTAssertEqual(FieldPrecedence.merge(existing:["height":imported],incoming:["height":incoming])["height"]?.value,"256")
    }
    @MainActor func testV2QuoteDiskRoundtrip() throws {
        let repo=try SwiftDataLibraryRepository(inMemory:true)
        var library=LibrarySnapshot(); var printer=PrinterProfile(); var system=PrinterToolSystem(); system.architecture = .toolChanger; system.sharedNozzle=false; system.resize(to:12); printer.toolSystem=system
        var q=Quote(); q.printer=printer; var j=ToolJob(); j.system=system; var a=ToolMaterialAssignment(); a.toolIndex=12; a.grams=100; j.assignments=[a]; q.input.toolJob=j
        q.result=try PricingEngine.calculate(q.input); library.quotes=[q]; library.printers=[printer]
        try repo.save(library)
        let loaded=try XCTUnwrap(repo.load())
        XCTAssertEqual(loaded.quotes[0].input.toolJob?.assignments[0].toolIndex,12)
        XCTAssertEqual(loaded.quotes[0].result,q.result)
    }
}
