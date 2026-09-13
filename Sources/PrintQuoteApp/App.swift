import SwiftUI
import QuoteDomain

@main struct QuoteApp: App {
    @State private var state = AppState()
    var body: some Scene {
        WindowGroup {
            RootView(state: state).frame(minWidth: 1000, minHeight: 680)
                .preferredColorScheme(.dark).tint(.blue)
                .alert("Unable to complete action", isPresented: Binding(get: {state.error != nil}, set: {if !$0 {state.error = nil}})) {
                    Button("OK") { state.error = nil }
                } message: { Text(state.error ?? "") }
        }.defaultSize(width: 1100, height: 760)
    }
}
enum Section: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard", quotes = "Quotes", estimate = "New Estimate", customers = "Customers", jobs = "Jobs", inventory = "Inventory", filaments = "Filaments", printers = "Printers", presets = "Presets", analytics = "Analytics", settings = "Settings", materials = "Material Database", sources = "Pricing Sources"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .quotes: "doc.text"
        case .estimate: "plus.circle"
        case .customers: "person.2"
        case .jobs: "tray.full"
        case .inventory: "shippingbox"
        case .filaments: "circle.hexagongrid"
        case .printers: "printer"
        case .presets: "slider.horizontal.3"
        case .analytics: "chart.bar"
        case .settings: "gearshape"
        case .materials: "square.stack.3d.up"
        case .sources: "link"
        }
    }
}
struct RootView: View {
    @Bindable var state: AppState
    @State private var selection: Section? = .dashboard
    @State private var editingQuote: Quote?
    @State private var draftID = UUID()
    var body: some View {
        NavigationSplitView {
            VStack(alignment:.leading, spacing: 20) {
                VStack(alignment:.leading) { Text("PRINTQUOTE 3D").font(.headline); Text("Upload. Configure. Price. Quote.").font(.caption).foregroundStyle(.secondary) }.padding(.horizontal).padding(.top)
                List(Section.allCases, selection: $selection) { item in Label(item.rawValue, systemImage:item.icon).tag(item) }
                Text("LOCAL WORKSPACE  ·  V1").font(.caption2).foregroundStyle(.secondary).padding()
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
                case .filaments: FilamentLibrary(state:state)
                case .presets: PresetsView(state:state)
                case .settings: SettingsView(state:state)
                case .customers: List { ForEach(Array(Set(state.library.quotes.map(\.customer))).filter{ !$0.isEmpty }.sorted(), id:\.self) { Text($0) } }.navigationTitle("Customers")
                case .materials: List(state.library.filaments) { f in VStack(alignment:.leading) { Text(f.materialFamily).font(.headline); Text("Product-specific guidance and compatibility will be added with verified sources.").foregroundStyle(.secondary) } }.navigationTitle("Material Database")
                case .sources: List { Text("All bundled profiles are illustrative local data. Prices and hardware specifications are editable."); Text("SimplyPrint support is recorded separately and currently unknown. No material or job compatibility is inferred.") }.navigationTitle("Pricing Sources")
                default: ContentUnavailableView((selection ?? .jobs).rawValue, systemImage:(selection ?? .jobs).icon, description:Text("Planned for a later milestone. Start with an estimate to build your quote library."))
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
                .disabled(!state.ready)
            }
        }
        .sheet(item:$editingQuote) { q in QuoteEditor(state:state, initial:q).frame(width:1050,height:760) }
    }
    var dashboard: some View {
        ScrollView {
            VStack(alignment:.leading, spacing:24) {
                Text("Your workshop, in focus.").font(.largeTitle.bold())
                Text("Build a clear estimate from material, machine time and labor.").foregroundStyle(.secondary)
                HStack(spacing:16) {
                    metric("Saved quotes", "\(state.library.quotes.count)", "doc.text")
                    metric("Printer profiles", "\(state.library.printers.count)", "printer")
                    metric("Filament products", "\(state.library.filaments.count)", "circle.hexagongrid")
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
    var body: some View { TextField(title,value:$value,format:.number).textFieldStyle(.roundedBorder) }
}
