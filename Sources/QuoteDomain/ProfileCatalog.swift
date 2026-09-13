import Foundation
public struct NormalizedTechnicalProfile: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: String
    public var vendor: String
    public var name: String
    public var model: String?
    public var materialFamily: String?
    public var buildXMM: Double?
    public var buildYMM: Double?
    public var buildZMM: Double?
    public var nozzleDiametersMM: [Double]
    public var physicalToolheadCount: Int?
    public var technicalValues: [String: [String]]
    public var fieldSourcePaths: [String:String] = [:]
    public var source: ExternalProfileSource
    public var reviewReasons: [String]
    public init(id:UUID,kind:String,vendor:String,name:String,model:String?,materialFamily:String?,buildXMM:Double?,buildYMM:Double?,buildZMM:Double?,nozzleDiametersMM:[Double],physicalToolheadCount:Int?,technicalValues:[String:[String]],source:ExternalProfileSource,reviewReasons:[String]) {
        self.id=id; self.kind=kind; self.vendor=vendor; self.name=name; self.model=model; self.materialFamily=materialFamily; self.buildXMM=buildXMM; self.buildYMM=buildYMM; self.buildZMM=buildZMM; self.nozzleDiametersMM=nozzleDiametersMM; self.physicalToolheadCount=physicalToolheadCount; self.technicalValues=technicalValues; self.source=source; self.reviewReasons=reviewReasons
    }
}
public struct TechnicalProfileCatalog: Codable, Sendable {
    public var schemaVersion: Int
    public var profiles: [NormalizedTechnicalProfile]
    public var diagnostics: [String]
    public init(profiles:[NormalizedTechnicalProfile],diagnostics:[String]) { schemaVersion=2; self.profiles=profiles; self.diagnostics=diagnostics }
}
