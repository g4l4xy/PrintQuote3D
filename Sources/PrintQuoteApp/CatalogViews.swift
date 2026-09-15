import SwiftUI
import QuoteDomain
import QuoteData
import UniformTypeIdentifiers

struct SourcesView: View {
    @Bindable var state: AppState
    @State private var query = ""
    @State private var exporting=false
    @State private var showingLogs=false
    @State private var diagnostics=CatalogSupportDocument(data:Data())
    var body: some View {
        List {
            SwiftUI.Section("Offline catalogs") {
                Text("Open Filament Database: \(state.filamentCatalog?.products.count ?? 0) products, version \(state.filamentCatalog?.upstreamVersion ?? "unknown")")
                Text("OrcaSlicer: \(state.technicalCatalog?.profiles.count ?? 0) pinned technical profiles. No retail prices imported.")
                Text("Catalog → manufacturer TDS → process profiles → packaging → secondary cross-checks. Retail prices remain a separate stream. User overrides are preserved.").foregroundStyle(.secondary)
            }
            SwiftUI.Section("Filament pipeline diagnostics") {
                let c=state.filamentCounts
                Text("Source spool records: \(c.discovered) · Decoded: \(c.decoded) · Normalized: \(c.normalized)")
                Text("Rejected: \(c.rejected) · Inserted: \(c.inserted) · Updated: \(c.updated) · Duplicate IDs: \(c.duplicates)")
                Text("Indexed: \(c.stored) · Saved inventory: \(state.library.filaments.count)")
                Text(state.filamentStatus)
                if let failure=state.filamentFailure{Text(failure).foregroundStyle(.orange)}
                Text(state.printerStatus)
                Button("Refresh Printer Data"){state.refreshPrinters()}.disabled(state.printerLoading)
                if state.printerLoading{Button("Cancel printer refresh"){state.printerTask?.cancel()}}
                Button("Open Logs"){showingLogs=true}
                Button("Refresh Filament Data / Rebuild Search Index"){state.refreshFilaments()}.disabled(state.filamentLoading)
                if state.filamentLoading{Button("Cancel"){state.catalogTask?.cancel()}}
                Button("Create Support Bundle") {do {
                    let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
                    diagnostics=CatalogSupportDocument(data:try encoder.encode(CatalogDiagnosticReport(status:state.filamentStatus,failure:state.filamentFailure,displayedAfterFilters:state.filamentVisibleCount,counts:state.filamentCounts)));exporting=true
                }catch{state.error="Could not export catalog diagnostics: \(error.localizedDescription)"}}
                Text("The diagnostic bundle contains catalog counts and quarantine reasons, without customer quotes or inventory prices.").font(.caption)
                DisclosureGroup("Quarantine (\(c.quarantine.count) diagnostics)") {ForEach(Array(c.quarantine.prefix(200).enumerated()),id:\.offset){_,d in Text("\(d.sourceID): \(d.reason) · \(d.count) records").font(.caption)}}
            }
            SwiftUI.Section("Source directory") {
                ForEach((state.sourceCatalog?.sources ?? []).filter {query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)}) { source in
                    DisclosureGroup(source.name) {
                        Text(source.status).font(.caption).foregroundStyle(.secondary)
                        ForEach(source.urls,id:\.self) { link in if let url=URL(string:link) { Link(link,destination:url).font(.caption).lineLimit(2) } }
                        Text(source.notes).font(.caption).textSelection(.enabled)
                    }
                }
            }
        }.sheet(isPresented:$showingLogs){NavigationStack{ScrollView{VStack(alignment:.leading){Text(state.filamentStatus);Text(state.printerStatus);if let failure=state.filamentFailure{Text(failure)};ForEach(Array(state.filamentCounts.quarantine.prefix(200).enumerated()),id:\.offset){_,d in Text("\(d.sourceID): \(d.reason) · \(d.count)")}}.padding().textSelection(.enabled)}.navigationTitle("Local database log").toolbar{Button("Done"){showingLogs=false}}}.desktopSheet(width:680,height:560)}.fileExporter(isPresented:$exporting,document:diagnostics,contentType:.json,defaultFilename:"PrintQuote-V4-catalog-diagnostics"){result in if case .failure(let error)=result{state.error=error.localizedDescription}}.searchable(text:$query,prompt:"Find source or manufacturer").navigationTitle("Data & Pricing Sources")
    }
}
struct OrcaCatalogView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var pricePerKG: Decimal = 0
    @State private var query = ""
    var body: some View {
        VStack {
            HStack { Text("OrcaSlicer technical profiles").font(.title2.bold()); Spacer(); Button("Close") {dismiss()} }.padding()
            TextField("Search technical profiles", text: $query).textFieldStyle(.roundedBorder).padding(.horizontal)
            Form {
                DecimalField(title:"Price per kg for filament imports (user entered)",value:$pricePerKG)
                ForEach((state.technicalCatalog?.profiles ?? []).filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }) { p in
                    SwiftUI.Section(p.name) {
                        Text(p.kind + " · " + p.vendor)
                        if p.kind == "machine" { Text("Build: \(p.buildXMM?.formatted() ?? "?") × \(p.buildYMM?.formatted() ?? "?") × \(p.buildZMM?.formatted() ?? "?") mm") }
                        Text(p.reviewReasons.joined(separator:"\n")).font(.caption).foregroundStyle(.orange)
                        DisclosureGroup("Source and technical fields") {
                            Text(p.source.sourcePath).textSelection(.enabled)
                            Text("Commit: " + p.source.commitSHA).font(.caption).textSelection(.enabled)
                            ForEach(p.technicalValues.keys.sorted(),id:\.self) { k in LabeledContent(k,value:p.technicalValues[k]!.joined(separator:", ")) }
                        }
                        Button("Add to \(p.kind == "machine" ? "Printers" : "Materials")") { add(p) }.disabled(state.library.printers.contains {$0.id==p.id} || state.library.filaments.contains {$0.id==p.id} || (p.kind == "filament" && pricePerKG <= 0))
                    }
                }
            }.formStyle(.grouped)
        }.desktopSheet(width:800,height:680)
    }
    func add(_ p:NormalizedTechnicalProfile) {
        var source=SourceReference(); source.name="OrcaSlicer"; source.url=p.source.repositoryURL + "/blob/" + p.source.commitSHA + "/" + p.source.sourcePath; source.sourceType="slicerProfile"; source.retrievedAt=p.source.importedAt; source.notes=p.reviewReasons.joined(separator:"\n")
        if p.kind == "machine" {
            state.library.printers.append(p.makePrinterProfile())
            _ = state.persist()
        } else {
            var f=FilamentProduct(); f.id=p.id; f.manufacturer=p.vendor; f.productName=p.name; f.materialFamily=p.materialFamily ?? "Unknown"; f.pricePerKG=pricePerKG; f.source=source; f.externalProfile=p.source
            _ = state.saveMaterial(f)
        }
    }
}

private struct CatalogSupportDocument:FileDocument {
    static var readableContentTypes:[UTType]{[.json]}
    var data:Data
    init(data:Data){self.data=data}
    init(configuration:ReadConfiguration)throws{data=configuration.file.regularFileContents ?? Data()}
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper{FileWrapper(regularFileWithContents:data)}
}

private struct CatalogDiagnosticReport:Codable {var appVersion="0.5.0";var status:String;var failure:String?;var displayedAfterFilters:Int;var counts:FilamentImportCounts}
