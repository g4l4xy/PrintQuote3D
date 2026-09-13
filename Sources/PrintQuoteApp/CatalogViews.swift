import SwiftUI
import QuoteDomain

struct MaterialCatalogView: View {
    @Bindable var state: AppState
    @State private var query = ""
    @State private var selection: UUID?
    var products: [CatalogFilament] {
        (state.filamentCatalog?.products ?? []).filter { query.isEmpty || ($0.brand + " " + $0.name + " " + $0.materialFamily).localizedCaseInsensitiveContains(query) }
    }
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing:0) {
                VStack {
                    TextField("Search brand, material or product",text:$query).textFieldStyle(.roundedBorder).padding()
                    Text("\(products.count) products · offline catalog").font(.caption).foregroundStyle(.secondary)
                    List(products,selection:$selection) { p in VStack(alignment:.leading) { Text(p.name).font(.headline); Text(p.brand + " · " + p.materialFamily + " · \(p.variants.count) colors").font(.caption).foregroundStyle(.secondary) }.tag(p.id) }
                }.frame(width:geometry.size.width * 0.4)
                Divider()
                if let p = state.filamentCatalog?.products.first(where:{$0.id == selection}) {
                    CatalogFilamentDetail(state:state,product:p).id(p.id).frame(maxWidth:.infinity)
                } else { ContentUnavailableView("Filament database",systemImage:"circle.hexagongrid",description:Text("Select a product to inspect colors, spool sizes, technical data and source provenance.")) }
            }
        }.navigationTitle("Material Database")
    }
}
struct CatalogFilamentDetail: View {
    @Bindable var state: AppState
    let product: CatalogFilament
    @State private var variantID: UUID?
    @State private var sizeID: UUID?
    @State private var pricePerKG: Decimal = 0
    var variant: CatalogColorVariant? { product.variants.first(where:{$0.id == variantID}) ?? product.variants.first }
    var size: CatalogSpoolSize? { variant?.sizes.first(where:{$0.id == sizeID}) ?? variant?.sizes.first }
    var body: some View {
        Form {
            SwiftUI.Section(product.name) {
                Text(product.brand + " · " + product.materialFamily)
                Picker("Color",selection:Binding(get:{variant?.id},set:{variantID=$0;sizeID=nil})) { ForEach(product.variants) { v in Text(v.name).tag(Optional(v.id)) } }
                if let variant {
                    if let hex=variant.colorHex { Text("Color: " + hex) }
                    Picker("Spool size",selection:Binding(get:{size?.id},set:{sizeID=$0})) { ForEach(variant.sizes) { s in Text("\(s.netWeightGrams?.formatted() ?? "Unknown") g · \(s.diameterMM?.formatted() ?? "Unknown") mm").tag(Optional(s.id)) } }
                }
                DecimalField(title:"Your price per kg (\(state.library.settings.currency))",value:$pricePerKG)
                Text("Enter your actual cost. Catalog purchase links do not supply verified current prices.").font(.caption).foregroundStyle(.secondary)
                Button("Add selected spool to Filaments") { add() }.buttonStyle(.borderedProminent).disabled(size == nil || pricePerKG <= 0 || size?.diameterMM == nil || size?.netWeightGrams == nil || state.library.filaments.contains(where:{$0.id == size?.id}))
                if state.library.filaments.contains(where:{$0.id == size?.id}) { Text("Already in your library; your edits are preserved.").foregroundStyle(.secondary) }
            }
            SwiftUI.Section("Technical properties") { ForEach(product.fields.keys.sorted(),id:\.self) { key in if let field=product.fields[key] { VStack(alignment:.leading) { Text(key.replacingOccurrences(of:"_",with:" ")).font(.headline); if let url = URL(string:field.value), ["https","http"].contains(url.scheme ?? "") { Link("Open source document", destination:url) } else { Text(field.value) }; DisclosureGroup("Source") { Text(field.sourcePath).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled) } } } } }
            if let size {
                SwiftUI.Section("Spool metadata") { ForEach(size.fields.keys.sorted(),id:\.self) { key in LabeledContent(key.replacingOccurrences(of:"_",with:" "),value:size.fields[key]!.value) } }
                SwiftUI.Section("Purchase links") { ForEach(size.purchaseURLs,id:\.self) { link in if let url=URL(string:link),["https","http"].contains(url.scheme ?? "") { Link(url.host ?? "Store",destination:url) } } }
            }
            SwiftUI.Section("Source") {
                Text("Open Filament Database · MIT · " + (state.filamentCatalog?.upstreamVersion ?? ""))
                Text("Retrieved: " + (state.filamentCatalog?.retrievedAt ?? ""))
                Text("Unknown properties remain absent. Manufacturer technical documentation takes precedence when verified.").font(.caption).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
    func add() {
        guard let variant,let size,let catalog=state.filamentCatalog,let diameter=size.diameterMM,let weight=size.netWeightGrams else {return}
        var f=FilamentProduct(); f.id=size.id; f.manufacturer=product.brand; f.productName=product.name; f.materialFamily=product.materialFamily; f.colorName=variant.name; f.diameterMM=diameter; f.netWeightGrams=weight; f.pricePerKG=pricePerKG
        f.catalogSnapshot=CatalogFilamentSnapshot(product:product,variant:variant,size:size,catalog:catalog)
        f.source.name=catalog.sourceName; f.source.url=catalog.sourceURL; f.source.sourceType="openCatalog"; f.source.retrievedAt=ISO8601DateFormatter().date(from:catalog.retrievedAt); f.source.notes="Technical data: OFD \(catalog.upstreamVersion), MIT. Price entered by user."
        state.library.filaments.append(f); state.persist()
    }
}
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
    var body: some View {
        VStack {
            HStack { Text("OrcaSlicer technical profiles").font(.title2.bold()); Spacer(); Button("Close") {dismiss()} }.padding()
            Form {
                DecimalField(title:"Price per kg for filament imports (user entered)",value:$pricePerKG)
                ForEach(state.technicalCatalog?.profiles ?? []) { p in
                    SwiftUI.Section(p.name) {
                        Text(p.kind + " · " + p.vendor)
                        if p.kind == "machine" { Text("Build: \(p.buildXMM?.formatted() ?? "?") × \(p.buildYMM?.formatted() ?? "?") × \(p.buildZMM?.formatted() ?? "?") mm") }
                        Text(p.reviewReasons.joined(separator:"\n")).font(.caption).foregroundStyle(.orange)
                        DisclosureGroup("Source and technical fields") {
                            Text(p.source.sourcePath).textSelection(.enabled)
                            Text("Commit: " + p.source.commitSHA).font(.caption).textSelection(.enabled)
                            ForEach(p.technicalValues.keys.sorted(),id:\.self) { k in LabeledContent(k,value:p.technicalValues[k]!.joined(separator:", ")) }
                        }
                        Button("Add to \(p.kind == "machine" ? "Printers" : "Filaments")") { add(p) }.disabled(state.library.printers.contains {$0.id==p.id} || state.library.filaments.contains {$0.id==p.id} || (p.kind == "filament" && pricePerKG <= 0))
                    }
                }
            }.formStyle(.grouped)
        }.frame(width:800,height:680)
    }
    func add(_ p:NormalizedTechnicalProfile) {
        var source=SourceReference(); source.name="OrcaSlicer"; source.url=p.source.repositoryURL + "/blob/" + p.source.commitSHA + "/" + p.source.sourcePath; source.sourceType="slicerProfile"; source.retrievedAt=p.source.importedAt; source.notes=p.reviewReasons.joined(separator:"\n")
        if p.kind == "machine" {
            var printer=PrinterProfile(); printer.id=p.id; printer.manufacturer=p.vendor; printer.model=p.name; printer.buildVolumeXMM=p.buildXMM ?? 0; printer.buildVolumeYMM=p.buildYMM ?? 0; printer.buildVolumeZMM=p.buildZMM ?? 0
            printer.typicalPowerWatts=0; printer.machineRate=0; printer.maintenanceRate=0; printer.source=source; printer.externalProfile=p.source
            var system=PrinterToolSystem(); system.architecture = .custom; system.resize(to:p.physicalToolheadCount ?? 1)
            if let nozzle=p.nozzleDiametersMM.first { system.toolheads[0].nozzleDiameterMM=Decimal(nozzle) }
            printer.toolSystem=system
            var hardware=PrinterHardwareDetails()
            for (key,values) in p.technicalValues { hardware.fieldSources[key]=TechnicalField(value:values.joined(separator:", "),sourcePath:p.fieldSourcePaths[key] ?? p.source.sourcePath,sourcePriority:3,userOverride:false) }
            for (key,value,upstreamKey) in [("buildXMM",p.buildXMM,"printable_area"),("buildYMM",p.buildYMM,"printable_area"),("buildZMM",p.buildZMM,"printable_height")] {
                if let value { hardware.fieldSources[key]=TechnicalField(value:String(value),sourcePath:p.fieldSourcePaths[upstreamKey] ?? p.source.sourcePath,sourcePriority:3,userOverride:false) }
            }
            printer.hardware=hardware; state.library.printers.append(printer)
        } else {
            var f=FilamentProduct(); f.id=p.id; f.manufacturer=p.vendor; f.productName=p.name; f.materialFamily=p.materialFamily ?? "Unknown"; f.pricePerKG=pricePerKG; f.source=source; f.externalProfile=p.source; state.library.filaments.append(f)
        }
        state.persist()
    }
}
