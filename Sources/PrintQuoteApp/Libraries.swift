import SwiftUI
import QuoteDomain

struct PrinterLibrary: View {
    @Bindable var state: AppState
    @State private var selection: UUID?
    @State private var showingCatalog = false
    @State private var search = ""
    private var filteredPrinters: [PrinterProfile] {
        state.library.printers.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var body: some View {
        AdaptiveLibrary(selection: $selection, backTitle: "All printers") {
            VStack(alignment: .leading) {
                TextField("Search manufacturer, model or nozzle", text: $search).textFieldStyle(.roundedBorder).padding([.horizontal, .top])
                Text("\(filteredPrinters.count) of \(state.library.printers.count) printer profiles").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            List(filteredPrinters) { p in Button { selection = p.id } label: { VStack(alignment:.leading) { Text(p.name).font(.headline); Text(p.multiMaterialSystem).font(.caption).foregroundStyle(.secondary) }.padding(5).frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle()) }.buttonStyle(.plain) }
            }
        } detail: {
            if let index = state.library.printers.firstIndex(where: {$0.id == selection}) {
                Form {
                    if let source = state.library.printers[index].externalProfile {
                        Text(source.userOverride ? "Your configuration" : "Imported profile · review tool setup and enter operating costs").font(.caption).foregroundStyle(.secondary)
                    }
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
