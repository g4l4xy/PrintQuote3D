import Foundation

public enum PricingMode: String, Codable, CaseIterable, Sendable { case margin, markup }
public struct SourceReference: Codable, Sendable, Equatable {
    public var name: String = "User entered"
    public var url: String? = nil
    public var sourceType: String = "userEntered"
    public var retrievedAt: Date? = nil
    public var notes: String = "Illustrative local values; verify for your equipment."
    public init() {}
}
public struct PrinterProfile: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID = UUID()
    public var manufacturer = "Custom"
    public var model = "New printer"
    public var buildVolumeXMM: Double = 220
    public var buildVolumeYMM: Double = 220
    public var buildVolumeZMM: Double = 250
    public var typicalPowerWatts: Decimal = 150
    public var machineRate: Decimal = 1
    public var maintenanceRate: Decimal = Decimal(string: "0.25")!
    public var hardware: PrinterHardwareDetails? = nil
    public var toolSystem: PrinterToolSystem? = nil
    public var externalProfile: ExternalProfileSource? = nil
    public var multiMaterialSystem = "none"
    public var source = SourceReference()
    public init() {}
    public var name: String { manufacturer + " " + model }
}
public struct FilamentProduct: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID = UUID()
    public var manufacturer = "Generic"
    public var productName = "New filament"
    // Optional so existing saved libraries continue to decode without migration.
    public var stock: FilamentStock? = nil
    public var catalogSnapshot: CatalogFilamentSnapshot? = nil
    public var externalProfile: ExternalProfileSource? = nil
    public var materialFamily = "PLA"
    public var colorName = "Natural"
    public var diameterMM: Double = 1.75
    public var netWeightGrams: Double = 1000
    public var pricePerKG: Decimal = 20
    public var source = SourceReference()
    public init() {}
    public var name: String { manufacturer + " " + productName }
}
public struct PricingPreset: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID = UUID()
    public var name = "Custom"
    public var mode: PricingMode = .margin
    public var rate: Decimal = Decimal(string: "0.4")!
    public var materialMultiplier: Decimal = 1
    public var machineRate: Decimal = 1
    public var laborRate: Decimal = 30
    public var minimumCharge: Decimal = 10
    public var rushMultiplier: Decimal = 1
    public init() {}
}
public struct BusinessSettings: Codable, Sendable {
    public var businessName = "My Print Studio"
    public var currency = "USD"
    public var electricityRate: Decimal = Decimal(string: "0.14")!
    public var taxRate: Decimal = 0
    public var expirationDays = 30
    public init() {}
}
public struct PricingInput: Codable, Sendable, Equatable {
    public var toolJob: ToolJob? = nil
    public var modelGrams: Decimal = 200
    public var supportGrams: Decimal = 50
    public var interfaceGrams: Decimal = 0
    public var purgeGrams: Decimal = 30
    public var towerGrams: Decimal = 0
    public var startupGrams: Decimal = 0
    public var pricePerKG: Decimal = 20
    public var supportPricePerKG: Decimal = 20
    public var interfacePricePerKG: Decimal = 20
    public var printHours: Decimal = 10
    public var averageWatts: Decimal = 150
    public var electricityRate: Decimal = Decimal(string: "0.14")!
    public var machineRate: Decimal = 1
    public var maintenanceRate: Decimal = Decimal(string: "0.25")!
    public var laborMinutes: Decimal = 30
    public var laborRate: Decimal = 30
    public var dryerWatts: Decimal = 0
    public var dryingHours: Decimal = 0
    public var dryingSharedJobs: Decimal = 1
    public var wearCost: Decimal = 0
    public var packaging: Decimal = 0
    public var outsideServices: Decimal = 0
    public var otherCosts: Decimal = 0
    public var failureProbability: Decimal = 0
    public var overheadRate: Decimal = 0
    public var pricingMode: PricingMode = .margin
    public var profitRate: Decimal = Decimal(string: "0.4")!
    public var materialMultiplier: Decimal = 1
    public var minimumCharge: Decimal = 0
    public var rushMultiplier: Decimal = 1
    public var discountRate: Decimal = 0
    public var taxRate: Decimal = 0
    public var shipping: Decimal = 0
    public init() {}
}
public struct CostComponent: Codable, Sendable, Equatable, Identifiable {
    public var name: String
    public var amount: Decimal
    public var id: String { name }
}
public struct PricingResult: Codable, Sendable, Equatable {
    public var components: [CostComponent]
    public var totalGrams: Decimal
    public var materialEfficiency: Decimal
    public var productionCost: Decimal
    public var overhead: Decimal
    public var minimumApplied: Bool
    public var subtotal: Decimal
    public var discount: Decimal
    public var tax: Decimal
    public var shipping: Decimal
    public var total: Decimal
}
public struct Quote: Identifiable, Codable, Sendable {
    public var id: UUID = UUID()
    public var number = ""
    public var customer = ""
    public var projectName = "Untitled project"
    public var status = "draft"
    public var createdAt = Date()
    public var expiresAt = Date().addingTimeInterval(30 * 86400)
    public var currency = "USD"
    public var notes = ""
    public var printer: PrinterProfile? = nil
    public var filament: FilamentProduct? = nil
    public var preset: PricingPreset? = nil
    public var input = PricingInput()
    public var result: PricingResult? = nil
    public var schemaVersion = 2
    public init() {}
}
public struct LibrarySnapshot: Codable, Sendable {
    public var schemaVersion = 2
    public var printers: [PrinterProfile] = []
    public var filaments: [FilamentProduct] = []
    public var presets: [PricingPreset] = []
    public var quotes: [Quote] = []
    public var settings = BusinessSettings()
    public init() {}
}

/// Optional manual stock counts; saving a quote does not consume inventory.
public struct FilamentStock: Codable, Sendable, Equatable {
    public var spoolCount: Int = 0
    public var remainingGrams: Decimal = 0
    public var location: String = ""
    public var notes: String = ""
    public init() {}
}
public extension FilamentProduct {
    func validateMaterial() throws {
        guard !manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              diameterMM.isFinite, diameterMM > 0, netWeightGrams.isFinite, netWeightGrams > 0 else {
            throw PricingError.invalid("Enter a manufacturer, product, positive diameter and spool weight.")
        }
        guard !pricePerKG.isNaN, pricePerKG >= 0 else { throw PricingError.invalid("Material cost must be zero or greater.") }
        if let stock {
            guard stock.spoolCount >= 0, !stock.remainingGrams.isNaN, stock.remainingGrams >= 0 else {
                throw PricingError.invalid("Stock counts and remaining grams must be zero or greater.")
            }
        }
    }
}
