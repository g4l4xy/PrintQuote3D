import Foundation
public enum BuildPlateShape: String, Codable, CaseIterable, Sendable { case rectangular,circular,customPolygon }
public enum PrinterOperatingMode: String, Codable, CaseIterable, Sendable { case singleExtrusion,dualExtrusion,copy,mirror,toolchanger,fullPlate,belt,custom }
public enum PowerDataQuality: String, Codable, CaseIterable, Sendable { case manufacturerRated,manufacturerTypical,measuredIndependent,userMeasured,estimated,unknown }
public struct OperatingModeBuildVolume: Codable, Identifiable, Equatable, Sendable {
    public var id = UUID()
    public var mode: PrinterOperatingMode = .fullPlate
    public var shape: BuildPlateShape = .rectangular
    public var widthMM: Double = 220
    public var depthMM: Double = 220
    public var heightMM: Double = 250
    public var diameterMM: Double? = nil
    public var notes = "User configured; verify usable area for this mode."
    public init() {}
}
public struct PrinterHardwareDetails: Codable, Equatable, Sendable {
    public var ratedMaximumPowerWatts: Decimal? = nil
    public var idlePowerWatts: Decimal? = nil
    public var typicalPowerQuality: PowerDataQuality = .unknown
    public var maximumBedTemperatureC: Decimal? = nil
    public var maximumChamberTemperatureC: Decimal? = nil
    public var activeChamberHeating = false
    public var physicalBuildHeightMM: Double? = nil
    public var buildVolumeByOperatingMode: [OperatingModeBuildVolume] = []
    public var installedAccessories: [String] = []
    public var fieldSources: [String:TechnicalField] = [:]
    public init() {}
    public func validate() throws {
        try nonnegative([ratedMaximumPowerWatts ?? 0,idlePowerWatts ?? 0,maximumBedTemperatureC ?? 0,maximumChamberTemperatureC ?? 0])
        for mode in buildVolumeByOperatingMode {
            guard [mode.widthMM,mode.depthMM,mode.heightMM].allSatisfy({$0.isFinite && $0>0}) else { throw PricingError.invalid("Mode build dimensions must be positive.") }
            if mode.shape == .circular { guard let d=mode.diameterMM,d.isFinite,d>0 else {throw PricingError.invalid("Circular beds need a positive diameter.")} }
        }
    }
}
public protocol PrinterSourceProvider: Sendable {
    var sourceName: String { get }
    func fetchPrinterRecords() async throws -> [NormalizedTechnicalProfile]
}
public struct LocalJSONPrinterSourceProvider: PrinterSourceProvider {
    public let sourceName = "Local normalized profiles"
    private let data: Data
    public init(data: Data) { self.data=data }
    public func fetchPrinterRecords() async throws -> [NormalizedTechnicalProfile] {
        try JSONDecoder().decode(TechnicalProfileCatalog.self,from:data).profiles.filter {$0.kind == "machine"}
    }
}
public enum PrinterSourceResolver {
    // Keep distinct physical/usable/mode measurements as separate keys. A conflict
    // never changes an explicit local override, and the original record is retained.
    public static func resolve(existing:[String:TechnicalField],incoming:[String:TechnicalField]) -> [String:TechnicalField] {
        FieldPrecedence.merge(existing:existing,incoming:incoming)
    }
}
