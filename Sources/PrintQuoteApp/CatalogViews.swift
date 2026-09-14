import SwiftUI
import QuoteDomain

struct SourcesView: View {
    @Bindable var state: AppState
    @State private var query = ""
    var body: some View {
        List {
            SwiftUI.Section("Offline catalogs") {
                Text("Open Filament Database: \(state.filamentCatalog?.products.count ?? 0) products, version \(state.filamentCatalog?.upstreamVersion ?? "unknown")")
                Text("OrcaSlicer: \(state.technicalCatalog?.profiles.count ?? 0) pinned technical profiles. No retail prices imported.")
                Text("Catalog → manufacturer TDS → process profiles → packaging → secondary cross-checks. Retail prices remain a separate stream. User overrides are preserved.").foregroundStyle(.secondary)
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
        }.searchable(text:$query,prompt:"Find source or manufacturer").navigationTitle("Data & Pricing Sources")
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
