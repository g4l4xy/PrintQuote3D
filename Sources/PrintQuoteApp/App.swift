import SwiftUI
import QuoteDomain
import QuoteData

@main struct QuoteApp: App {
    @State private var state = AppState()
    @AppStorage("pq.appearance") private var appearance="System"
    var body: some Scene {
        WindowGroup {
            RootView(state: state).desktopWindowMinimum()
                .preferredColorScheme(appearance == "System" ? nil : appearance == "Dark" ? .dark:.light).pqWorkspace()
                .alert("Unable to complete action", isPresented: Binding(get: {state.error != nil}, set: {if !$0 {state.error = nil}})) {
                    Button("OK") { state.error = nil }
                } message: { Text(state.error ?? "") }
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        .commands {
            CommandGroup(replacing:.newItem){Button("New Quote"){state.navigationRequest="New Estimate"}.keyboardShortcut("n")}
            CommandMenu("Navigate") {
                Button("Command Palette"){state.commandRequested=true}.keyboardShortcut("k")
                Button("Search this screen"){NotificationCenter.default.post(name:.pqFocusSearch,object:nil)}.keyboardShortcut("f")
                Button("Import STL / 3MF"){state.navigationRequest="Import"}.keyboardShortcut("o")
                Button("Refresh local filament data"){state.refreshFilaments()}
            }
        }
        #endif
    }
}
enum Section: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard", quotes = "Quotes", estimate = "New Estimate", customers = "Customers", jobs = "Jobs", inventory = "Inventory", materials = "Materials", printers = "Printers", presets = "Presets", analytics = "Analytics", settings = "Settings", sources = "Pricing Sources"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .quotes: "doc.text"
        case .estimate: "plus.circle"
        case .customers: "person.2"
        case .jobs: "tray.full"
        case .inventory: "shippingbox"
        case .materials: "circle.hexagongrid"
        case .printers: "printer"
        case .presets: "slider.horizontal.3"
        case .analytics: "chart.bar"
        case .settings: "gearshape"
        case .sources: "link"
        }
    }
}
struct RootView: View {
    @Bindable var state: AppState
    @State private var selection: Section? = .dashboard
    @State private var editingQuote: Quote?
    @State private var draftID = UUID()
    @State private var inspectingModel = false
    @State private var quoteSearch = ""
    @FocusState private var quoteSearchFocused: Bool
    @State private var compactColumn: NavigationSplitViewColumn = .detail
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            VStack(alignment:.leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        BrandIcon().frame(width: 32, height: 36).fixedSize()
                        Text("PrintQuote 3D").font(.headline).lineLimit(1).minimumScaleFactor(0.8).layoutPriority(1)
                    }
                    Text("Real parts. Real prices. Faster.").font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16).padding(.top, 12)
                List(selection:$selection) {
                    SwiftUI.Section("Workspace"){ForEach([Section.dashboard,.quotes,.estimate,.customers,.jobs]){item in NavigationLink(value:item){Label(item.rawValue,systemImage:item.icon)}}}
                    SwiftUI.Section("Library"){ForEach([Section.inventory,.materials,.printers,.presets]){item in NavigationLink(value:item){Label(item.rawValue,systemImage:item.icon)}}}
                    SwiftUI.Section("Utility"){ForEach([Section.analytics,.sources,.settings]){item in NavigationLink(value:item){Label(item.rawValue,systemImage:item.icon)}}}
                }.navigationTitle("PrintQuote 3D")
                Text("LOCAL WORKSPACE  ·  V4").font(.caption2).foregroundStyle(.secondary).padding()
            }.navigationSplitViewColumnWidth(min:210, ideal:230)
        } detail: {
            // Keep a destination's ideal content size from expanding the split view
            // beyond the current window when the sidebar selection changes.
            GeometryReader { geometry in
            Group {
                switch selection ?? .dashboard {
                case .dashboard: dashboard
                case .quotes: quotes
                case .estimate: QuoteEditor(state:state, initial:nil).id(draftID)
                case .printers: PrinterLibrary(state:state)
                case .materials: MaterialsView(state:state)
                case .presets: PresetsView(state:state)
                case .settings: SettingsView(state:state)
                case .customers: List { ForEach(Array(Set(state.library.quotes.map(\.customer))).filter{ !$0.isEmpty }.sorted(), id:\.self) { customer in Text(customer).contextMenu{Button("Favorite"){state.favorite("customers",customer)};Button("Mark recently used"){state.used("customers",customer)};Button("Duplicate latest job setup"){if var q=state.library.quotes.first(where:{$0.customer==customer}){q.id=UUID();q.number="PQ-"+String(UUID().uuidString.prefix(8));q.status="draft";q.createdAt=Date();q.expiresAt=Date().addingTimeInterval(Double(state.library.settings.expirationDays)*86400);state.quickQuote=q}}} } }.navigationTitle("Customers")
                case .sources: SourcesView(state:state)
                default: ContentUnavailableView((selection ?? .jobs).rawValue, systemImage:(selection ?? .jobs).icon, description:Text("Planned for a later milestone. Start with an estimate to build your quote library."))
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
                .disabled(!state.ready)
            }
        }
        .pqWorkspace()
        .toolbar {
            ToolbarItem {Button("Search / Commands",systemImage:"magnifyingglass"){state.commandRequested=true}}
            #if os(iOS)
            if sizeClass == .compact {ToolbarItemGroup(placement:.bottomBar){
                Button("Dashboard",systemImage:"square.grid.2x2"){selection = .dashboard}
                Spacer()
                Button("Quotes",systemImage:"doc.text"){selection = .quotes}
                Spacer()
                Button("Materials",systemImage:"circle.hexagongrid"){selection = .materials}
                Spacer()
                Menu("More",systemImage:"ellipsis.circle"){ForEach(Section.allCases){item in Button(item.rawValue,systemImage:item.icon){selection=item}}}
            }}
            #endif
        }
        .overlay(alignment:.bottom){if let toast=state.toast{Text(toast).padding(PQSpacing.md).background(.regularMaterial,in:Capsule()).padding()}}
        .task(id:state.toast){if state.toast != nil{do{try await Task.sleep(for:.seconds(3));state.toast=nil}catch{}}}
        .sheet(isPresented:$state.commandRequested){V4CommandPalette(state:state){kind,id in
            state.commandRequested=false
            switch kind {
            case "quote":editingQuote=state.library.quotes.first{$0.id.uuidString==id};state.used("quotes",id)
            case "printer":state.requestedPrinter=UUID(uuidString:id);selection = .printers;state.used("printers",id)
            case "filament":state.filamentQuery=FilamentQuery();state.filamentQuery.text=id;selection = .materials
            case "New Estimate":draftID=UUID();selection = .estimate
            case "refresh":state.refreshFilaments()
            case "Import":inspectingModel=true
            default:selection=Section(rawValue:kind) ?? .dashboard
            }
        }}
        .onChange(of:state.navigationRequest){_,request in if request=="Import"{inspectingModel=true}else if let request{selection=Section(rawValue:request);if selection == .estimate{draftID=UUID()}};state.navigationRequest=nil}
        .onChange(of: selection) { _, _ in compactColumn = .detail }
        .sheet(isPresented: $inspectingModel) { ModelInspectionView(state: state) }
        .sheet(item:$state.quickQuote){q in QuoteEditor(state:state,initial:q).desktopSheet(width:1050,height:760)}
        .sheet(item:$editingQuote) { q in QuoteEditor(state:state, initial:q).desktopSheet(width:1050,height:760) }
    }
    var dashboard: some View {
        ScrollView {
            VStack(alignment:.leading, spacing:PQSpacing.section) {
                Text("Your workshop, in focus.").font(PQTypography.display)
                Text("Build a clear estimate from material, machine time and labor.").foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing:16) {
                    metric("Saved quotes", "\(state.library.quotes.count)", "doc.text")
                    metric("Printer profiles", "\(state.library.printers.count)", "printer")
                    metric("Catalog spool options", "\(state.filamentCounts.stored.formatted())", "circle.hexagongrid")
                }
                ViewThatFits(in:.horizontal){
                    HStack(spacing:PQSpacing.md){dashboardActions}
                    VStack(alignment:.leading,spacing:PQSpacing.md){dashboardActions}
                }.padding(PQSpacing.lg).pqGlass(.toolbar)
                if !state.recoveredDrafts.isEmpty {
                    GroupBox("Recovered drafts found") {
                        ForEach(state.recoveredDrafts){draft in
                            HStack {
                                Text(draft.projectName)
                                Button("Restore"){editingQuote=draft;state.recoveredDrafts.removeAll{$0.id==draft.id}}
                                Button("Discard",role:.destructive){Task{do{try await state.recovery.discard(draft.id);state.recoveredDrafts.removeAll{$0.id==draft.id}}catch{state.error=error.localizedDescription}}}
                            }
                        }
                    }
                }

                GroupBox("Workshop activity") {
                    VStack(alignment:.leading){Text("Printer status: local profiles available; live printer monitoring is not connected.");Text("Material alerts: \(state.library.filaments.filter{($0.stock?.remainingGrams ?? 1000)<100}.count) saved spools below 100 g");Text("Active jobs: no job tracker connected");Text("Recent customers: \(Array(Set(state.library.quotes.prefix(10).map(\.customer))).filter{!$0.isEmpty}.prefix(5).joined(separator:", "))")}.frame(maxWidth:.infinity,alignment:.leading)
                }
                Text("Recent quotes").font(.title2.bold())
                if state.library.quotes.isEmpty { Text("Your first saved quote will appear here.").foregroundStyle(.secondary) }
                ForEach(state.library.quotes.prefix(5)) { q in Button { editingQuote = q;state.used("quotes",q.id.uuidString);state.used("customers",q.customer) } label: { HStack { Text(q.number); Text(q.projectName); Spacer(); Text(money(q.result?.total ?? 0, currency:q.currency)) }.padding(10) }.buttonStyle(.plain) }
                Text("Seed profiles are examples. Review your actual costs before issuing a quote.").font(.caption).foregroundStyle(.secondary)
            }.padding(PQSpacing.section)
        }.navigationTitle("Dashboard")
    }
    @ViewBuilder var dashboardActions:some View {
        Button("Create estimate",systemImage:"plus"){draftID=UUID();selection = .estimate}.buttonStyle(.borderedProminent)
        Button("Inspect STL / 3MF",systemImage:"cube.transparent"){inspectingModel=true}.buttonStyle(.bordered)
        Button("Browse materials",systemImage:"circle.hexagongrid"){selection = .materials}.buttonStyle(.bordered)
    }
    func metric(_ title:String, _ value:String, _ icon:String)->some View {PQMetric(title:title,value:value,icon:icon)}
    var quotes: some View {
        VStack(spacing:PQSpacing.md) {
        TextField("Search quotes, customers or status",text:$quoteSearch).textFieldStyle(.roundedBorder).focused($quoteSearchFocused).onReceive(NotificationCenter.default.publisher(for:.pqFocusSearch)){_ in quoteSearchFocused=true}.padding(PQSpacing.md).pqGlass().padding(.horizontal)
        List {
            if state.library.quotes.isEmpty { Text("No saved quotes yet. Create a new estimate to get started.") }
            ForEach(state.library.quotes.filter{quoteSearch.isEmpty || ($0.projectName+" "+$0.customer+" "+$0.number+" "+$0.status).localizedCaseInsensitiveContains(quoteSearch)}) { q in
                Button { editingQuote = q;state.used("quotes",q.id.uuidString);state.used("customers",q.customer) } label: { HStack { VStack(alignment:.leading) { Text(q.number + " · " + q.projectName).font(.headline); Text(q.customer.isEmpty ? "No customer" : q.customer).foregroundStyle(.secondary) }; Spacer(); Text(q.status.capitalized); Text(money(q.result?.total ?? 0,currency:q.currency)).bold() }.padding(6).contentShape(Rectangle()) }.buttonStyle(.plain)
                .contextMenu {
                    Button("Duplicate"){var copy=q;copy.id=UUID();copy.number="PQ-"+String(UUID().uuidString.prefix(8));copy.projectName+=" copy";copy.status="draft";copy.createdAt=Date();copy.expiresAt=Date().addingTimeInterval(Double(state.library.settings.expirationDays)*86400);editingQuote=copy}
                    Button(state.v4Favorites.contains("quotes:"+q.id.uuidString) ? "Remove favorite":"Favorite"){state.favorite("quotes",q.id.uuidString)}
                }
            }
        }}.navigationTitle("Quotes")
    }
}
struct DecimalField: View {
    let title: String
    @Binding var value: Decimal
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title,value:$value,format:.number).textFieldStyle(.roundedBorder).help(PQTechnicalHelp.explanation(title))
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }
}

struct BrandIcon: View {
    var body: some View {
        #if SWIFT_PACKAGE && os(macOS)
        // Plain SwiftPM PNG resources are not asset-catalog named images.
        // Prefer the packaged resource so a copied .app works away from its build directory.
        let packaged = Bundle.main.resourceURL?.appendingPathComponent("PrintQuote3D_PrintQuoteApp.bundle/BrandIcon.png")
        if let image = packaged.flatMap({ NSImage(contentsOf: $0) })
            ?? Bundle.module.url(forResource: "BrandIcon", withExtension: "png").flatMap({ NSImage(contentsOf: $0) }) {
            Image(nsImage: image).resizable().scaledToFit().accessibilityHidden(true)
        }
        #elseif SWIFT_PACKAGE
        Image("BrandIcon", bundle: .module).resizable().scaledToFit().accessibilityHidden(true)
        #else
        Image("BrandIcon").resizable().scaledToFit().accessibilityHidden(true)
        #endif
    }
}

private struct V4CommandResult:Identifiable,Sendable {var id:String;var title:String;var kind:String;var target:String}
private struct V4CommandPalette:View {
    let state:AppState
    let choose:(String,String)->Void
    @State private var query=""
    @State private var results:[V4CommandResult]=[]
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        NavigationStack {
            VStack {
                TextField("Search quotes, customers, printers, filaments, presets or commands",text:$query).textFieldStyle(.roundedBorder).padding()
                List(results){r in Button{choose(r.kind,r.target)}label:{VStack(alignment:.leading){Text(r.title);Text(r.kind).font(.caption).foregroundStyle(.secondary)}}}
            }.navigationTitle("Search & Commands").toolbar{Button("Close"){dismiss()}}
            .task(id:query){await search()}
        }.desktopSheet(width:760,height:600)
    }
    private func search() async {
        do {
            try await Task.sleep(for:.milliseconds(200));let text=query;let library=state.library
            var found=await Task.detached { ()->[V4CommandResult] in
                var rows=[V4CommandResult]()
                for (title,kind) in [("New Quote","New Estimate"),("Quick Quote","New Estimate"),("Import STL / 3MF","Import"),("Add / Search Printers","Printers"),("Add / Search Filaments","Materials"),("Settings","Settings"),("Refresh Data","refresh"),("Jobs","Jobs")] where text.isEmpty || title.localizedCaseInsensitiveContains(text){rows.append(.init(id:kind+title,title:title,kind:kind,target:""))}
                rows += library.quotes.filter{text.isEmpty || ($0.projectName+" "+$0.customer+" "+$0.number).localizedCaseInsensitiveContains(text)}.prefix(10).map{.init(id:$0.id.uuidString,title:$0.projectName,kind:"quote",target:$0.id.uuidString)}
                if !text.isEmpty {
                    rows += library.printers.filter{$0.name.localizedCaseInsensitiveContains(text)}.prefix(15).map{.init(id:$0.id.uuidString,title:$0.name,kind:"printer",target:$0.id.uuidString)}
                    rows += library.presets.filter{$0.name.localizedCaseInsensitiveContains(text)}.prefix(10).map{.init(id:$0.id.uuidString,title:$0.name,kind:"Presets",target:$0.id.uuidString)}
                    rows += Array(Set(library.quotes.map(\.customer))).filter{!$0.isEmpty && $0.localizedCaseInsensitiveContains(text)}.prefix(10).map{.init(id:"customer:"+$0,title:$0,kind:"Customers",target:$0)}
                };return rows
            }.value
            if !query.isEmpty,let repo=state.filamentRepository {var q=FilamentQuery();q.text=query;q.limit=15;let page=try await repo.search(q);found += page.rows.map{.init(id:$0.id,title:$0.brand+" "+$0.name+" · "+$0.color,kind:"filament",target:query)}}
            try Task.checkCancellation();results=found
        }catch is CancellationError{}catch{results=[.init(id:"failure",title:error.localizedDescription,kind:"Pricing Sources",target:"")]}
    }
}
