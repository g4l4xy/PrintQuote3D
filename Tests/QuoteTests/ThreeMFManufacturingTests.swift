import XCTest
import QuoteDomain
@testable import QuoteData

final class ThreeMFManufacturingTests: XCTestCase {
    func url(_ name:String)throws->URL {try XCTUnwrap(TestResources.bundle.url(forResource:name,withExtension:"3mf",subdirectory:"Fixtures/ThreeMFV2"))}
    func parse(_ name:String,limits:ThreeMFImportLimits = .init())async throws->ThreeMFImportResult {try await ThreeMFImportService.importFile(url:url(name),limits:limits,cache:nil)}
    func testSlicerFamilyGoldenFixtures()async throws {
        for (file,name) in [("bambu-ams","Bambu Studio"),("orca-multiplate","OrcaSlicer"),("prusa-xl5","PrusaSlicer"),("anycubic","Anycubic Slicer Next"),("creality","Creality Print"),("cura","Cura"),("flashprint","FlashPrint")] {
            let r=try await parse(file);let p=try XCTUnwrap(r.project,"\(r.diagnostics)");XCTAssertEqual(p.slicer.name,name);XCTAssertNotNil(p.slicer.version);XCTAssertTrue(p.objects.contains{$0.boundsMM != nil})
        }
    }
    func testAMSSlotsNeverBecomePhysicalToolheads()async throws {
        let r=try await parse("bambu-ams");let p=try XCTUnwrap(r.project)
        XCTAssertEqual(p.toolSystem.physicalToolheads?.value,1);XCTAssertEqual(p.toolSystem.filamentInputs?.value,4);XCTAssertEqual(p.toolSystem.feederSlots?.value,4);XCTAssertEqual(p.materials.count,4);XCTAssertEqual(p.plates.count,2)
        XCTAssertEqual(p.toolSystem.physicalToolheads?.sourceType,.printerProfile)
        XCTAssertTrue(p.unmappedMetadata.contains{$0.key=="unknown_new_vendor_key"})
        XCTAssertEqual(p.estimates.filter{$0.role=="printTime"}.map(\.amount.value).sorted(),[600,31320])
        for role in ["model","support","purge","primeTower"] {XCTAssertTrue(p.estimates.contains{$0.role==role})}
    }
    func testXLFiveToolsAndOneThroughTwelve()async throws {
        let xl=try await parse("prusa-xl5");XCTAssertEqual(xl.project?.toolSystem.physicalToolheads?.value,5);XCTAssertEqual(xl.project?.toolSystem.architecture?.value,"toolChanger")
        for count in [1,2,12] {let r=try await parse("tools-\(count)");let tools=try XCTUnwrap(r.project?.toolSystem);XCTAssertEqual(tools.physicalToolheads?.value,count);XCTAssertEqual(tools.tools.count,count);XCTAssertNotNil(tools.reviewedSystem())}
    }
    func testTransformedInchGeometryAndMirrors()async throws {
        let r=try await parse("generic-inch");let instance=try XCTUnwrap(r.project?.objects.first{$0.boundsMM != nil});let box=try XCTUnwrap(instance.boundsMM?.value)
        for (a,b) in zip(box.minimum,[254.0,508.0,762.0]) {XCTAssertEqual(a,b,accuracy:1e-6)}
        for dimension in box.dimensions {XCTAssertEqual(dimension,50.8,accuracy:1e-6)}
        XCTAssertEqual(try XCTUnwrap(instance.enclosedVolumeMM3?.value),pow(25.4,3)*8/6,accuracy:1e-5)
        let mirrored=try await parse("mirrored");let obj=try XCTUnwrap(mirrored.project?.objects.first{$0.boundsMM != nil});XCTAssertEqual(obj.mirrored,true);XCTAssertEqual(obj.enclosedVolumeMM3?.value ?? 0,1.0/6,accuracy:1e-8)
    }
    func testProductionComponentsAndRootRelationships()async throws {
        let r=try await parse("external-component");let p=try XCTUnwrap(r.project);let obj=try XCTUnwrap(p.objects.first{$0.boundsMM != nil && $0.parentID != nil});XCTAssertEqual(obj.boundsMM?.value.minimum,[10,20,0]);XCTAssertNotNil(obj.parentID);XCTAssertTrue(p.objects.contains{!$0.children.isEmpty})
    }
    func testPartialRecoveryAndUnknownFallback()async throws {
        for file in ["partial","bad-thumbnail","invalid-object","invalid-transform","cycle","unknownslicer","external-relationship"] {
            let r=try await parse(file);XCTAssertNotNil(r.project,file);XCTAssertTrue(r.project?.objects.contains{$0.boundsMM != nil} == true,file)
            if file != "unknownslicer" {XCTAssertFalse(r.diagnostics.isEmpty,file)}
        }
    }
    func testSecurityLimitsAndCancellation()async throws {
        let xxe=try await parse("xxe");XCTAssertNil(xxe.project);XCTAssertTrue(xxe.diagnostics.contains{$0.severity == .fatalError})
        var limits=ThreeMFImportLimits();limits.compressionRatio=10
        let ratio=try await parse("ratio",limits:limits);XCTAssertNil(ratio.project)
        limits = .init();limits.triangleCount=1;let triangles=try await parse("generic-inch",limits:limits);XCTAssertNil(triangles.project)
        do {_ = try await ThreeMFImportService.importFile(url:url("generic-inch"),cache:nil,cancelled:{true});XCTFail("Expected cancellation")}catch is CancellationError{}catch{XCTFail("Wrong error \(error)")}
    }
    func testCacheFingerprintReanalysisAndCorruptionFallback()async throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:folder)}
        let cache=ThreeMFImportCache(directory:folder);let source=try url("generic-inch")
        let first=try await ThreeMFImportService.importFile(url:source,cache:cache)
        let second=try await ThreeMFImportService.importFile(url:source,cache:cache)
        XCTAssertFalse(first.cacheHit);XCTAssertTrue(second.cacheHit);XCTAssertEqual(first.project?.sha256.count,64)
        let again=try await ThreeMFImportService.importFile(url:source,forceReanalysis:true,cache:cache);XCTAssertFalse(again.cacheHit)
        for file in try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil){try Data("broken cache".utf8).write(to:file)}
        let repaired=try await ThreeMFImportService.importFile(url:source,cache:cache);XCTAssertFalse(repaired.cacheHit);XCTAssertNotNil(repaired.project)
    }
    func testMatchingAndSelectedUpdatesNeverMutateOriginalQuote()async throws {
        let r=try await parse("bambu-ams");let p=try XCTUnwrap(r.project)
        var printer=PrinterProfile();printer.manufacturer="BBL";printer.model="P1S";var tools=PrinterToolSystem();tools.toolheads[0].nozzleDiameterMM=0.6;tools.toolheads[0].nozzleMaterial = .hardenedSteel;printer.toolSystem=tools
        let reviewed=ThreeMFImportService.review(r,printers:[printer],materials:[],selectedPrinter:printer);XCTAssertEqual(reviewed.printerMatches.first?.quality,"exact");XCTAssertFalse(reviewed.differences.isEmpty)
        var q=Quote();q.printer=printer;q.input.modelGrams=99;q.input.laborMinutes=77;q.input.pricePerKG=48
        let quantity=try XCTUnwrap(p.estimates.first{$0.role=="model"})
        let preview=try ThreeMFQuotePreview.apply(p,to:q,selected:[ThreeMFQuotePreview.key(quantity)])
        XCTAssertEqual(preview.input.modelGrams,183);XCTAssertEqual(q.input.modelGrams,99);XCTAssertEqual(preview.input.laborMinutes,77);XCTAssertEqual(preview.input.pricePerKG,48);XCTAssertEqual(preview.printer?.toolSystem?.toolheads[0].nozzleDiameterMM,0.6)
        XCTAssertThrowsError(try ThreeMFQuotePreview.apply(p,to:q,selected:Set(p.estimates.filter{$0.role=="printTime"}.map(ThreeMFQuotePreview.key))))
    }
    func testSupportSummaryOmitsPrivateMetadataValues()async throws {
        let r=try await parse("bambu-ams");let text=String(data:try ThreeMFImportService.supportSummary(r),encoding:.utf8)!
        XCTAssertFalse(text.contains("keep me"));XCTAssertFalse(text.contains("<vertex"));XCTAssertTrue(text.contains("unknown_new_vendor_key"))
    }
    func testSeededMalformedTransformPropertyCases()async throws {
        let values=["", "nan", "1 2 3", "1 0 0 0 0 0 0 0 1 0 0 0", "1e999 0 0 0 1 0 0 0 1 0 0 0"]
        for value in values {XCTAssertThrowsError(try MFTransform(value,unitScale:1))}
        let large=try MFTransform("1 0 0 0 1 0 0 0 1 1e20 0 0",unitScale:1).then(.identity)
        XCTAssertEqual(Array(large.values.prefix(9)),Array(MFTransform.identity.values.prefix(9)))
        XCTAssertNoThrow(try MFTransform("1e-8 0 0 0 1e-8 0 0 0 1e-8 0 0 0",unitScale:1))
        for n in 1...50 {let t=try MFTransform("1 0 0 0 1 0 0 0 1 \(n) 2 3",unitScale:1);let p=t.then(.identity).apply(.zero);XCTAssertEqual(p.x,Double(n))}
    }
    func testGCodeHeaderFormsOneMaterialProfileWithDistinctSources() async throws {
        let r=try await parse("gcode-profile");let p=try XCTUnwrap(r.project)
        XCTAssertEqual(p.materials.count,1);XCTAssertEqual(p.materials.first?.family?.value,"PETG")
        XCTAssertEqual(p.materials.first?.densityGramsPerCM3?.value,1.27)
        XCTAssertTrue(p.estimates.contains{$0.role=="printTime" && $0.amount.value==3720})
    }
    func testSlicedMetadataOnlyJobRemainsUseful() async throws {
        let r=try await parse("metadata-only-job");XCTAssertNotNil(r.project);XCTAssertEqual(r.project?.objects.count,0)
        XCTAssertTrue(r.project?.estimates.contains{$0.role=="printTime"} == true)
        XCTAssertTrue(r.diagnostics.contains{$0.code=="metadataOnlyJob"})
        XCTAssertEqual(r.stageStatus["geometry"],"partial")
    }
    func testPlateAliasesAndUnknownNamespaces() async throws {
        let alias=try await parse("plate-alias");XCTAssertEqual(alias.project?.plates.count,1);XCTAssertEqual(alias.project?.plates.first?.objectIDs,["1"])
        let unknown=try await parse("unknown-namespace");XCTAssertFalse(unknown.project?.objects.contains{$0.resourceID.hasSuffix("#88")} == true)
        XCTAssertTrue(unknown.project?.unmappedMetadata.contains{$0.value=="88"} == true)
    }
    func testConflictsCannotSilentlySelectPrinterOrToolCount() async throws {
        let result=try await parse("conflicting-printer")
        let p=try XCTUnwrap(result.project)
        XCTAssertNil(p.printer.model);XCTAssertNil(p.toolSystem.physicalToolheads)
        XCTAssertTrue(result.diagnostics.contains{$0.code=="conflictingMetadata"})
        XCTAssertTrue(result.diagnostics.contains{$0.code=="versionFallback"})
        XCTAssertEqual(p.unmappedMetadata.filter{$0.key=="printer_model"}.count,2)
    }
    func testDuplicateMaterialAndUntrustedToolIndexesCannotCrashReview() async throws {
        let result=try await parse("duplicate-material")
        XCTAssertNotNil(ThreeMFImportService.review(result,printers:[],materials:[]).project)
        var tools=ImportedToolSystem();tools.physicalToolheads = .init(1,path:"test",key:"count")
        var tool=ImportedToolhead(index:0);tool.nozzleDiameterMM = .init(0.4,path:"test",key:"diameter");tools.tools=[tool]
        XCTAssertNil(tools.reviewedSystem())
        tools.tools[0].index=100;XCTAssertNil(tools.reviewedSystem())
    }
    func testMalformedArchivePropertiesAndOverflowRecovery() async throws {
        for file in ["path-traversal","xml-depth"]+(1...5).map({"truncated-\($0)"}) {
            let result=try await parse(file);XCTAssertNil(result.project,file)
        }
        let result=try await parse("overflow-instance")
        XCTAssertNotNil(result.project);XCTAssertTrue(result.project?.objects.contains{$0.boundsMM != nil} == true)
        var limits=ThreeMFImportLimits();limits.retainedMetadataBytes=1024
        let giant=try await parse("giant-metadata",limits:limits);XCTAssertNil(giant.project)
        let shuffled=try await parse("shuffled-metadata");XCTAssertEqual(shuffled.project?.printer.model?.value,"P1S")
        XCTAssertEqual(try SafeArchiveReader.resolve("%2FParts/part.model",relativeTo:"3D/model.model"),"Parts/part.model")
        XCTAssertThrowsError(try SafeArchiveReader.resolve("%2E%2E/escape",relativeTo:"root.model"))
    }
    func testSharedGoldenContract() async throws {
        let source=try XCTUnwrap(TestResources.bundle.url(forResource:"golden",withExtension:"json",subdirectory:"Fixtures/ThreeMFV2"))
        let goldens=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:source)) as? [String:[String:Any]])
        for (name,golden) in goldens {
            let result=try await parse(name);let p=try XCTUnwrap(result.project)
            if let slicer=golden["slicer"] as? String {XCTAssertEqual(p.slicer.name,slicer)}
            if let count=golden["physicalToolheads"] as? Int {XCTAssertEqual(p.toolSystem.physicalToolheads?.value,count)}
            if let count=golden["materials"] as? Int {XCTAssertEqual(p.materials.count,count)}
            if let count=golden["filamentInputs"] as? Int {XCTAssertEqual(p.toolSystem.filamentInputs?.value,count)}
        }
    }
    func testQuoteReferenceRoundTripAndLegacyComparison() async throws {
        let result=try await parse("bambu-ams");let project=try XCTUnwrap(result.project)
        let q=try ThreeMFQuotePreview.apply(project,to:Quote(),selected:[])
        let data=try JSONEncoder().encode(q)
        XCTAssertEqual(try JSONDecoder().decode(Quote.self,from:data).manufacturingImport?.sha256,project.sha256)
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any]);object.removeValue(forKey:"manufacturingImport")
        XCTAssertNil(try JSONDecoder().decode(Quote.self,from:JSONSerialization.data(withJSONObject:object)).manufacturingImport)
        let legacy=try ModelImportService.inspect(url:url("bambu-ams"));XCTAssertFalse(legacy.fields.isEmpty)
        XCTAssertThrowsError(try ModelImportService.inspect(url:url("bad-thumbnail")))
        let recovered=try await parse("bad-thumbnail");XCTAssertNotNil(recovered.project)
    }

    func testCacheInvalidatesForChangedContentPolicyAndVersion() async throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:folder)}
        let file=folder.appendingPathComponent("source.3mf");let original=try Data(contentsOf:url("generic-inch"));try original.write(to:file)
        let cacheFolder=folder.appendingPathComponent("cache");let cache=ThreeMFImportCache(directory:cacheFolder)
        let first=try await ThreeMFImportService.importFile(url:file,cache:cache)
        XCTAssertEqual(try Data(contentsOf:file),original)
        var policy=ThreeMFImportLimits();policy.seconds=30
        let changedPolicy=try await ThreeMFImportService.importFile(url:file,limits:policy,cache:cache);XCTAssertFalse(changedPolicy.cacheHit)
        try Data(contentsOf:url("mirrored")).write(to:file)
        let changed=try await ThreeMFImportService.importFile(url:file,cache:cache);XCTAssertFalse(changed.cacheHit);XCTAssertNotEqual(changed.project?.sha256,first.project?.sha256)
        for cacheFile in try FileManager.default.contentsOfDirectory(at:cacheFolder,includingPropertiesForKeys:nil) {
            var text=try String(contentsOf:cacheFile,encoding:.utf8);text=text.replacingOccurrences(of:"2.0.0",with:"0.0.0");try Data(text.utf8).write(to:cacheFile)
        }
        let changedVersion=try await ThreeMFImportService.importFile(url:file,cache:cache);XCTAssertFalse(changedVersion.cacheHit)
    }
    func testCancellationDuringGeometryStage() async throws {
        let token=Progress(totalUnitCount:1)
        do {
            _ = try await ThreeMFImportService.importFile(url:url("generic-inch"),cache:nil,cancelled:{token.isCancelled},progress:{if $0.stage=="Analyzing geometry"{token.cancel()}})
            XCTFail("Expected in-flight cancellation")
        }catch is CancellationError{}catch{XCTFail("Unexpected error: \(error)")}
    }

}
