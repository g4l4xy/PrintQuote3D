import Foundation
import QuoteData
import QuoteDomain

// Read-only developer probe. Source contents are never logged unless --normalized is explicit.
@main struct ThreeMFProbe {
    static func main() async throws {
        let args=Array(CommandLine.arguments.dropFirst())
        guard let path=args.first else { print("Usage: ThreeMFProbe FILE [--normalized] [--compare]"); return }
        let start=ContinuousClock.now
        let result=try await ThreeMFImportService.importFile(url:URL(fileURLWithPath:path),cache:nil)
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];encoder.dateEncodingStrategy = .iso8601
        if args.contains("--normalized") { print(String(decoding:try encoder.encode(result),as:UTF8.self));return }
        struct Summary:Encodable {
            var parser:String;var elapsed:String;var bytes:Int?;var slicer:String?;var version:String?
            var objects:Int;var triangles:Int;var materials:Int;var plates:Int;var toolheads:Int?;var filamentInputs:Int?
            var diagnosticCodes:[String];var legacy:String?
        }
        var legacy:String?
        if args.contains("--compare") {
            do {let report=try ModelImportService.inspect(url:URL(fileURLWithPath:path));legacy="success; \(report.fields.count) evidence fields"}catch{legacy="failed (legacy validation policy)"}
        }
        let p=result.project
        let summary=Summary(parser:ThreeMFImportService.version,elapsed:String(describing:start.duration(to:.now)),bytes:p?.fileSize,slicer:p?.slicer.name,version:p?.slicer.version,objects:p?.objects.count ?? 0,triangles:p?.objects.filter{!$0.id.hasPrefix("instance:")}.reduce(0){$0+$1.triangleCount} ?? 0,materials:p?.materials.count ?? 0,plates:p?.plates.count ?? 0,toolheads:p?.toolSystem.physicalToolheads?.value,filamentInputs:p?.toolSystem.filamentInputs?.value,diagnosticCodes:result.diagnostics.map{$0.category+":"+$0.code},legacy:legacy)
        print(String(decoding:try encoder.encode(summary),as:UTF8.self))
    }
}
