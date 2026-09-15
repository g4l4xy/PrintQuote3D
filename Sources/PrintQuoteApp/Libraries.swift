import SwiftUI
import QuoteDomain

struct PrinterLibrary: View {
    @Bindable var state: AppState
    @FocusState private var searchFocused:Bool
    @State private var selection: UUID?
    @State private var showingCatalog = false
    @State private var search = ""
    @AppStorage("v4.printers.layout") private var layout=PQLayout.defaultLibraryLayout
    @AppStorage("v4.printers.sort") private var sort="Favorite"
    private var filteredPrinters: [PrinterProfile] {
        state.library.printers.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted {
                switch sort {
                case "Favorite":let a=state.v4Favorites.contains("printers:"+$0.id.uuidString);let b=state.v4Favorites.contains("printers:"+$1.id.uuidString);if a != b{return a}
                case "Recently Used":let a=state.v4Recent["printers:"+$0.id.uuidString] ?? 0;let b=state.v4Recent["printers:"+$1.id.uuidString] ?? 0;if a != b{return a>b}
                case "Build Volume":let a=$0.buildVolumeXMM*$0.buildVolumeYMM*$0.buildVolumeZMM;let b=$1.buildVolumeXMM*$1.buildVolumeYMM*$1.buildVolumeZMM;if a != b{return a>b}
                case "Toolheads":let a=$0.toolSystem?.availableToolheadCount ?? 1;let b=$1.toolSystem?.availableToolheadCount ?? 1;if a != b{return a>b}
                default:break
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }
    var body: some View {
        AdaptiveLibrary(selection: $selection, backTitle: "All printers") {
            VStack(alignment: .leading) {
                TextField("Search manufacturer, model or nozzle", text: $search).textFieldStyle(.roundedBorder).focused($searchFocused).onReceive(NotificationCenter.default.publisher(for:.pqFocusSearch)){_ in searchFocused=true}.padding(PQSpacing.md).pqGlass().padding(.horizontal)
                Text("\(filteredPrinters.count) of \(state.library.printers.count) printer profiles").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                Picker("Sort",selection:$sort){ForEach(["Name","Manufacturer","Build Volume","Toolheads","Recently Used","Favorite"],id:\.self){Text($0)}}.padding(.horizontal)
                Picker("Layout",selection:$layout){Text("Cards").tag("Cards");Text("Table").tag("Table")}.pickerStyle(.segmented).padding(.horizontal)
                if layout=="Table" {
                    ComparisonBrowser(key:"v4.printers.table",columns:["Name","Manufacturer","Build volume","Toolheads","Favorite"],records:filteredPrinters.map{p in ComparisonRecord(id:p.id.uuidString,values:["Name":p.model,"Manufacturer":p.manufacturer,"Build volume":"\(p.buildVolumeXMM) × \(p.buildVolumeYMM) × \(p.buildVolumeZMM) mm","Toolheads":"\(p.toolSystem?.availableToolheadCount ?? 1)","Favorite":state.v4Favorites.contains("printers:"+p.id.uuidString) ? "★":""])},open:{selection=UUID(uuidString:$0)})
                } else {List(filteredPrinters) { p in Button { selection = p.id;state.used("printers",p.id.uuidString) } label: { VStack(alignment:.leading) { Text(p.name).font(.headline); Text(p.multiMaterialSystem).font(.caption).foregroundStyle(.secondary) }.padding(5).frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle()) }.buttonStyle(.plain).contextMenu{Button("New Quote"){state.startQuote(printer:p)};Button("Maintenance settings"){selection=p.id};Button("Favorite"){state.favorite("printers",p.id.uuidString)};Button("Duplicate Config"){var copy=p;copy.id=UUID();copy.model+=" copy";state.library.printers.append(copy);state.persist();selection=copy.id}} }
            }
            }
        } detail: {
            if let index = state.library.printers.firstIndex(where: {$0.id == selection}) {
                Form {
                    PQSectionHeader(title:state.library.printers[index].name,subtitle:"Printer configuration · your operating costs")
                    SwiftUI.Section("Overview") {
                    if let source = state.library.printers[index].externalProfile {
                        Text(source.userOverride ? "Your configuration" : "Imported profile · review tool setup and enter operating costs").font(.caption).foregroundStyle(.secondary)
                    }
                    TextField("Manufacturer",text:$state.library.printers[index].manufacturer)
                    TextField("Model",text:$state.library.printers[index].model)
                    TextField("Build X (mm)",value:$state.library.printers[index].buildVolumeXMM,format:.number)
                    TextField("Build Y (mm)",value:$state.library.printers[index].buildVolumeYMM,format:.number)
                    TextField("Build Z (mm)",value:$state.library.printers[index].buildVolumeZMM,format:.number)
                    }
                    DisclosureGroup("Advanced · operating costs & capabilities") {
                    DecimalField(title:"Average watts",value:$state.library.printers[index].typicalPowerWatts)
                    DecimalField(title:"Machine rate / hour",value:$state.library.printers[index].machineRate)
                    DecimalField(title:"Maintenance / hour",value:$state.library.printers[index].maintenanceRate)
                    TextField("Multi-material system",text:$state.library.printers[index].multiMaterialSystem)
                    Text(state.library.printers[index].source.notes).font(.caption).foregroundStyle(.secondary)
                    PrinterHardwareEditor(hardware: Binding(get: {state.library.printers[index].hardware ?? PrinterHardwareDetails()},set:{state.library.printers[index].hardware=$0}))
                    ToolSystemEditor(system: Binding(get: { state.library.printers[index].toolSystem ?? PrinterToolSystem() }, set: { state.library.printers[index].toolSystem = $0 }))
                    }
                    Button("Save printer") { state.library.printers[index].externalProfile?.userOverride = true; state.persist() }.buttonStyle(.borderedProminent)
                }.formStyle(.grouped)
            } else { ContentUnavailableView("Select a printer",systemImage:"printer",description:Text("Add your equipment and set its operating costs.")) }
        }.onAppear{if let id=state.requestedPrinter{selection=id;state.requestedPrinter=nil}}.navigationTitle("Printer Library").sheet(isPresented:$showingCatalog) { OrcaCatalogView(state:state) }.toolbar { Button("Orca profiles") { showingCatalog = true }; Button("Add printer",systemImage:"plus") { let p = PrinterProfile(); state.library.printers.append(p); selection = p.id } }
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
                        Button(state.v4Favorites.contains("presets:"+p.id.uuidString) ? "★ Favorite" : "☆ Favorite"){state.favorite("presets",p.id.uuidString)}
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
    @State private var search=""
    var body: some View {
        Form {
            if search.isEmpty || "appearance theme light dark accessibility effects".localizedCaseInsensitiveContains(search){PQAppearanceSettings()}
            if search.isEmpty || "business name currency tax quote validity".localizedCaseInsensitiveContains(search) {SwiftUI.Section("Business") {
                TextField("Business name",text:$state.library.settings.businessName)
                Picker("Currency",selection:$state.library.settings.currency) { ForEach(["USD","CAD","EUR","GBP","AUD"],id:\.self) { Text($0).tag($0) } }
                DecimalField(title:"Default tax rate (0.08 = 8%)",value:$state.library.settings.taxRate)
                Stepper("Quote validity: \(state.library.settings.expirationDays) days",value:$state.library.settings.expirationDays,in:1...365)
            }
            }
            if search.isEmpty || "electricity energy cost".localizedCaseInsensitiveContains(search) {SwiftUI.Section("Electricity") { DecimalField(title:"Default cost per kWh",value:$state.library.settings.electricityRate) }}
            Text("Defaults apply to new quotes. Saved quotes retain their original rates, equipment and material snapshots.").foregroundStyle(.secondary)
            Button("Save settings") { state.persist() }.buttonStyle(.borderedProminent)
            SwiftUI.Section("About PrintQuote V4") {Text("Workspace schema: \(state.library.schemaVersion)");Text("Filament database: \(state.filamentCatalog?.upstreamVersion ?? "loading")");Text("Printers: \(state.library.printers.count) · Products: \(state.filamentCounts.products) · Colors: \(state.filamentCounts.variants) · Spool options: \(state.filamentCounts.stored)");Button("Validate database / rebuild index"){state.refreshFilaments()}}
        }.searchable(text:$search,prompt:"Search settings").formStyle(.grouped).navigationTitle("Settings")
    }
}

struct ComparisonRecord:Identifiable {
    let id:String
    let values:[String:String]
}
/// Bounded, horizontally scrollable comparison with user-owned column preferences.
struct ComparisonBrowser:View {
    let key:String
    let columns:[String]
    let records:[ComparisonRecord]
    let open:(String)->Void
    var edit:((String,String,String)->Bool)? = nil
    @State private var order:[String]=[]
    @State private var hidden:Set<String>=[]
    @State private var widths:[String:Double]=[:]
    @State private var customize=false
    private var ordered:[String]{order.isEmpty ? columns:order.filter{columns.contains($0)}+columns.filter{!order.contains($0)}}
    private var shown:[String]{ordered.filter{!hidden.contains($0)}}
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Button("Columns & layout"){customize=true}
            ScrollView(.horizontal) {
                VStack(spacing:0) {
                    HStack(spacing:0){ForEach(shown,id:\.self){column in Text(column).font(.caption.bold()).frame(width:width(column),alignment:.leading).padding(.horizontal,8)}}.padding(.vertical,8)
                    Divider()
                    ScrollView {
                        LazyVStack(spacing:0) {
                            ForEach(records){record in
                                HStack(spacing:0){ForEach(shown,id:\.self){column in
                                    if let edit, ["Price / kg","Stock (g)","Nickname","Notes"].contains(column) {
                                        ComparisonEditCell(value:record.values[column] ?? "",label:column){edit(record.id,column,$0)}.frame(width:width(column)).padding(.horizontal,8)
                                    } else {
                                        Text(record.values[column] ?? "Unknown").font(.callout).lineLimit(3).frame(width:width(column),alignment:.leading).padding(.horizontal,8).contentShape(Rectangle()).onTapGesture{open(record.id)}
                                    }
                                }}.padding(.vertical,10)
                                    .contextMenu{Button("Open"){open(record.id)}}
                                Divider()
                            }
                        }
                    }
                }.frame(width:shown.reduce(0){$0+width($1)+16})
            }
        }.onAppear {
            let defaults=UserDefaults.standard
            order=defaults.stringArray(forKey:key+".order") ?? columns
            hidden=Set(defaults.stringArray(forKey:key+".hidden") ?? [])
            widths=defaults.dictionary(forKey:key+".widths") as? [String:Double] ?? [:]
        }
        .sheet(isPresented:$customize){NavigationStack{Form {
            Text("Show or hide columns, move them left/right, and adjust each width. Layout is remembered on this device.").font(.caption)
            ForEach(ordered,id:\.self){column in
                SwiftUI.Section(column) {
                    Toggle("Show column",isOn:Binding(get:{!hidden.contains(column)},set:{enabled in if enabled{hidden.remove(column)}else if shown.count>1{hidden.insert(column)};persist()}))
                    Slider(value:Binding(get:{width(column)},set:{widths[column]=$0;persist()}),in:90...420){Text("Column width")}
                    Text("Width: \(Int(width(column))) points").font(.caption)
                    HStack{Button("Move left"){move(column,-1)};Button("Move right"){move(column,1)}}
                }
            }
            Button("Reset layout"){order=columns;hidden=[];widths=[:];persist()}
        }.navigationTitle("Comparison columns").toolbar{Button("Done"){customize=false}}}.desktopSheet(width:540,height:620)}
    }
    private func width(_ column:String)->Double{min(420,max(90,widths[column] ?? (column=="Name" ? 240:145)))}
    private func move(_ column:String,_ delta:Int){var values=ordered;guard let i=values.firstIndex(of:column),values.indices.contains(i+delta) else{return};values.swapAt(i,i+delta);order=values;persist()}
    private func persist(){let defaults=UserDefaults.standard;defaults.set(order,forKey:key+".order");defaults.set(Array(hidden),forKey:key+".hidden");defaults.set(widths,forKey:key+".widths")}
}
private struct ComparisonEditCell:View {
    let value:String
    let label:String
    let save:(String)->Bool
    @State private var text=""
    var body:some View{TextField(label,text:$text).textFieldStyle(.roundedBorder).onAppear{text=value}.onChange(of:value){_,value in text=value}.onSubmit{if !save(text){text=value}}.help("Press Return to save this field")}
}
