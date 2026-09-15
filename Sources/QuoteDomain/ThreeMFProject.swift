import Foundation

public enum ImportConfidence: String, Codable, Sendable { case high, medium, low, unknown }
public enum ImportSourceType: String, Codable, Sendable { case standard3MF, slicerMetadata, printerProfile, filamentProfile, derived, userOverride }
public struct ImportedValue<T: Codable & Sendable>: Codable, Sendable {
    public var value: T
    public var sourcePath: String
    public var metadataKey: String
    public var sourceType: ImportSourceType
    public var confidence: ImportConfidence
    public init(_ value: T, path: String, key: String, type: ImportSourceType = .slicerMetadata, confidence: ImportConfidence = .high) {
        self.value = value; sourcePath = path; metadataKey = key; sourceType = type; self.confidence = confidence
    }
}
public enum ImportSeverity: String, Codable, Sendable { case info, warning, recoverableError, fatalError }
public struct ImportDiagnostic: Codable, Sendable, Identifiable {
    public var id = UUID()
    public var severity: ImportSeverity
    public var category: String
    public var code: String
    public var sourcePath: String?
    public var message: String
    public init(_ severity: ImportSeverity, _ category: String, _ code: String, _ message: String, path: String? = nil) { self.severity = severity; self.category = category; self.code = code; self.message = message; sourcePath = path }
}
public struct UnmappedThreeMFMetadata: Codable, Sendable {
    public var sourcePath: String
    public var namespace: String?
    public var scope: String
    public var key: String
    public var value: String?
    public var rawXMLSnippet: String?
    public init(path: String, scope: String = "project", key: String, value: String?, namespace: String? = nil) { sourcePath = path; self.scope = scope; self.key = key; self.value = value; self.namespace = namespace }
}
public struct DetectedSlicer: Codable, Sendable {
    public var name = "Unknown"
    public var version: String?
    public var family = "generic"
    public var confidence: ImportConfidence = .unknown
    public var evidence: [ImportedValue<String>] = []
    public var capabilities: [String: String] = [:]
    public init() {}
}
public struct ImportedPrinterConfiguration: Codable, Sendable {
    public var manufacturer: ImportedValue<String>?
    public var model: ImportedValue<String>?
    public var variant: ImportedValue<String>?
    public var presetName: ImportedValue<String>?
    public var presetID: ImportedValue<String>?
    public var profileVersion: ImportedValue<String>?
    public var operatingMode: ImportedValue<String>?
    public init() {}
}
public struct ImportedToolhead: Codable, Sendable {
    public var index: Int
    public var nozzleDiameterMM: ImportedValue<Double>?
    public var nozzleMaterial: ImportedValue<String>?
    public init(index: Int) { self.index = index }
}
public struct ImportedToolSystem: Codable, Sendable {
    public var physicalToolheads: ImportedValue<Int>?
    public var extruderCount: ImportedValue<Int>?
    public var nozzleCount: ImportedValue<Int>?
    public var filamentInputs: ImportedValue<Int>?
    public var feederSlots: ImportedValue<Int>?
    public var feederType: ImportedValue<String>?
    public var architecture: ImportedValue<String>?
    public var tools: [ImportedToolhead] = []
    public var needsReview = true
    public init() {}
    /// Only explicit/reviewed physical counts can create a pricing tool system.
    public func reviewedSystem() -> PrinterToolSystem? {
        guard let count = physicalToolheads?.value, (1...12).contains(count), tools.count == count,
              Set(tools.map(\.index)) == Set(1...count),
              tools.allSatisfy({ ($0.nozzleDiameterMM?.value ?? 0) > 0 && $0.nozzleDiameterMM?.value.isFinite == true }) else { return nil }
        var system = PrinterToolSystem(); system.architecture = .custom; system.resize(to: count)
        system.sharedNozzle = count == 1
        if let raw = architecture?.value, let architecture = ToolArchitecture(rawValue: raw) { system.architecture = architecture }
        system.filamentInputCount = max(count, filamentInputs?.value ?? count)
        system.feederSlotCount = feederSlots?.value ?? 0
        for tool in tools { system.toolheads[tool.index - 1].nozzleDiameterMM = Decimal(tool.nozzleDiameterMM!.value); system.toolheads[tool.index - 1].nozzleMaterial = NozzleMaterial(rawValue: tool.nozzleMaterial?.value ?? "") ?? .unknown }
        return system
    }
}
public struct ImportedMaterial: Codable, Sendable, Identifiable {
    public var id: String
    public var family: ImportedValue<String>?
    public var preset: ImportedValue<String>?
    public var manufacturer: ImportedValue<String>?
    public var productName: ImportedValue<String>?
    public var sourceColorHex: ImportedValue<String>?
    public var normalizedColorHex: String?
    public var manufacturerColorName: ImportedValue<String>?
    public var densityGramsPerCM3: ImportedValue<Double>?
    public var diameterMM: ImportedValue<Double>?
    public var embeddedSlicerCost: ImportedValue<Decimal>?
    public var temperatures: [ImportedValue<Double>] = []
    public var properties: [ImportedSetting] = []
    public init(id: String) { self.id = id }
}
public struct ImportedAssignment: Codable, Sendable {
    public var scope: String
    public var role: String
    public var materialID: String?
    public var toolIndex: Int?
    public var source: ImportedValue<String>
    public init(scope: String, role: String, materialID: String? = nil, toolIndex: Int? = nil, source: ImportedValue<String>) { self.scope = scope; self.role = role; self.materialID = materialID; self.toolIndex = toolIndex; self.source = source }
}
public struct ImportedSetting: Codable, Sendable {
    public var name: String
    public var scope: String
    public var source: ImportedValue<String>
    public init(_ name: String, scope: String, source: ImportedValue<String>) { self.name = name; self.scope = scope; self.source = source }
}
public struct ImportedProcessSettings: Codable, Sendable {
    public var settings: [ImportedSetting] = []
    public var purgeSettings: [ImportedSetting] = []
    public init() {}
}
public struct ImportedQuantity: Codable, Sendable {
    public var role: String
    public var plateID: String?
    public var objectID: String?
    public var materialID: String?
    public var amount: ImportedValue<Double>
    public var unit: String
    public init(role: String, plateID: String? = nil, objectID: String? = nil, materialID: String? = nil, amount: ImportedValue<Double>, unit: String) { self.role = role; self.plateID = plateID; self.objectID = objectID; self.materialID = materialID; self.amount = amount; self.unit = unit }
}
public struct ImportedPlate: Codable, Sendable, Identifiable {
    public var id: String
    public var name: ImportedValue<String>?
    public var objectIDs: [String] = []
    public var settings: [ImportedSetting] = []
    public var estimates: [ImportedQuantity] = []
    public init(id: String) { self.id = id }
}
public struct ImportedBounds: Codable, Sendable {
    public var minimum: [Double]
    public var maximum: [Double]
    public var dimensions: [Double] { zip(maximum, minimum).map(-) }
    public init(minimum: [Double], maximum: [Double]) { self.minimum = minimum; self.maximum = maximum }
}
public struct ImportedObject: Codable, Sendable, Identifiable {
    public var id: String
    public var resourceID: String
    public var parentID: String?
    public var name: String?
    public var role: String
    public var sourcePath: String
    public var children: [String] = []
    public var triangleCount: Int
    public var instanceCount = 0
    public var unit: String
    public var sourceTransform: [Double]?
    public var boundsMM: ImportedValue<ImportedBounds>?
    public var surfaceAreaMM2: ImportedValue<Double>?
    public var enclosedVolumeMM3: ImportedValue<Double>?
    public var mirrored: Bool?
    public init(id: String, resourceID: String, sourcePath: String, role: String = "model", triangleCount: Int = 0, unit: String = "millimeter") { self.id = id; self.resourceID = resourceID; self.sourcePath = sourcePath; self.role = role; self.triangleCount = triangleCount; self.unit = unit }
}
public struct ImportedPrintProject: Codable, Sendable {
    public var filename: String
    public var sha256: String
    public var fileSize: Int
    public var importedAt: Date
    public var threeMFImporterVersion: String
    public var schemaVersion = 2
    public var slicer = DetectedSlicer()
    public var printer = ImportedPrinterConfiguration()
    public var toolSystem = ImportedToolSystem()
    public var materials: [ImportedMaterial] = []
    public var assignments: [ImportedAssignment] = []
    public var plates: [ImportedPlate] = []
    public var objects: [ImportedObject] = []
    public var processSettings = ImportedProcessSettings()
    public var estimates: [ImportedQuantity] = []
    public var standardMetadata: [UnmappedThreeMFMetadata] = []
    public var slicerMetadata: [UnmappedThreeMFMetadata] = []
    public var unmappedMetadata: [UnmappedThreeMFMetadata] = []
    public init(filename: String, sha256: String, fileSize: Int, version: String) { self.filename = filename; self.sha256 = sha256; self.fileSize = fileSize; importedAt = Date(); threeMFImporterVersion = version }
}
public struct ImportMatch: Codable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var quality: String
    public var reason: String
    public init(id: UUID, name: String, quality: String, reason: String) { self.id = id; self.name = name; self.quality = quality; self.reason = reason }
}
public struct ConfigurationDifference: Codable, Sendable {
    public var field: String
    public var imported: String
    public var current: String
    public init(_ field: String, imported: String, current: String) { self.field = field; self.imported = imported; self.current = current }
}
public struct ThreeMFImportResult: Codable, Sendable {
    public var project: ImportedPrintProject?
    public var diagnostics: [ImportDiagnostic] = []
    public var printerMatches: [ImportMatch] = []
    public var materialMatches: [String: [ImportMatch]] = [:]
    public var differences: [ConfigurationDifference] = []
    public var cacheHit = false
    public var stageStatus: [String: String] = [:]
    public init() {}
}

public struct ThreeMFImportReference: Codable, Sendable {
    public var sha256: String
    public var filename: String
    public var parserVersion: String
    public var importedAt: Date
    public var acceptedFields: [String]
    public init(project: ImportedPrintProject, acceptedFields: [String]) { sha256 = project.sha256; filename = project.filename; parserVersion = project.threeMFImporterVersion; importedAt = project.importedAt; self.acceptedFields = acceptedFields }
}
