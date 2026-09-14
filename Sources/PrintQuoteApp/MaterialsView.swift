import SwiftUI
import QuoteDomain

private enum MaterialsTab: String, CaseIterable, Identifiable {
    case mine = "My materials"
    case catalog = "Browse catalog"

    var id: Self { self }
}

/// Keeps shop-owned spools and the reference catalog in one workspace.
struct MaterialsView: View {
    @Bindable var state: AppState
    let onUse: ((FilamentProduct) -> Void)?

    @State private var tab: MaterialsTab = .mine
    @State private var materialID: UUID?
    @State private var catalogProductID: UUID?
    @State private var manualDraft: FilamentProduct?
    @State private var query = ""

    init(state: AppState, onUse: ((FilamentProduct) -> Void)? = nil) {
        self.state = state
        self.onUse = onUse
    }

    private var isShowingDetail: Bool {
        switch tab {
        case .mine: materialID != nil || manualDraft != nil
        case .catalog: catalogProductID != nil
        }
    }

    private var savedMaterials: [FilamentProduct] {
        state.library.filaments
            .filter { query.isEmpty || searchText(for: $0).localizedCaseInsensitiveContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var catalogProducts: [CatalogFilament] {
        (state.filamentCatalog?.products ?? [])
            .filter { query.isEmpty || ($0.brand + " " + $0.name + " " + $0.materialFamily).localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 720 {
                HStack(spacing: 0) {
                    browser.frame(width: min(360, geometry.size.width * 0.38))
                    Divider()
                    detail.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if isShowingDetail {
                VStack(alignment: .leading, spacing: 0) {
                    Button { clearSelection() } label: {
                        Label(tab == .mine ? "My materials" : "Browse catalog", systemImage: "chevron.left")
                    }
                    .padding()
                    detail.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                browser
            }
        }
        .navigationTitle("Materials")
        .toolbar {
            if tab == .mine {
                Button("Add material", systemImage: "plus") { addMaterial() }
            }
        }
    }

    private var browser: some View {
        VStack(spacing: 0) {
            Picker("Materials view", selection: $tab) {
                ForEach(MaterialsTab.allCases) { tab in Text(tab.rawValue).tag(tab) }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])
            .onChange(of: tab) { _, _ in
                query = ""
            }

            TextField(tab == .mine ? "Search your materials" : "Search brand, material or product", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.top, 10)

            if tab == .mine {
                savedMaterialsList
            } else {
                catalogList
            }
        }
    }

    private var savedMaterialsList: some View {
        List {
            SwiftUI.Section {
                if savedMaterials.isEmpty {
                    ContentUnavailableView(
                        "No saved materials",
                        systemImage: "circle.hexagongrid",
                        description: Text("Add a material manually or browse the catalog to save a spool with your cost."))
                } else {
                    ForEach(savedMaterials) { material in
                        Button { materialID = material.id } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(material.name).font(.headline)
                                Text(materialSummary(material)).font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("\(savedMaterials.count) saved material\(savedMaterials.count == 1 ? "" : "s")")
            }
        }
    }

    private var catalogList: some View {
        List {
            SwiftUI.Section {
                ForEach(catalogProducts) { product in
                    Button { catalogProductID = product.id } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(product.name).font(.headline)
                            Text(product.brand + " · " + product.materialFamily + " · \(product.variants.count) colors")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("\(catalogProducts.count) catalog products · offline")
            }
        }
    }

    @ViewBuilder private var detail: some View {
        switch tab {
        case .mine:
            if let manualDraft {
                MaterialEditor(
                    state: state,
                    material: manualDraft,
                    isNew: true,
                    onSaved: { material in
                        self.manualDraft = nil
                        self.materialID = material.id
                    },
                    onUse: onUse,
                    onDiscard: { self.manualDraft = nil }
                )
                .id(manualDraft.id)
            } else if let materialID,
                      let material = state.library.filaments.first(where: { $0.id == materialID }) {
                MaterialEditor(
                    state: state,
                    material: material,
                    isNew: false,
                    onSaved: { material in self.materialID = material.id },
                    onUse: onUse,
                    onDiscard: { self.materialID = nil }
                )
                .id(material.id)
            } else {
                ContentUnavailableView(
                    "Select a material",
                    systemImage: "circle.hexagongrid",
                    description: Text("Your saved spools hold the prices used in estimates."))
            }
        case .catalog:
            if let catalogProductID,
               let product = state.filamentCatalog?.products.first(where: { $0.id == catalogProductID }) {
                CatalogMaterialDetail(
                    state: state,
                    product: product,
                    onSaved: { material in
                        tab = .mine
                        materialID = material.id
                    },
                    onUse: handleUse
                )
                    .id(product.id)
            } else {
                ContentUnavailableView(
                    "Browse the catalog",
                    systemImage: "magnifyingglass",
                    description: Text("Choose a product, color and spool size, then save it with your own cost."))
            }
        }
    }

    private func addMaterial() {
        var material = FilamentProduct()
        material.source.name = "User entered"
        material.source.sourceType = "user"
        material.source.notes = "Created in Materials."
        tab = .mine
        manualDraft = material
        materialID = nil
        query = ""
    }

    private func clearSelection() {
        if tab == .mine {
            materialID = nil
            manualDraft = nil
        }
        else { catalogProductID = nil }
    }

    private func handleUse(_ material: FilamentProduct) {
        if let onUse { onUse(material) }
        else {
            tab = .mine
            materialID = material.id
        }
    }

    private func searchText(for material: FilamentProduct) -> String {
        [material.manufacturer, material.productName, material.materialFamily, material.colorName, material.stock?.location ?? ""]
            .joined(separator: " ")
    }

    private func materialSummary(_ material: FilamentProduct) -> String {
        var details = [material.materialFamily, material.colorName, money(material.pricePerKG, currency: state.library.settings.currency) + "/kg"]
        if let stock = material.stock {
            let count = "\(stock.spoolCount) spool\(stock.spoolCount == 1 ? "" : "s")"
            details.append(count + " · \(stock.remainingGrams.formatted()) g open")
        }
        return details.joined(separator: " · ")
    }
}

/// Edits a copy until the user saves, so invalid input cannot alter the live library.
private struct MaterialEditor: View {
    @Bindable var state: AppState
    let isNew: Bool
    let onSaved: (FilamentProduct) -> Void
    let onUse: ((FilamentProduct) -> Void)?
    let onDiscard: () -> Void

    @State private var draft: FilamentProduct

    init(
        state: AppState,
        material: FilamentProduct,
        isNew: Bool,
        onSaved: @escaping (FilamentProduct) -> Void,
        onUse: ((FilamentProduct) -> Void)?,
        onDiscard: @escaping () -> Void
    ) {
        self.state = state
        self.isNew = isNew
        self.onSaved = onSaved
        self.onUse = onUse
        self.onDiscard = onDiscard
        _draft = State(initialValue: material)
    }

    var body: some View {
        Form {
            SwiftUI.Section("Material") {
                TextField("Manufacturer", text: $draft.manufacturer)
                TextField("Product", text: $draft.productName)
                TextField("Material family", text: $draft.materialFamily)
                TextField("Color", text: $draft.colorName)
                TextField("Diameter (mm)", value: $draft.diameterMM, format: .number)
                TextField("Spool weight (g)", value: $draft.netWeightGrams, format: .number)
                DecimalField(title: "Your cost per kg (\(state.library.settings.currency))", value: $draft.pricePerKG)
            }

            SwiftUI.Section("Stock") {
                Toggle("Track stock", isOn: Binding(
                    get: { draft.stock != nil },
                    set: { draft.stock = $0 ? FilamentStock() : nil }
                ))

                if draft.stock != nil {
                    Stepper(
                        "Full / unopened spools: \(draft.stock?.spoolCount ?? 0)",
                        value: Binding(
                            get: { draft.stock?.spoolCount ?? 0 },
                            set: { draft.stock?.spoolCount = $0 }
                        ),
                        in: 0...999
                    )
                    DecimalField(
                        title: "Open-spool remaining grams",
                        value: Binding(
                            get: { draft.stock?.remainingGrams ?? 0 },
                            set: { draft.stock?.remainingGrams = $0 }
                        )
                    )
                    TextField(
                        "Storage location",
                        text: Binding(
                            get: { draft.stock?.location ?? "" },
                            set: { draft.stock?.location = $0 }
                        )
                    )
                    TextField(
                        "Stock notes",
                        text: Binding(
                            get: { draft.stock?.notes ?? "" },
                            set: { draft.stock?.notes = $0 }
                        ),
                        axis: .vertical
                    )
                    Text("Stock is a reference for now; saving a quote does not reduce it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SwiftUI.Section("Source") {
                Text(draft.source.name)
                if let value = draft.source.url,
                   let url = URL(string: value),
                   ["https", "http"].contains(url.scheme ?? "") {
                    Link(value, destination: url)
                }
                Text(draft.source.notes).font(.caption).foregroundStyle(.secondary)
                if let snapshot = draft.catalogSnapshot {
                    Text("Catalog snapshot: \(snapshot.sourceName) · \(snapshot.upstreamVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SwiftUI.Section {
                Button(isNew ? "Save material" : "Save changes") { save(useAfterSaving: false) }
                    .buttonStyle(.borderedProminent)

                if onUse != nil {
                    Button(isNew ? "Save and use in estimate" : "Save changes and use in estimate") {
                        save(useAfterSaving: true)
                    }
                }

                if isNew {
                    Button("Discard material", role: .destructive) { onDiscard() }
                } else {
                    Button("Delete material", role: .destructive) {
                        if state.deleteMaterial(id: draft.id) { onDiscard() }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func save(useAfterSaving: Bool) {
        draft.catalogSnapshot?.userOverride = true
        guard state.saveMaterial(draft) else { return }
        onSaved(draft)
        if useAfterSaving { onUse?(draft) }
    }
}

private struct CatalogMaterialDetail: View {
    @Bindable var state: AppState
    let product: CatalogFilament
    let onSaved: (FilamentProduct) -> Void
    let onUse: (FilamentProduct) -> Void

    @State private var variantID: UUID?
    @State private var sizeID: UUID?
    @State private var pricePerKG: Decimal = 0

    private var variant: CatalogColorVariant? {
        product.variants.first(where: { $0.id == variantID }) ?? product.variants.first
    }

    private var size: CatalogSpoolSize? {
        variant?.sizes.first(where: { $0.id == sizeID }) ?? variant?.sizes.first
    }

    private var savedMaterial: FilamentProduct? {
        guard let size else { return nil }
        return state.library.filaments.first(where: { $0.id == size.id })
    }

    var body: some View {
        Form {
            SwiftUI.Section(product.name) {
                Text(product.brand + " · " + product.materialFamily)
                Picker("Color", selection: Binding(get: { variant?.id }, set: { variantID = $0; sizeID = nil })) {
                    ForEach(product.variants) { variant in Text(variant.name).tag(Optional(variant.id)) }
                }
                if let variant {
                    if let hex = variant.colorHex { Text("Color: " + hex) }
                    Picker("Spool size", selection: Binding(get: { size?.id }, set: { sizeID = $0 })) {
                        ForEach(variant.sizes) { size in
                            Text("\(size.netWeightGrams?.formatted() ?? "Unknown") g · \(size.diameterMM?.formatted() ?? "Unknown") mm")
                                .tag(Optional(size.id))
                        }
                    }
                }

                if let savedMaterial {
                    Text("Already in My materials at \(money(savedMaterial.pricePerKG, currency: state.library.settings.currency))/kg.")
                        .foregroundStyle(.secondary)
                    Button("Use saved material in estimate") { onUse(savedMaterial) }
                        .buttonStyle(.borderedProminent)
                } else {
                    DecimalField(title: "Your cost per kg (\(state.library.settings.currency))", value: $pricePerKG)
                    Text("The catalog gives technical data. Enter the cost you actually paid before saving this spool.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Save to My materials") { save(useAfterSaving: false) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canSave)
                    Button("Save and use in estimate") { save(useAfterSaving: true) }
                        .disabled(!canSave)
                }
            }

            SwiftUI.Section("Technical properties") {
                ForEach(product.fields.keys.sorted(), id: \.self) { key in
                    if let field = product.fields[key] {
                        VStack(alignment: .leading) {
                            Text(key.replacingOccurrences(of: "_", with: " ")).font(.headline)
                            if let url = URL(string: field.value), ["https", "http"].contains(url.scheme ?? "") {
                                Link("Open source document", destination: url)
                            } else {
                                Text(field.value)
                            }
                            DisclosureGroup("Source") {
                                Text(field.sourcePath).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }
                    }
                }
            }

            if let size {
                SwiftUI.Section("Spool metadata") {
                    ForEach(size.fields.keys.sorted(), id: \.self) { key in
                        LabeledContent(key.replacingOccurrences(of: "_", with: " "), value: size.fields[key]!.value)
                    }
                }
                SwiftUI.Section("Purchase links") {
                    ForEach(size.purchaseURLs, id: \.self) { link in
                        if let url = URL(string: link), ["https", "http"].contains(url.scheme ?? "") {
                            Link(url.host ?? "Store", destination: url)
                        }
                    }
                }
            }

            SwiftUI.Section("Catalog source") {
                Text("Open Filament Database · MIT · " + (state.filamentCatalog?.upstreamVersion ?? ""))
                Text("Retrieved: " + (state.filamentCatalog?.retrievedAt ?? ""))
                Text("Unknown properties remain absent. Manufacturer technical documentation takes precedence when verified.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var canSave: Bool {
        size?.diameterMM != nil && size?.netWeightGrams != nil && pricePerKG > 0
    }

    private func save(useAfterSaving: Bool) {
        guard let variant,
              let size,
              let catalog = state.filamentCatalog,
              let diameter = size.diameterMM,
              let weight = size.netWeightGrams else { return }

        var material = FilamentProduct()
        material.id = size.id
        material.manufacturer = product.brand
        material.productName = product.name
        material.materialFamily = product.materialFamily
        material.colorName = variant.name
        material.diameterMM = diameter
        material.netWeightGrams = weight
        material.pricePerKG = pricePerKG
        material.catalogSnapshot = CatalogFilamentSnapshot(product: product, variant: variant, size: size, catalog: catalog)
        material.source.name = catalog.sourceName
        material.source.url = catalog.sourceURL
        material.source.sourceType = "openCatalog"
        material.source.retrievedAt = ISO8601DateFormatter().date(from: catalog.retrievedAt)
        material.source.notes = "Technical data: OFD \(catalog.upstreamVersion), MIT. Price entered by user."

        if state.saveMaterial(material) {
            onSaved(material)
            if useAfterSaving { onUse(material) }
        }
    }
}
