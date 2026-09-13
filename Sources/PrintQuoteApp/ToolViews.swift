import SwiftUI
import QuoteDomain

struct ToolSystemEditor: View {
    @Binding var system: PrinterToolSystem
    var body: some View {
        SwiftUI.Section("Tool system") {
            Picker("Architecture",selection:$system.architecture) { ForEach(ToolArchitecture.allCases,id:\.self) { Text($0.rawValue).tag($0) } }
            Picker("Available physical toolheads",selection:Binding(get:{system.availableToolheadCount},set:{system.resize(to:$0)})) { ForEach(1...12,id:\.self) { Text("\($0)").tag($0) } }
            Stepper("Simultaneously active: \(system.simultaneousToolUseCount)",value:$system.simultaneousToolUseCount,in:1...system.availableToolheadCount)
            Stepper("Filament inputs: \(system.filamentInputCount)",value:$system.filamentInputCount,in:1...96)
            Stepper("Feeder slots: \(system.feederSlotCount)",value:$system.feederSlotCount,in:0...96)
            Stepper("Simultaneous materials: \(system.maxSimultaneousMaterials)",value:$system.maxSimultaneousMaterials,in:1...system.filamentInputCount)
            Stepper("Automatic selectable materials: \(system.maxAutomaticSelectableMaterials)",value:$system.maxAutomaticSelectableMaterials,in:1...system.filamentInputCount)
            Toggle("Automatic material switching",isOn:$system.automaticMaterialSwitching)
            Toggle("Shared nozzle",isOn:$system.sharedNozzle)
            if system.sharedNozzle {
                DecimalField(title:"Reload time per material change (seconds)",value:$system.materialSwitchSeconds)
                DecimalField(title:"Purge per material change (g)",value:$system.purgeGramsPerMaterialSwitch)
            }
            Toggle("Configuration needs review",isOn:$system.needsReview)
            Text("Physical toolheads are separate from feeder slots and colors. New tool records require review.").font(.caption).foregroundStyle(.secondary)
            ForEach($system.toolheads) { $tool in
                DisclosureGroup(tool.name) {
                    TextField("Name",text:$tool.name)
                    DecimalField(title:"Nozzle diameter (mm)",value:$tool.nozzleDiameterMM)
                    Picker("Nozzle material",selection:$tool.nozzleMaterial) { ForEach(NozzleMaterial.allCases,id:\.self) { Text($0.rawValue).tag($0) } }
                    TextField("Maximum nozzle °C (blank = unknown)",text:Binding(get:{tool.maxNozzleTemperatureC.map {$0.formatted()} ?? ""},set:{tool.maxNozzleTemperatureC = Decimal(string:$0)}))
                    TextField("Material families (comma separated)",text:Binding(get:{tool.supportedMaterialFamilies.joined(separator:", ")},set:{tool.supportedMaterialFamilies = $0.split(separator:",").map {$0.trimmingCharacters(in:.whitespaces)}}))
                    Toggle("Abrasive materials allowed",isOn:$tool.abrasiveMaterialsAllowed)
                    Toggle("Flexible materials allowed",isOn:$tool.flexibleMaterialsAllowed)
                    DecimalField(title:"Tool activation time (seconds)",value:$tool.changeOverheadSeconds)
                    DecimalField(title:"Activation purge (g)",value:$tool.purgeGramsPerActivation)
                    DecimalField(title:"Activation wipe (g)",value:$tool.wipeGramsPerActivation)
                    DecimalField(title:"Additional active heater watts",value:$tool.additionalHeaterWatts)
                    DecimalField(title:"Additional parked heater watts",value:$tool.parkedHeaterWatts)
                    DecimalField(title:"Tool maintenance / active hour",value:$tool.maintenancePerHour)
                    DecimalField(title:"Nozzle replacement cost",value:$tool.nozzleReplacementCost)
                    DecimalField(title:"Nozzle life (hours)",value:$tool.nozzleLifeHours)
                    DecimalField(title:"Abrasive wear multiplier",value:$tool.abrasiveWearMultiplier)
                    Toggle("Tool needs review",isOn:$tool.needsReview)
                }
            }
            if let issue = validationIssue { Text(issue).foregroundStyle(.orange) }
        }.onChange(of:system.architecture) { _, architecture in
            system.sharedNozzle = [.singleTool,.singleNozzleSwitcher,.mixingHotend].contains(architecture)
            if architecture == .singleTool || architecture == .singleNozzleSwitcher { system.resize(to:1) }
            if architecture == .idex { system.resize(to:2) }
            system.needsReview = true
        }
    }
    var validationIssue: String? { do { try system.validate(); return nil } catch { return error.localizedDescription } }
}
struct ToolAssignmentsEditor: View {
    @Binding var job: ToolJob
    let filaments: [FilamentProduct]
    var body: some View {
        SwiftUI.Section("Tool material assignments") {
            Text("\(job.system.architecture.rawValue) · \(job.system.availableToolheadCount) physical toolheads · \(job.system.feederSlotCount) feeder slots")
            Text("These rows replace the manual material totals. Print time excludes the change time calculated here. Enter initial activation plus subsequent changes for each material; include tower/startup waste as extra grams in a support row.").font(.caption).foregroundStyle(.secondary)
            ForEach($job.assignments) { $assignment in
                DisclosureGroup(assignment.materialName + " → Tool \(assignment.toolIndex)") {
                    Menu("Choose filament") { ForEach(filaments) { f in Button(f.name) { assignment.materialID = f.id; assignment.materialName = f.name; assignment.materialFamily = f.materialFamily; assignment.colorName = f.colorName; assignment.pricePerKG = f.pricePerKG } } }
                    TextField("Material name",text:$assignment.materialName)
                    TextField("Family",text:$assignment.materialFamily)
                    TextField("Color",text:$assignment.colorName)
                    Picker("Physical tool",selection:$assignment.toolIndex) { ForEach(job.system.toolheads) { t in Text(t.name).tag(t.index) } }
                    Picker("Feeder slot",selection:Binding(get:{assignment.feederSlot ?? 0},set:{assignment.feederSlot = $0 == 0 ? nil : $0})) { Text("External / direct").tag(0); if job.system.feederSlotCount > 0 { ForEach(1...job.system.feederSlotCount,id:\.self) { Text("Slot \($0) → Tool \(assignment.toolIndex)").tag($0) } } }
                    Picker("Role",selection:$assignment.role) { ForEach(MaterialRole.allCases,id:\.self) { Text($0.rawValue).tag($0) } }
                    DecimalField(title:"Material grams",value:$assignment.grams)
                    DecimalField(title:"Price per kg",value:$assignment.pricePerKG)
                    DecimalField(title:"Tool active hours",value:$assignment.activeHours)
                    TextField("Activation / reload count",value:$assignment.activationCount,format:.number)
                    Toggle("Abrasive",isOn:$assignment.abrasive)
                    Toggle("Flexible",isOn:$assignment.flexible)
                    Button("Remove assignment",role:.destructive) { job.assignments.removeAll {$0.id == assignment.id} }
                }
            }
            Button("Add material assignment") { job.assignments.append(ToolMaterialAssignment()) }
        }
    }
}
