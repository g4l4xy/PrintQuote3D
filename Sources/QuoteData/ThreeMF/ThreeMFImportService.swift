import Foundation
import CryptoKit
import QuoteDomain

public actor ThreeMFImportCache {
    public static let shared = ThreeMFImportCache()
    private let directory: URL
    public init(directory:URL? = nil) { self.directory=directory ?? FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("PrintQuote3D/ThreeMF-v2") }
    func get(_ key:String)->ThreeMFImportResult? {
        let url=directory.appendingPathComponent(key+".json")
        guard FileManager.default.fileExists(atPath:url.path) else{return nil}
        guard let size=try? url.resourceValues(forKeys:[.fileSizeKey]).fileSize,size<=8*1024*1024,let data=try? Data(contentsOf:url),let result=try? JSONDecoder().decode(ThreeMFImportResult.self,from:data) else{return nil}
        guard let project=result.project,
              project.objects.allSatisfy({ o in
                  guard let bounds=o.boundsMM?.value else {return true}
                  return bounds.minimum.count==3 && bounds.maximum.count==3 && (bounds.minimum+bounds.maximum).allSatisfy(\.isFinite)
              }), project.estimates.allSatisfy({$0.amount.value.isFinite && $0.amount.value>=0}) else {return nil}
        return result
    }
    func put(_ key:String,result:ThreeMFImportResult) {
        guard let data=try? JSONEncoder().encode(result),data.count<=8*1024*1024 else{return}
        do {
            try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
            let url=directory.appendingPathComponent(key+".json");try data.write(to:url,options:.atomic);try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:url.path)
            let files=try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:[.contentModificationDateKey]).filter{$0.pathExtension=="json"}.sorted{(try? $0.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast > (try? $1.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast}
            for old in files.dropFirst(16){try? FileManager.default.removeItem(at:old)}
        } catch { /* Cache is optional; never turn a successful import into a failure. */ }
    }
}
public enum ThreeMFImportService {
    public static let version="2.0.0"
    public static func importFile(url:URL, limits:ThreeMFImportLimits = .init(), forceReanalysis:Bool=false, cache:ThreeMFImportCache? = .shared, cancelled:@escaping @Sendable ()->Bool = {false}, progress:@escaping @Sendable (ThreeMFImportProgress)->Void = {_ in}) async throws -> ThreeMFImportResult {
        try limits.validate(); progress(.init("Opening file",0))
        let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
        let snapshotTask=Task.detached(priority:.userInitiated){try ThreeMFSourceSnapshot.create(url,limits:limits,cancelled:cancelled)}
        let snapshot=try await withTaskCancellationHandler(operation:{try await snapshotTask.value},onCancel:{snapshotTask.cancel()})
        defer{try? FileManager.default.removeItem(at:snapshot.url)}
        if cancelled() || Task.isCancelled {throw CancellationError()}
        let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys
        let policy=try encoder.encode(limits)
        let policyHash=SHA256.hash(data:policy).map{String(format:"%02x",$0)}.joined()
        let key=snapshot.sha256+"-"+version+"-2-"+policyHash
        if !forceReanalysis, var cached=await cache?.get(key),cached.project?.sha256==snapshot.sha256,cached.project?.threeMFImporterVersion==version,cached.project?.schemaVersion==2 {
            cached.cacheHit=true;cached.project?.filename=snapshot.originalName;cached.project?.importedAt=Date();if cancelled(){throw CancellationError()};progress(.init("Finalizing cached result",1));return cached
        }
        let parseTask=Task.detached(priority:.userInitiated){try parse(snapshot,limits:limits,cancelled:cancelled,progress:progress)}
        let result=try await withTaskCancellationHandler(operation:{try await parseTask.value},onCancel:{parseTask.cancel()})
        if cancelled() || Task.isCancelled {throw CancellationError()}
        if result.project != nil {await cache?.put(key,result:result)}
        return result
    }
    private static func parse(_ snapshot:ThreeMFSourceSnapshot,limits:ThreeMFImportLimits,cancelled:@escaping @Sendable ()->Bool,progress:@escaping @Sendable (ThreeMFImportProgress)->Void)throws->ThreeMFImportResult {
        let context=ThreeMFContext(limits,cancelled:cancelled,progress:progress);var result=ThreeMFImportResult()
        do {
            progress(.init("Inspecting archive",0.05));let reader=try SafeArchiveReader(url:snapshot.url,context:context)
            progress(.init("Reading relationships",0.1));let manifest=try ThreeMFContainerReader.inspect(reader,context:context);result.stageStatus["container"]="success"
            let standard=try StandardThreeMFParser.parse(reader,manifest:manifest,context:context)
            var project=ImportedPrintProject(filename:snapshot.originalName,sha256:snapshot.sha256,fileSize:snapshot.size,version:version)
            project.standardMetadata=standard.metadata;
            for relation in manifest.relationships {project.standardMetadata.append(.init(path:relation.source,scope:"relationship",key:relation.type,value:relation.target))}
            project.materials=standard.materials;project.assignments=standard.assignments
            let records=try ThreeMFMetadataRouter.read(reader,manifest:manifest,standard:standard,context:context)
            project.slicerMetadata=records.filter{!$0.raw.sourcePath.hasSuffix(".model")}.map(\.raw)
            progress(.init("Detecting slicer",0.68));project.slicer=ThreeMFSlicerDetector.detect(records,paths:reader.paths)
            let adapter=FamilyThreeMFAdapter.adapter(project.slicer.family);project.slicer.capabilities=adapter.capabilities
            progress(.init("Parsing printer, materials and process settings",0.72));try adapter.normalize(records,project:&project,context:context)
            if standard.resources.isEmpty {
                guard !project.estimates.isEmpty || !project.materials.isEmpty || project.printer.model != nil else {throw ThreeMFFailure.damaged("No usable geometry or manufacturing metadata was found.")}
                context.diagnostic(.recoverableError,"3MF.Geometry","metadataOnlyJob","Manufacturing metadata was recovered without mesh resources, as in sliced G-code packages. Geometry and build-volume checks are unavailable.")
            }
            progress(.init("Analyzing geometry",0.8));project.objects=try StandardThreeMFParser.geometry(standard,roots:manifest.roots,context:context)
            if project.plates.isEmpty {var plate=ImportedPlate(id:"default-build");plate.objectIDs=project.objects.filter{$0.parentID==nil && $0.id.hasPrefix("instance:")}.map(\.id);project.plates=[plate]}
            result.project=project
            result.stageStatus["geometry"]=context.diagnostics.contains{$0.category=="3MF.Geometry" && $0.severity == .recoverableError} ? "partial":"success"
            result.stageStatus["metadata"]=context.diagnostics.contains{$0.category=="3MF.Metadata" && $0.severity == .recoverableError} ? "partial":"success"
            result.stageStatus["thumbnail"]=context.diagnostics.contains{$0.code=="optionalPart" && $0.category=="3MF.Container"} ? "partial":"validated where present"
            result.stageStatus["slicer"]=project.slicer.confidence == .high ? "identified":"needsReview"
            try context.check();progress(.init("Finalizing",1))
        } catch is CancellationError {throw CancellationError()}
          catch {context.diagnostic(.fatalError,"3MF.Container","importFailed",error.localizedDescription);result.project=nil;result.stageStatus["import"]="fatal"}
        result.diagnostics=context.diagnostics;return result
    }
    /// Matching is deliberately outside the cache: inventories and saved overrides change independently of the file.
    public static func review(_ result:ThreeMFImportResult,printers:[PrinterProfile],materials:[FilamentProduct],catalog:[CatalogFilament]=[],selectedPrinter:PrinterProfile?=nil)->ThreeMFImportResult {
        var output=result;guard let project=result.project else{return output}
        output.printerMatches=ThreeMFPrinterMatcher.match(project.printer,printers:printers)
        output.materialMatches=Dictionary(grouping:project.materials,by: \.id).mapValues { records in
            records.flatMap { ThreeMFFilamentMatcher.match($0,materials:materials) + ThreeMFFilamentMatcher.matchCatalog($0,catalog:catalog) }
        }
        if output.printerMatches.isEmpty {output.diagnostics.append(.init(.warning,"3MF.Printer","noMatch","Imported printer did not match the available printer database. Choose a configuration explicitly."))}
        if let selectedPrinter {output.differences=ThreeMFCompatibility.compare(project,printer:selectedPrinter);output.diagnostics += ThreeMFCompatibility.check(project,printer:selectedPrinter)}
        output.stageStatus["matching"]="reviewRequired";return output
    }
    /// A support bundle intentionally excludes geometry, metadata values and the source archive.
    public static func supportSummary(_ result:ThreeMFImportResult)throws->Data {
        struct Summary:Encodable {var filename:String?;var sha256:String?;var importerVersion:String;var slicer:String?;var diagnosticCodes:[String];var metadataKeys:[String]}
        let summary=Summary(filename:result.project?.filename,sha256:result.project?.sha256,importerVersion:version,slicer:result.project?.slicer.name,diagnosticCodes:result.diagnostics.map{$0.category+":"+$0.code},metadataKeys:Array(Set(result.project?.unmappedMetadata.map(\.key) ?? [])).sorted())
        return try JSONEncoder().encode(summary)
    }
}
