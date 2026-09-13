import Foundation

public enum ToolArchitecture: String, Codable, CaseIterable, Sendable {
    case singleTool, singleNozzleSwitcher, idex, dualExtruder, fixedMultiNozzle, toolChanger, mixingHotend, custom
}
public enum NozzleMaterial: String, Codable, CaseIterable, Sendable { case unknown, brass, hardenedSteel, stainlessSteel, tungstenCarbide, ruby, custom }
public struct ToolheadConfiguration: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var index: Int
    public var name: String
    public var nozzleDiameterMM: Decimal = Decimal(string:"0.4")!
    public var nozzleMaterial: NozzleMaterial = .unknown
    public var maxNozzleTemperatureC: Decimal? = nil
    public var supportedMaterialFamilies: [String] = []
    public var abrasiveMaterialsAllowed = false
    public var flexibleMaterialsAllowed = false
    public var changeOverheadSeconds: Decimal = 0
    public var purgeGramsPerActivation: Decimal = 0
    public var wipeGramsPerActivation: Decimal = 0
    public var additionalHeaterWatts: Decimal = 0
    public var parkedHeaterWatts: Decimal = 0
    public var maintenancePerHour: Decimal = 0
    public var nozzleReplacementCost: Decimal = 0
    public var nozzleLifeHours: Decimal = 1000
    public var abrasiveWearMultiplier: Decimal = 1
    public var needsReview = true
    public init(index: Int) { self.index = index; self.name = "Tool \(index)" }
}
public struct PrinterToolSystem: Codable, Equatable, Sendable {
    public var availableToolheadCount = 1
    public var toolheads = [ToolheadConfiguration(index:1)]
    public var architecture: ToolArchitecture = .singleTool
    public var simultaneousToolUseCount = 1
    public var filamentInputCount = 1
    public var feederSlotCount = 0
    public var maxSimultaneousMaterials = 1
    public var maxAutomaticSelectableMaterials = 1
    public var automaticMaterialSwitching = false
    public var sharedNozzle = true
    public var materialSwitchSeconds: Decimal = 0
    public var purgeGramsPerMaterialSwitch: Decimal = 0
    public var needsReview = true
    public init() {}
    public mutating func resize(to count: Int) {
        guard (1...12).contains(count) else { return }
        if count > toolheads.count { for index in (toolheads.count + 1)...count { toolheads.append(ToolheadConfiguration(index:index)) } }
        else { toolheads = Array(toolheads.prefix(count)) }
        availableToolheadCount = count
        simultaneousToolUseCount = min(simultaneousToolUseCount,count)
        maxSimultaneousMaterials = min(maxSimultaneousMaterials,count)
        needsReview = true
    }
    public func validate() throws {
        guard (1...12).contains(availableToolheadCount), toolheads.count == availableToolheadCount else { throw PricingError.invalid("Physical toolheads must number 1–12 and match the tool records.") }
        guard (1...availableToolheadCount).contains(simultaneousToolUseCount), filamentInputCount >= 1, feederSlotCount >= 0, maxSimultaneousMaterials >= 1, maxSimultaneousMaterials <= filamentInputCount, maxAutomaticSelectableMaterials >= 1, maxAutomaticSelectableMaterials <= filamentInputCount else { throw PricingError.invalid("Tool, input and material counts are inconsistent.") }
        guard Set(toolheads.map(\.id)).count == toolheads.count, toolheads.map(\.index).sorted() == Array(1...availableToolheadCount) else { throw PricingError.invalid("Tool IDs and indices must be unique and sequential.") }
        if architecture == .singleTool || architecture == .singleNozzleSwitcher {
            guard availableToolheadCount == 1, sharedNozzle else { throw PricingError.invalid("A single-tool architecture has one physical toolhead and a shared nozzle.") }
        }
        if architecture == .idex { guard availableToolheadCount == 2, !sharedNozzle else { throw PricingError.invalid("IDEX requires two independent toolheads.") } }
        if [.toolChanger, .fixedMultiNozzle, .dualExtruder].contains(architecture) {
            guard !sharedNozzle else { throw PricingError.invalid("This architecture uses independent nozzles.") }
        }
        try nonnegative([materialSwitchSeconds,purgeGramsPerMaterialSwitch])
        for t in toolheads {
            try nonnegative([t.nozzleDiameterMM,t.maxNozzleTemperatureC ?? 0,t.changeOverheadSeconds,t.purgeGramsPerActivation,t.wipeGramsPerActivation,t.additionalHeaterWatts,t.parkedHeaterWatts,t.maintenancePerHour,t.nozzleReplacementCost,t.nozzleLifeHours,t.abrasiveWearMultiplier])
            guard t.nozzleDiameterMM > 0, t.nozzleLifeHours > 0, t.abrasiveWearMultiplier >= 1 else { throw PricingError.invalid("Nozzle diameter/life must be positive and wear multiplier at least 1.") }
        }
    }
}
func nonnegative(_ values: [Decimal]) throws {
    guard values.allSatisfy({ !$0.isNaN && $0 >= 0 }) else { throw PricingError.invalid("Tool costs and quantities must be finite nonnegative numbers.") }
}
public enum MaterialRole: String, Codable, CaseIterable, Sendable { case model, support, interface }
public struct ToolMaterialAssignment: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var toolIndex = 1
    public var feederSlot: Int? = nil
    public var materialID: UUID? = nil
    public var materialName = "Manual material"
    public var materialFamily = "PLA"
    public var colorName = "Natural"
    public var role: MaterialRole = .model
    public var grams: Decimal = 0
    public var pricePerKG: Decimal = 20
    public var activeHours: Decimal = 0
    public var activationCount = 0
    public var abrasive = false
    public var flexible = false
    public init() {}
}
public struct ToolJob: Codable, Equatable, Sendable {
    public var system = PrinterToolSystem()
    public var assignments: [ToolMaterialAssignment] = []
    public init() {}
}
public struct ToolCostResult: Sendable {
    public var components: [CostComponent] = []
    public var materialCost: Decimal = 0
    public var finalPartGrams: Decimal = 0
    public var totalGrams: Decimal = 0
    public var changeHours: Decimal = 0
    public var additionalEnergyKWh: Decimal = 0
    public var maintenance: Decimal = 0
    public var wear: Decimal = 0
    public var warnings: [String] = []
}
public enum ToolCostEngine {
    public static func calculate(_ job: ToolJob, printHours: Decimal) throws -> ToolCostResult {
        try job.system.validate(); try nonnegative([printHours])
        guard !job.assignments.isEmpty else { throw PricingError.invalid("Add at least one material assignment.") }
        var r = ToolCostResult()
        var hoursByTool: [Int: Decimal] = [:]
        for a in job.assignments {
            guard let tool = job.system.toolheads.first(where: {$0.index == a.toolIndex}), a.activationCount >= 0 else { throw PricingError.invalid("Assignment references an unavailable tool or invalid change count.") }
            try nonnegative([a.grams,a.pricePerKG,a.activeHours])
            if let slot = a.feederSlot { guard slot >= 1 && slot <= job.system.feederSlotCount else { throw PricingError.invalid("Assignment feeder slot is outside the configured slot count.") } }
            hoursByTool[a.toolIndex,default:0] += a.activeHours
            let shared = job.system.sharedNozzle
            let changes = Decimal(a.activationCount)
            let purge = changes * (shared ? job.system.purgeGramsPerMaterialSwitch : tool.purgeGramsPerActivation + tool.wipeGramsPerActivation)
            let seconds = changes * (shared ? job.system.materialSwitchSeconds : tool.changeOverheadSeconds)
            if job.system.architecture == .singleTool && a.activationCount > 0 { r.warnings.append("Single-tool changes are manual; include operator labor separately.") }
            r.changeHours += seconds / 3600
            let material = a.grams / 1000 * a.pricePerKG
            let waste = purge / 1000 * a.pricePerKG
            r.materialCost += material + waste
            r.totalGrams += a.grams + purge
            if a.role == .model { r.finalPartGrams += a.grams }
            let label = "Tool \(tool.index) · \(a.materialName) · \(a.role.rawValue)"
            r.components.append(CostComponent(name:label + " · " + a.id.uuidString.prefix(4),amount:material))
            r.components.append(CostComponent(name:"Change waste · " + a.id.uuidString.prefix(4),amount:waste))
            r.additionalEnergyKWh += tool.additionalHeaterWatts / 1000 * a.activeHours
            r.maintenance += tool.maintenancePerHour * a.activeHours
            r.wear += tool.nozzleReplacementCost / tool.nozzleLifeHours * a.activeHours * (a.abrasive ? tool.abrasiveWearMultiplier : 1)
            if a.abrasive && !tool.abrasiveMaterialsAllowed { r.warnings.append("Tool \(tool.index): abrasive compatibility is unconfirmed or disallowed.") }
            if a.flexible && !tool.flexibleMaterialsAllowed { r.warnings.append("Tool \(tool.index): flexible compatibility is unconfirmed or disallowed.") }
            if !tool.supportedMaterialFamilies.contains(a.materialFamily) { r.warnings.append("Tool \(tool.index): review \(a.materialFamily) capability.") }
        }
        guard hoursByTool.values.allSatisfy({$0 <= printHours}), hoursByTool.values.reduce(0,+) <= printHours * Decimal(job.system.simultaneousToolUseCount) else { throw PricingError.invalid("Assigned tool hours exceed print time or simultaneous tool capacity.") }
        // Independent carriage / fixed-nozzle systems may keep parked heaters warm.
        // Toolchangers charge active heater use only; parked power is not assumed.
        if [.idex,.dualExtruder,.fixedMultiNozzle].contains(job.system.architecture) {
            for tool in job.system.toolheads { r.additionalEnergyKWh += max(0,printHours - hoursByTool[tool.index,default:0]) * tool.parkedHeaterWatts / 1000 }
        }
        if job.system.needsReview || job.system.toolheads.contains(where: \.needsReview) { r.warnings.append("Review tool configuration and change/purge assumptions before quoting.") }
        return r
    }
}
