import SwiftUI
import QuoteDomain

@main struct QuoteApp: App {
    @State private var state = AppState()
    var body: some Scene {
        WindowGroup {
            RootView(state: state).desktopWindowMinimum()
                .preferredColorScheme(.dark).tint(.blue)
                .alert("Unable to complete action", isPresented: Binding(get: {state.error != nil}, set: {if !$0 {state.error = nil}})) {
                    Button("OK") { state.error = nil }
                } message: { Text(state.error ?? "") }
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
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
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            VStack(alignment:.leading, spacing: 20) {
                VStack(alignment:.leading) { HStack { BrandIcon().frame(width:44,height:44); Text("PrintQuote 3D").font(.headline) }; Text("Real parts. Real prices. Faster.").font(.caption).foregroundStyle(.secondary) }.padding(.horizontal).padding(.top)
                List(Section.allCases, selection: $selection) { item in NavigationLink(value: item) { Label(item.rawValue, systemImage:item.icon) } }.navigationTitle("PrintQuote 3D")
                Text("LOCAL WORKSPACE  ·  V2").font(.caption2).foregroundStyle(.secondary).padding()
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
                case .customers: List { ForEach(Array(Set(state.library.quotes.map(\.customer))).filter{ !$0.isEmpty }.sorted(), id:\.self) { Text($0) } }.navigationTitle("Customers")
                case .sources: SourcesView(state:state)
                default: ContentUnavailableView((selection ?? .jobs).rawValue, systemImage:(selection ?? .jobs).icon, description:Text("Planned for a later milestone. Start with an estimate to build your quote library."))
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
                .disabled(!state.ready)
            }
        }
        .onChange(of: selection) { _, _ in compactColumn = .detail }
        .sheet(item:$editingQuote) { q in QuoteEditor(state:state, initial:q).desktopSheet(width:1050,height:760) }
    }
    var dashboard: some View {
        ScrollView {
            VStack(alignment:.leading, spacing:24) {
                Text("Your workshop, in focus.").font(.largeTitle.bold())
                Text("Build a clear estimate from material, machine time and labor.").foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing:16) {
                    metric("Saved quotes", "\(state.library.quotes.count)", "doc.text")
                    metric("Printer profiles", "\(state.library.printers.count)", "printer")
                    metric("Saved materials", "\(state.library.filaments.count)", "circle.hexagongrid")
                }
                GroupBox {
                    VStack(alignment:.leading, spacing:14) {
                        Label("Start with the production cost", systemImage:"plus.circle.fill").font(.title2.bold())
                        Text("Enter print data manually, compare margin and markup, then save a complete pricing snapshot.")
                        Button("Create estimate") { draftID = UUID(); selection = .estimate }.buttonStyle(.borderedProminent)
                    }.frame(maxWidth:.infinity, alignment:.leading).padding(16)
                }
                Text("Recent quotes").font(.title2.bold())
                if state.library.quotes.isEmpty { Text("Your first saved quote will appear here.").foregroundStyle(.secondary) }
                ForEach(state.library.quotes.prefix(5)) { q in Button { editingQuote = q } label: { HStack { Text(q.number); Text(q.projectName); Spacer(); Text(money(q.result?.total ?? 0, currency:q.currency)) }.padding(10) }.buttonStyle(.plain) }
                Text("Seed profiles are examples. Review your actual costs before issuing a quote.").font(.caption).foregroundStyle(.secondary)
            }.padding(32)
        }.navigationTitle("Dashboard")
    }
    func metric(_ title:String, _ value:String, _ icon:String) -> some View {
        GroupBox { VStack(alignment:.leading, spacing:12) { Label(title,systemImage:icon).foregroundStyle(.secondary); Text(value).font(.system(size:34,weight:.semibold,design:.rounded)) }.frame(maxWidth:.infinity,alignment:.leading).padding(12) }
    }
    var quotes: some View {
        List {
            if state.library.quotes.isEmpty { Text("No saved quotes yet. Create a new estimate to get started.") }
            ForEach(state.library.quotes) { q in
                Button { editingQuote = q } label: { HStack { VStack(alignment:.leading) { Text(q.number + " · " + q.projectName).font(.headline); Text(q.customer.isEmpty ? "No customer" : q.customer).foregroundStyle(.secondary) }; Spacer(); Text(q.status.capitalized); Text(money(q.result?.total ?? 0,currency:q.currency)).bold() }.padding(6).contentShape(Rectangle()) }.buttonStyle(.plain)
            }
        }.navigationTitle("Quotes")
    }
}
struct DecimalField: View {
    let title: String
    @Binding var value: Decimal
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextField(title,value:$value,format:.number).textFieldStyle(.roundedBorder)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        }
    }
}

struct BrandIcon: View {
    var body: some View {
        #if SWIFT_PACKAGE
        Image("BrandIcon", bundle: .module).resizable().scaledToFit().accessibilityHidden(true)
        #else
        Image("BrandIcon").resizable().scaledToFit().accessibilityHidden(true)
        #endif
    }
}
