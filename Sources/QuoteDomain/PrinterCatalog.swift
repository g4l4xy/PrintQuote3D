import Foundation

public extension NormalizedTechnicalProfile {
    func makePrinterProfile() -> PrinterProfile {
        var printer = PrinterProfile()
        printer.id = id
        printer.manufacturer = vendor == "BBL" ? "Bambu Lab" : vendor
        let prefix = printer.manufacturer + " "
        printer.model = name.lowercased().hasPrefix(prefix.lowercased()) ? String(name.dropFirst(prefix.count)) : name
        printer.buildVolumeXMM = buildXMM ?? 0
        printer.buildVolumeYMM = buildYMM ?? 0
        printer.buildVolumeZMM = buildZMM ?? 0
        printer.typicalPowerWatts = 0
        printer.machineRate = 0
        printer.maintenanceRate = 0
        printer.externalProfile = source
        var reference = SourceReference()
        reference.name = source.sourceName
        reference.url = source.sourcePath.hasPrefix("https://") ? source.sourcePath : source.repositoryURL + "/blob/" + source.commitSHA + "/" + source.sourcePath
        reference.sourceType = source.sourcePath.hasPrefix("https://") ? "manufacturerSpecifications" : "slicerProfile"
        reference.retrievedAt = source.importedAt
        reference.notes = reviewReasons.joined(separator: "\n")
        printer.source = reference
        var system = PrinterToolSystem()
        system.architecture = .custom
        system.resize(to: physicalToolheadCount ?? 1)
        if let nozzle = nozzleDiametersMM.first { system.toolheads[0].nozzleDiameterMM = Decimal(nozzle) }
        if source.sourcePath.hasPrefix("https://"), let raw = technicalValues["physical_tool_architecture"]?.first, let architecture = ToolArchitecture(rawValue: raw) {
            system.architecture = architecture
            system.sharedNozzle = false
            system.filamentInputCount = system.availableToolheadCount
            system.maxAutomaticSelectableMaterials = system.availableToolheadCount
            system.automaticMaterialSwitching = true
        }
        printer.toolSystem = system
        var hardware = PrinterHardwareDetails()
        for (key, values) in technicalValues {
            hardware.fieldSources[key] = TechnicalField(value: values.joined(separator: ", "), sourcePath: fieldSourcePaths[key] ?? source.sourcePath, sourcePriority: source.sourcePath.hasPrefix("https://") ? 1 : 3, userOverride: false)
        }
        for (key, value, upstreamKey) in [("buildXMM", buildXMM, "printable_area"), ("buildYMM", buildYMM, "printable_area"), ("buildZMM", buildZMM, "printable_height")] {
            if let value { hardware.fieldSources[key] = TechnicalField(value: String(value), sourcePath: fieldSourcePaths[upstreamKey] ?? source.sourcePath, sourcePriority: source.sourcePath.hasPrefix("https://") ? 1 : 3, userOverride: false) }
        }
        if let values = technicalValues["dual_build_volume_mm"], values.count == 3,
           let x = Double(values[0]), let y = Double(values[1]), let z = Double(values[2]) {
            var single = OperatingModeBuildVolume()
            single.mode = .singleExtrusion; single.widthMM = buildXMM ?? 0; single.depthMM = buildYMM ?? 0; single.heightMM = buildZMM ?? 0
            single.notes = "Manufacturer single-extruder usable volume."
            var dual = OperatingModeBuildVolume()
            dual.mode = .dualExtrusion; dual.widthMM = x; dual.depthMM = y; dual.heightMM = z
            dual.notes = "Manufacturer dual-extruder usable volume."
            hardware.buildVolumeByOperatingMode = [single, dual]
        }
        printer.hardware = hardware
        return printer
    }
}

public extension LibrarySnapshot {
    /// Add missing catalog records once. Existing equipment, costs and quote snapshots remain user-owned.
    mutating func includePrinters(from catalog: TechnicalProfileCatalog) {
        var existing = Set(printers.map(\.id))
        for profile in catalog.profiles where profile.kind == "machine" {
            if existing.insert(profile.id).inserted { printers.append(profile.makePrinterProfile()) }
        }
    }
}
