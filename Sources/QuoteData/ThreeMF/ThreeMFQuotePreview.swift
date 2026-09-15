import Foundation
import QuoteDomain

public enum ThreeMFQuotePreview {
    /// Values are explicitly selected by their source/plate/role identity; duplicate sources are never summed.
    public static func key(_ q:ImportedQuantity)->String { [q.amount.sourcePath,q.amount.metadataKey,q.plateID ?? "",q.materialID ?? "",q.role,q.unit].joined(separator:"|") }
    public static func apply(_ project:ImportedPrintProject, to quote:Quote, selected:Set<String>, printer:PrinterProfile?=nil, useImportedTools:Bool=false, material:FilamentProduct?=nil)throws->Quote {
        var result=quote
        guard quote.input.toolJob == nil || (selected.isEmpty && !useImportedTools) else { throw ThreeMFFailure.damaged("This quote uses per-tool material assignments. Review those assignments in the quote editor before applying imported quantities or a different tool system.") }
        let quantities=project.estimates.filter{selected.contains(key($0))}
        let groups=Dictionary(grouping:quantities,by:\.role)
        guard groups.values.allSatisfy({$0.count<=1}) else {throw ThreeMFFailure.damaged("Select one source per pricing field. Multi-plate/filament totals must be reviewed separately.")}
        guard Set(quantities.compactMap(\.plateID)).count<=1 else {throw ThreeMFFailure.damaged("Select quantities from one plate per quote.")}
        if let printer { result.printer=printer }
        if useImportedTools {
            guard var printer=result.printer,let system=project.toolSystem.reviewedSystem() else {throw ThreeMFFailure.damaged("Choose a printer and resolve physical toolhead/nozzle information before using imported tools.")}
            printer.toolSystem=system;result.printer=printer // A quote snapshot only; never mutate the user's library.
        }
        if let material { result.filament=material;result.input.pricePerKG=material.pricePerKG }
        for q in quantities {
            guard q.amount.value.isFinite,q.amount.value>=0 else {throw ThreeMFFailure.damaged("Invalid selected quantity.")}
            let value=Decimal(q.amount.value)
            switch(q.role,q.unit) {
            case("printTime","seconds"):result.input.printHours=value/3600
            case("model","grams"):result.input.modelGrams=value
            case("support","grams"):result.input.supportGrams=value
            case("supportInterface","grams"):result.input.interfaceGrams=value
            case("purge","grams"):result.input.purgeGrams=value
            case("primeTower","grams"):result.input.towerGrams=value
            default:throw ThreeMFFailure.damaged("This quantity is evidence only; it cannot safely populate that pricing field.")
            }
        }
        result.manufacturingImport = .init(project:project,acceptedFields:selected.sorted())
        result.result=nil
        return result
    }
    public static func differences(old:ImportedPrintProject,new:ImportedPrintProject)->[ConfigurationDifference] {
        var differences=[ConfigurationDifference]()
        if old.printer.model?.value != new.printer.model?.value {differences.append(.init("Printer",imported:new.printer.model?.value ?? "unknown",current:old.printer.model?.value ?? "unknown"))}
        func compare(_ field:String,_ before:String,_ after:String) {
            if before != after {differences.append(.init(field,imported:after,current:before))}
        }
        compare("Physical toolheads",old.toolSystem.physicalToolheads.map{String($0.value)} ?? "unknown",new.toolSystem.physicalToolheads.map{String($0.value)} ?? "unknown")
        compare("Nozzle diameters",old.toolSystem.tools.map{$0.nozzleDiameterMM.map{String($0.value)} ?? "unknown"}.joined(separator:", "),new.toolSystem.tools.map{$0.nozzleDiameterMM.map{String($0.value)} ?? "unknown"}.joined(separator:", "))
        compare("Plates",old.plates.map(\.id).sorted().joined(separator:", "),new.plates.map(\.id).sorted().joined(separator:", "))
        func materials(_ project:ImportedPrintProject)->String {project.materials.map{[$0.id,$0.family?.value ?? "unknown",$0.sourceColorHex?.value ?? "unknown"].joined(separator:" ")}.sorted().joined(separator:"; ")}
        compare("Material identities/colors",materials(old),materials(new))
        let newKeys=Set(new.estimates.map(key))
        for q in old.estimates where !newKeys.contains(key(q)) {differences.append(.init(q.role,imported:"no longer reported",current:String(q.amount.value)+" "+q.unit))}
        let oldQuantities=Dictionary(grouping:old.estimates,by:key)
        for q in new.estimates {let previous=oldQuantities[key(q)]?.first?.amount.value;if previous != q.amount.value {differences.append(.init(q.role,imported:String(q.amount.value)+" "+q.unit,current:previous.map { String($0) } ?? "not previously present"))}}
        return differences
    }
}
