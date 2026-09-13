import Foundation

public enum PricingError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}
public enum PricingEngine {
    public static func rounded(_ value: Decimal) -> Decimal {
        var original = value; var result = Decimal()
        NSDecimalRound(&result, &original, 2, .plain)
        return result
    }
    public static func calculate(_ i: PricingInput) throws -> PricingResult {
        let data = try JSONEncoder().encode(i)
        let object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        for (key, value) in object {
            if let number = value as? NSNumber, number.doubleValue < 0 || !number.doubleValue.isFinite {
                throw PricingError.invalid("\(key) must be a finite, nonnegative number.")
            }
        }
        guard i.profitRate < 1 || i.pricingMode == .markup else { throw PricingError.invalid("Target margin must be below 100%.") }
        guard i.failureProbability <= 1, i.discountRate <= 1, i.taxRate <= 1 else { throw PricingError.invalid("Risk, discount and tax must be between 0 and 1.") }
        guard i.dryingSharedJobs >= 1, i.rushMultiplier >= 1, i.materialMultiplier >= 1 else { throw PricingError.invalid("Shared jobs and multipliers must be at least 1.") }
        let toolCost = try i.toolJob.map { try ToolCostEngine.calculate($0, printHours: i.printHours) }
        let chargedHours = i.printHours + (toolCost?.changeHours ?? 0)
        var components: [CostComponent] = []
        func add(_ name: String, _ amount: Decimal) { components.append(CostComponent(name: name, amount: amount)) }
        if let toolCost { components = toolCost.components } else {
        add("Model material", i.modelGrams / 1000 * i.pricePerKG)
        add("Support material", i.supportGrams / 1000 * i.supportPricePerKG)
        add("Support interface", i.interfaceGrams / 1000 * i.interfacePricePerKG)
        add("Purge / flush", i.purgeGrams / 1000 * i.pricePerKG)
        add("Prime tower", i.towerGrams / 1000 * i.pricePerKG)
        add("Startup purge", i.startupGrams / 1000 * i.pricePerKG)
        }
        let materialCost = components.reduce(Decimal.zero) { $0 + $1.amount }
        add("Electricity", i.averageWatts / 1000 * chargedHours * i.electricityRate)
        add("Drying", i.dryerWatts / 1000 * i.dryingHours * i.electricityRate / i.dryingSharedJobs)
        add("Machine", i.machineRate * chargedHours)
        add("Maintenance", i.maintenanceRate * chargedHours)
        add("Nozzle / consumable wear", i.wearCost)
        if let toolCost {
            add("Additional tool energy", toolCost.additionalEnergyKWh * i.electricityRate)
            add("Tool maintenance", toolCost.maintenance)
            add("Tool nozzle wear", toolCost.wear)
        }
        add("Labor", i.laborMinutes / 60 * i.laborRate)
        // Reserve covers manufacturing, including labor, before packaging and external costs.
        let reserve = components.reduce(Decimal.zero) { $0 + $1.amount } * i.failureProbability
        add("Failure reserve", reserve)
        add("Packaging", i.packaging)
        add("Outside services", i.outsideServices)
        add("Other direct costs", i.otherCosts)
        let production = components.reduce(Decimal.zero) { $0 + $1.amount }
        let overhead = production * i.overheadRate
        let basis = production + overhead + materialCost * (i.materialMultiplier - 1)
        let price = i.pricingMode == .margin ? basis / (1 - i.profitRate) : basis * (1 + i.profitRate)
        let minimumApplied = price < i.minimumCharge
        let subtotal = rounded(max(price, i.minimumCharge) * i.rushMultiplier)
        let discount = rounded(subtotal * i.discountRate)
        let tax = rounded((subtotal - discount) * i.taxRate)
        let shipping = rounded(i.shipping)
        let grams = toolCost?.totalGrams ?? (i.modelGrams + i.supportGrams + i.interfaceGrams + i.purgeGrams + i.towerGrams + i.startupGrams)
        return PricingResult(components: components, totalGrams: grams, materialEfficiency: grams == 0 ? 0 : (toolCost?.finalPartGrams ?? i.modelGrams) / grams, productionCost: production, overhead: overhead, minimumApplied: minimumApplied, subtotal: subtotal, discount: discount, tax: tax, shipping: shipping, total: subtotal - discount + tax + shipping)
    }
}
