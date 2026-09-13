import Foundation
public struct TechnicalField: Codable, Equatable, Sendable {
    public var value: String
    public var sourcePath: String
    public var sourcePriority: Int
    public var userOverride: Bool
    public init(value:String,sourcePath:String,sourcePriority:Int,userOverride:Bool) { self.value=value; self.sourcePath=sourcePath; self.sourcePriority=sourcePriority; self.userOverride=userOverride }
}
public enum FieldPrecedence {
    public static func merge(existing: [String:TechnicalField], incoming: [String:TechnicalField]) -> [String:TechnicalField] {
        existing.merging(incoming) { old,new in
            if old.userOverride { return old }
            return new.userOverride || new.sourcePriority <= old.sourcePriority ? new : old
        }
    }
}
public protocol ManufacturerDataProvider: Sendable {
    var sourceName: String { get }
    func technicalFields(productID: String) async throws -> [String:TechnicalField]
}
public struct CatalogSpoolSize: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var diameterMM: Double?
    public var netWeightGrams: Double?
    public var fields: [String:TechnicalField]
    public var purchaseURLs: [String]
}
public struct CatalogColorVariant: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var colorHex: String?
    public var fields: [String:TechnicalField]
    public var sizes: [CatalogSpoolSize]
}
public struct CatalogFilament: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var brand: String
    public var name: String
    public var materialFamily: String
    public var fields: [String:TechnicalField]
    public var variants: [CatalogColorVariant]
}
public struct OpenFilamentCatalog: Codable, Sendable {
    public var schemaVersion: Int
    public var sourceName: String
    public var sourceURL: String
    public var sourceLicense: String
    public var upstreamVersion: String
    public var generatedAt: String
    public var retrievedAt: String
    public var sha256: String
    public var products: [CatalogFilament]
}
public struct CatalogFilamentSnapshot: Codable, Equatable, Sendable {
    public var productID: UUID
    public var variantID: UUID
    public var sizeID: UUID
    public var fields: [String:TechnicalField]
    public var sourceName: String
    public var sourceURL: String
    public var sourceLicense: String
    public var upstreamVersion: String
    public var retrievedAt: String
    public var sha256: String
    public var userOverride: Bool
    public init(product:CatalogFilament,variant:CatalogColorVariant,size:CatalogSpoolSize,catalog:OpenFilamentCatalog) {
        productID=product.id; variantID=variant.id; sizeID=size.id
        fields=FieldPrecedence.merge(existing:FieldPrecedence.merge(existing:product.fields,incoming:variant.fields),incoming:size.fields)
        sourceName=catalog.sourceName; sourceURL=catalog.sourceURL; sourceLicense=catalog.sourceLicense; upstreamVersion=catalog.upstreamVersion; retrievedAt=catalog.retrievedAt; sha256=catalog.sha256; userOverride=false
    }
}
public struct FilamentSourceEntry: Codable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var priority: Int
    public var urls: [String]
    public var notes: String
    public var status: String
}
public struct FilamentSourceCatalog: Codable, Sendable {
    public var schemaVersion: Int
    public var sources: [FilamentSourceEntry]
}
