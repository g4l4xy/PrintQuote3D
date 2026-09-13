import SwiftUI
import QuoteDomain

struct PrinterLibrary: View {
    @Bindable var state: AppState
    @State private var selection: UUID?
    @State private var showingCatalog = false
    var body: some View {
        HSplitView {
            List(state.library.printers,selection:$selection) { p in VStack(alignment:.leading) { Text(p.name).font(.headline); Text(p.multiMaterialSystem).font(.caption).foregroundStyle(.secondary) }.padding(5).tag(p.id) }.frame(minWidth:220,idealWidth:280,maxWidth:340)
            if let index = state.library.printers.firstIndex(where: {$0.id == selection}) {
                Form {
                    TextField("Manufacturer",text:$state.library.printers[index].manufacturer)
                    TextField("Model",text:$state.library.printers[index].model)
                    TextField("Build X (mm)",value:$state.library.printers[index].buildVolumeXMM,format:.number)
                    TextField("Build Y (mm)",value:$state.library.printers[index].buildVolumeYMM,format:.number)
                    TextField("Build Z (mm)",value:$state.library.printers[index].buildVolumeZMM,format:.number)
                    DecimalField(title:"Average watts",value:$state.library.printers[index].typicalPowerWatts)
                    DecimalField(title:"Machine rate / hour",value:$state.library.printers[index].machineRate)
                    DecimalField(title:"Maintenance / hour",value:$state.library.printers[index].maintenanceRate)
                    TextField("Multi-material system",text:$state.library.printers[index].multiMaterialSystem)
                    Text(state.library.printers[index].source.notes).font(.caption).foregroundStyle(.secondary)
                    PrinterHardwareEditor(hardware: Binding(get: {state.library.printers[index].hardware ?? PrinterHardwareDetails()},set:{state.library.printers[index].hardware=$0}))
                    ToolSystemEditor(system: Binding(get: { state.library.printers[index].toolSystem ?? PrinterToolSystem() }, set: { state.library.printers[index].toolSystem = $0 }))
                    Button("Save printer") { state.library.printers[index].externalProfile?.userOverride = true; state.persist() }.buttonStyle(.borderedProminent)
                }.formStyle(.grouped)
            } else { ContentUnavailableView("Select a printer",systemImage:"printer",description:Text("Add your equipment and set its operating costs.")) }
        }.navigationTitle("Printer Library").sheet(isPresented:$showingCatalog) { OrcaCatalogView(state:state) }.toolbar { Button("Orca profiles") { showingCatalog = true }; Button("Add printer",systemImage:"plus") { let p = PrinterProfile(); state.library.printers.append(p); selection = p.id } }
    }
}
struct FilamentLibrary: View {
    @Bindable var state: AppState
    @State private var selection: UUID?
    var body: some View {
        HSplitView {
            List(state.library.filaments,selection:$selection) { f in VStack(alignment:.leading) { Text(f.name).font(.headline); Text(f.materialFamily + " · " + money(f.pricePerKG) + "/kg").font(.caption).foregroundStyle(.secondary) }.padding(5).tag(f.id) }.frame(minWidth:220,idealWidth:280,maxWidth:340)
            if let index = state.library.filaments.firstIndex(where: {$0.id == selection}) {
                Form {
                    TextField("Manufacturer",text:$state.library.filaments[index].manufacturer)
                    TextField("Product",text:$state.library.filaments[index].productName)
                    TextField("Material family",text:$state.library.filaments[index].materialFamily)
                    TextField("Color",text:$state.library.filaments[index].colorName)
                    TextField("Diameter (mm)",value:$state.library.filaments[index].diameterMM,format:.number)
                    TextField("Spool weight (g)",value:$state.library.filaments[index].netWeightGrams,format:.number)
                    DecimalField(title:"Price per kg",value:$state.library.filaments[index].pricePerKG)
                    Text(state.library.filaments[index].source.notes).font(.caption).foregroundStyle(.secondary)
                    Button("Save filament") { state.library.filaments[index].externalProfile?.userOverride = true; state.library.filaments[index].catalogSnapshot?.userOverride = true; state.persist() }.buttonStyle(.borderedProminent)
                }.formStyle(.grouped)
            } else { ContentUnavailableView("Select a filament",systemImage:"circle.hexagongrid",description:Text("Maintain product-specific prices for your estimates.")) }
        }.navigationTitle("Filament Library").toolbar { Button("Add filament",systemImage:"plus") { let f = FilamentProduct(); state.library.filaments.append(f); selection = f.id } }
    }
}
struct PresetsView: View {
    @Bindable var state: AppState
    var body: some View {
        Form {
            ForEach($state.library.presets) { $p in
                SwiftUI.Section(p.name) {
                    TextField("Name",text:$p.name)
                    Picker("Method",selection:$p.mode) { Text("Target margin").tag(PricingMode.margin); Text("Markup").tag(PricingMode.markup) }
                    DecimalField(title:"Rate (0.40 = 40%)",value:$p.rate)
                    DecimalField(title:"Material multiplier",value:$p.materialMultiplier)
                    DecimalField(title:"Machine / hour",value:$p.machineRate)
                    DecimalField(title:"Labor / hour",value:$p.laborRate)
                    DecimalField(title:"Minimum",value:$p.minimumCharge)
                    DecimalField(title:"Rush multiplier",value:$p.rushMultiplier)
                    HStack {
                        Button("Duplicate") { var copy = p; copy.id = UUID(); copy.name += " copy"; state.library.presets.append(copy); state.persist() }
                        Button("Delete",role:.destructive) { state.library.presets.removeAll {$0.id == p.id}; state.persist() }
                    }
                }
            }
            Button("Save presets") { state.persist() }.buttonStyle(.borderedProminent)
        }.formStyle(.grouped).navigationTitle("Pricing Presets")
    }
}
struct SettingsView: View {
    @Bindable var state: AppState
    var body: some View {
        Form {
            SwiftUI.Section("Business") {
                TextField("Business name",text:$state.library.settings.businessName)
                Picker("Currency",selection:$state.library.settings.currency) { ForEach(["USD","CAD","EUR","GBP","AUD"],id:\.self) { Text($0).tag($0) } }
                DecimalField(title:"Default tax rate (0.08 = 8%)",value:$state.library.settings.taxRate)
                Stepper("Quote validity: \(state.library.settings.expirationDays) days",value:$state.library.settings.expirationDays,in:1...365)
            }
            SwiftUI.Section("Electricity") { DecimalField(title:"Default cost per kWh",value:$state.library.settings.electricityRate) }
            Text("Defaults apply to new quotes. Saved quotes retain their original rates, equipment and material snapshots.").foregroundStyle(.secondary)
            Button("Save settings") { state.persist() }.buttonStyle(.borderedProminent)
        }.formStyle(.grouped).navigationTitle("Settings")
    }
}
