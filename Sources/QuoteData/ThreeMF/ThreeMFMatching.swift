import Foundation
import QuoteDomain

public enum ThreeMFPrinterMatcher {
    public static func normalize(_ text:String)->String {
        var value=text.lowercased().replacingOccurrences(of:#"\b(?:bambu lab|bambu|bbl)\b"#,with:"bambu",options:.regularExpression).replacingOccurrences(of:"prusa research",with:"prusa").replacingOccurrences(of:"original prusa",with:"prusa")
        value=value.replacingOccurrences(of:#"\d+(?:\.\d+)?\s*(?:mm\s*)?nozzle"#,with:"",options:.regularExpression)
        return value.components(separatedBy:CharacterSet.alphanumerics.inverted).filter{!$0.isEmpty}.joined(separator:" ")
    }
    public static func match(_ imported:ImportedPrinterConfiguration, printers:[PrinterProfile])->[ImportMatch] {
        let model=normalize(imported.model?.value ?? "");let vendor=normalize(imported.manufacturer?.value ?? "");let preset=normalize(imported.presetName?.value ?? "")
        guard !model.isEmpty || !preset.isEmpty else{return []}
        return printers.compactMap { p in
            let candidate=normalize(p.model);let full=normalize(p.manufacturer+" "+p.model);let v=normalize(p.manufacturer)
            let vendorOK=vendor.isEmpty || vendor==v
            if !model.isEmpty && vendorOK && (model==candidate || model==full || model==candidate.replacingOccurrences(of:v+" ",with:"")) {return .init(id:p.id,name:p.name,quality:"exact",reason:"Model identity matches; nozzle and saved modifications still require comparison.")}
            if !preset.isEmpty && vendorOK && (preset==candidate || preset==full) {return .init(id:p.id,name:p.name,quality:"high",reason:"Preset-name match only; renamed presets can be stale.")}
            let tokens=Set((model.isEmpty ? preset:model).split(separator:" "));let other=Set(full.split(separator:" "))
            if !tokens.isEmpty && tokens.isSubset(of:other) {return .init(id:p.id,name:p.name,quality:"possible",reason:"Partial text match; never automatically selected.")};return nil
        }.sorted{a,b in let rank=["exact":0,"high":1,"possible":2];return rank[a.quality]! == rank[b.quality]! ? a.name<b.name:rank[a.quality]!<rank[b.quality]!}
    }
}
public enum ThreeMFFilamentMatcher {
    public static func matchCatalog(_ material:ImportedMaterial,catalog:[CatalogFilament])->[ImportMatch] {
        // Catalog candidates are recommendations only; no catalog price replaces inventory cost.
        let products=catalog.map { p in
            var m=FilamentProduct();m.id=p.id;m.manufacturer=p.brand;m.productName=p.name;m.materialFamily=p.materialFamily;return m
        }
        return match(material,materials:products).map { .init(id:$0.id,name:$0.name,quality:$0.quality,reason:"PrintQuote filament database: "+$0.reason) }
    }
    public static func match(_ material:ImportedMaterial, materials:[FilamentProduct])->[ImportMatch] {
        let family=ThreeMFPrinterMatcher.normalize(material.family?.value ?? "");let name=ThreeMFPrinterMatcher.normalize(material.productName?.value ?? material.preset?.value ?? "");let brand=ThreeMFPrinterMatcher.normalize(material.manufacturer?.value ?? "")
        return materials.compactMap { m in
            let sameFamily = !family.isEmpty && family==ThreeMFPrinterMatcher.normalize(m.materialFamily)
            let sameName = !name.isEmpty && name==ThreeMFPrinterMatcher.normalize(m.productName)
            let sameBrand = !brand.isEmpty && brand==ThreeMFPrinterMatcher.normalize(m.manufacturer)
            if sameName && sameBrand && sameFamily {return .init(id:m.id,name:m.name,quality:"exact",reason:"Brand, product and material family match; color/stock must still be reviewed.")}
            if sameName && sameFamily {return .init(id:m.id,name:m.name,quality:"likely",reason:"Product and family match; manufacturer is incomplete.")}
            if sameFamily {return .init(id:m.id,name:m.name,quality:"genericMaterialOnly",reason:"Family match only; inventory cost remains authoritative.")};return nil
        }.sorted{a,b in let rank=["exact":0,"likely":1,"genericMaterialOnly":2];return rank[a.quality]! < rank[b.quality]!}.prefix(100).map{$0}
    }
}
public enum ThreeMFCompatibility {
    public static func compare(_ project:ImportedPrintProject, printer:PrinterProfile)->[ConfigurationDifference] {
        var output=[ConfigurationDifference]()
        let imported=project.toolSystem.tools.compactMap{$0.nozzleDiameterMM?.value}.map{String($0)}.joined(separator:", ")
        let configured=printer.toolSystem?.toolheads.map{NSDecimalNumber(decimal:$0.nozzleDiameterMM).stringValue+" "+$0.nozzleMaterial.rawValue}.joined(separator:", ") ?? "unknown"
        output.append(.init("Nozzles",imported:imported.isEmpty ? "unknown":imported,current:configured))
        output.append(.init("Physical toolheads",imported:project.toolSystem.physicalToolheads.map{String($0.value)} ?? "needs review",current:printer.toolSystem.map{String($0.availableToolheadCount)} ?? "unknown"))
        output.append(.init("Filament inputs",imported:project.toolSystem.filamentInputs.map{String($0.value)} ?? "unknown",current:printer.toolSystem.map{String($0.filamentInputCount)} ?? "unknown"))
        output.append(.init("Accessories",imported:project.toolSystem.feederType?.value ?? "not specified",current:printer.hardware?.installedAccessories.joined(separator:", ") ?? "not specified"))
        return output
    }
    public static func check(_ project:ImportedPrintProject, printer:PrinterProfile)->[ImportDiagnostic] {
        var diagnostics=[ImportDiagnostic]()
        let mode=PrinterOperatingMode(rawValue:project.printer.operatingMode?.value ?? "")
        let volume=printer.hardware?.buildVolumeByOperatingMode.first{$0.mode==mode}
        let bounds=volume.map{[$0.widthMM,$0.depthMM,$0.heightMM]} ?? [printer.buildVolumeXMM,printer.buildVolumeYMM,printer.buildVolumeZMM]
        if mode != nil && volume == nil {diagnostics.append(.init(.warning,"3MF.Compatibility","modeVolumeUnknown","No usable build volume for the imported operating mode; full-volume check is provisional."))}
        for object in project.objects where object.instanceCount==1 && object.id.hasPrefix("instance:") {
            guard let box=object.boundsMM?.value else{continue}
            var exceeds=zip(box.dimensions,bounds).contains{$0>$1+0.001}
            if volume?.shape == .circular, let diameter=volume?.diameterMM {exceeds = exceeds || hypot(box.dimensions[0],box.dimensions[1])>diameter}
            if exceeds {diagnostics.append(.init(.warning,"3MF.Compatibility","buildVolume","\(object.name ?? object.id) exceeds the selected configuration's usable volume.",path:object.sourcePath))}
        }
        for material in project.materials {
            let family=(material.family?.value ?? "").uppercased();let abrasive=family.contains("CF") || family.contains("GF") || material.properties.contains{$0.name=="filament_is_abrasive" && ["1","true"].contains($0.source.value)}
            if abrasive && printer.toolSystem?.toolheads.contains(where:{!$0.abrasiveMaterialsAllowed}) == true {diagnostics.append(.init(.warning,"3MF.Materials","abrasive","\(family) may require hardened nozzles/gears; the selected configuration is not marked abrasive-capable."))}
            if family.contains("TPU") && (project.toolSystem.feederSlots?.value ?? 0)>0 {diagnostics.append(.init(.warning,"3MF.Compatibility","feederReview","Flexible filament through the imported feeder needs a compatibility review."))}
            for temperature in material.temperatures where temperature.metadataKey.contains("nozzle") || temperature.metadataKey=="temperature" {
                if let maximum=printer.toolSystem?.toolheads.compactMap(\.maxNozzleTemperatureC).min(),Decimal(temperature.value)>maximum {diagnostics.append(.init(.warning,"3MF.Compatibility","temperature","Imported nozzle temperature exceeds a configured tool limit."))}
            }
        }
        let differences=compare(project,printer:printer)
        if let source=project.toolSystem.physicalToolheads?.value,let current=printer.toolSystem?.availableToolheadCount,source != current {diagnostics.append(.init(.warning,"3MF.Toolheads","configurationDiffers","Imported and current physical toolhead counts differ. Saved configuration is unchanged."))}
        if differences.first?.imported != differences.first?.current {diagnostics.append(.init(.info,"3MF.Compatibility","reviewConfiguration","Review imported nozzle evidence against saved nozzle materials and custom modifications."))}
        return diagnostics
    }
}
