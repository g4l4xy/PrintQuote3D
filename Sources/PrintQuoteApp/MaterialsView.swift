import SwiftUI
import QuoteDomain
import QuoteData

private enum MaterialsTab: String, CaseIterable, Identifiable {
    case mine = "My Inventory"
    case catalog = "All Filaments"

    var id: Self { self }
}

/// Keeps shop-owned spools and the reference catalog in one workspace.
struct MaterialsView: View {
    @Bindable var state: AppState
    let onUse: ((FilamentProduct) -> Void)?

    @State private var tab: MaterialsTab = .catalog
    @AppStorage("v4.materials.layout") private var layout="Cards"
    @AppStorage("v4.inventory.sort") private var inventorySort="Favorite"
    @State private var materialID: UUID?
    @State private var pickerGroup="all"
    @State private var catalogProductID: UUID?
    @State private var manualDraft: FilamentProduct?
    @State private var page=FilamentPage()
    @State private var searching=false
    @State private var selectedVariant:UUID?
    @State private var selectedSize:UUID?
    private var query:String {get{state.filamentQuery.text} nonmutating set{state.filamentQuery.text=newValue;state.filamentQuery.offset=0}}


    init(state: AppState, onUse: ((FilamentProduct) -> Void)? = nil) {
        self.state = state
        self.onUse = onUse
        _tab=State(initialValue:onUse == nil ? .catalog:.mine)
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
            .filter {onUse == nil || pickerGroup=="all" || (pickerGroup=="recent" && state.v4Recent["filaments:"+$0.id.uuidString] != nil) || (pickerGroup=="favorite" && state.v4Favorites.contains("filaments:"+$0.id.uuidString)) || (pickerGroup=="recommended" && (state.v4Favorites.contains("filaments:"+$0.id.uuidString) || state.v4Recent["filaments:"+$0.id.uuidString] != nil))}
            .sorted {
                switch inventorySort {
                case "Price / kg":if $0.pricePerKG != $1.pricePerKG{return $0.pricePerKG<$1.pricePerKG}
                case "Material":if $0.materialFamily != $1.materialFamily{return $0.materialFamily<$1.materialFamily}
                case "Favorite":let a=state.v4Favorites.contains("filaments:"+$0.id.uuidString);let b=state.v4Favorites.contains("filaments:"+$1.id.uuidString);if a != b{return a}
                case "Recently Used":let a=state.v4Recent["filaments:"+$0.id.uuidString] ?? 0;let b=state.v4Recent["filaments:"+$1.id.uuidString] ?? 0;if a != b{return a>b}
                default:break
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }


    var body: some View {
        GeometryReader { geometry in
            if layout=="Table" && !isShowingDetail {browser.frame(maxWidth:.infinity,maxHeight:.infinity)}
            else if geometry.size.width >= 720 {
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
        .task(id:state.filamentQuery){await searchCatalog()}
        .onChange(of:state.filamentLoading){_,loading in if !loading{Task{await searchCatalog()}}}
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


            TextField(tab == .mine ? "Search your materials" : "Search brand, material or product", text:Binding(get:{query},set:{query=$0}))
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.top, 10)

            if onUse != nil {
                Menu("Quick material picker") {
                    Button("Recently Used"){tab = .mine;pickerGroup="recent";inventorySort="Recently Used"}
                    Button("Recommended from your history"){tab = .mine;pickerGroup="recommended";inventorySort="Favorite"}
                    Button("Saved Favorites"){tab = .mine;pickerGroup="favorite";inventorySort="Favorite"}
                    Button("Catalog Favorites"){tab = .catalog;state.filamentQuery=FilamentQuery();state.filamentQuery.favoritesOnly=true}
                    Button("My Inventory"){tab = .mine;pickerGroup="all"}
                    Button("All Filaments"){tab = .catalog;state.filamentQuery=FilamentQuery()}
                }.padding(.top,8)
                if pickerGroup=="recommended"{Text("Suggestions use your favorites and recent selections. Verify printer compatibility separately.").font(.caption).foregroundStyle(.secondary)}
            }
            Picker("Layout",selection:$layout){Text("Cards").tag("Cards");Text("Table").tag("Table")}.pickerStyle(.segmented).padding()
            if tab == .mine {
                Picker("Sort",selection:$inventorySort){ForEach(["Name","Manufacturer","Material","Price / kg","Recently Used","Favorite"],id:\.self){Text($0)}}.padding(.horizontal)
                if layout=="Table" {
                    ComparisonBrowser(key:"v4.inventory.table",columns:["Name","Material","Color","Price / kg","Stock (g)","Nickname","Notes"],records:savedMaterials.map{m in
                        ComparisonRecord(id:m.id.uuidString,values:["Name":m.name,"Material":m.materialFamily,"Color":m.colorName,"Price / kg":"\(m.pricePerKG)","Stock (g)":m.stock.map{"\($0.remainingGrams)"} ?? "","Nickname":m.productName,"Notes":m.stock?.notes ?? ""])
                    },open:{materialID=UUID(uuidString:$0)},edit:editInventory)
                } else {savedMaterialsList}
            } else {
                catalogList
            }
        }
    }

    private var savedMaterialsList:some View {
        let matches=savedMaterials
        let recent=matches.filter{state.v4Recent["filaments:"+$0.id.uuidString] != nil}
        let recentIDs=Set(recent.map(\.id))
        let favorites=matches.filter{state.v4Favorites.contains("filaments:"+$0.id.uuidString) && !recentIDs.contains($0.id)}
        let favoriteIDs=Set(favorites.map(\.id))
        let other=matches.filter{!recentIDs.contains($0.id) && !favoriteIDs.contains($0.id)}
        let groups:[(String,[FilamentProduct])]=onUse == nil ? [("My Inventory (\(matches.count))",matches)] : [("Recently Used",recent),("Favorites",favorites),("My Inventory",other)]
        return List {
            if matches.isEmpty {ContentUnavailableView("No saved materials match",systemImage:"circle.hexagongrid",description:Text("Choose My Inventory, clear the search or browse All Filaments to save a spool with your actual cost."))}
            ForEach(Array(groups.enumerated()),id:\.offset){_,group in
                if !group.1.isEmpty {SwiftUI.Section(group.0){ForEach(group.1){material in
                    Button{if onUse != nil{handleUse(material)}else{materialID=material.id}}label:{VStack(alignment:.leading,spacing:3){Text(material.name).font(.headline);Text(materialSummary(material)).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())}
                    .buttonStyle(.plain).contextMenu {
                        Button("Open / Edit"){materialID=material.id}
                        Button("Favorite"){state.favorite("filaments",material.id.uuidString);Task{try? await state.filamentRepository?.favorite(material.id.uuidString,enabled:state.v4Favorites.contains("filaments:"+material.id.uuidString))}}
                        Button("Duplicate"){var copy=material;copy.id=UUID();copy.productName+=" copy";manualDraft=copy}
                        Button("Use in Quote"){handleUse(material)}
                    }
                }}}
            }
        }
    }

    private func searchCatalog() async {
        searching=true
        do {try await Task.sleep(for:.milliseconds(250));if let repo=state.filamentRepository {try await repo.syncInventoryPrices(state.library.filaments);let result=try await repo.search(state.filamentQuery);try Task.checkCancellation();page=result;state.filamentVisibleCount=result.matches}}
        catch is CancellationError{return}
        catch{state.filamentFailure=error.localizedDescription}
        searching=false
    }
    private func favorite(_ row:FilamentSearchRow) {
        Task{do{try await state.filamentRepository?.favorite(row.id,enabled:!row.favorite);if state.v4Favorites.contains("filaments:"+row.id)==row.favorite{state.favorite("filaments",row.id)};await searchCatalog()}catch{state.error=error.localizedDescription}}
    }
    private var catalogList:some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                Menu("Material families") {ForEach(state.filamentFamilies,id:\.self){family in Toggle(family,isOn:Binding(get:{state.filamentQuery.families.contains(family)},set:{if $0{state.filamentQuery.families.insert(family)}else{state.filamentQuery.families.remove(family)};state.filamentQuery.offset=0}))}}
                Menu("Manufacturers") {ForEach(state.filamentBrands,id:\.self){brand in Toggle(brand,isOn:Binding(get:{state.filamentQuery.manufacturers.contains(brand)},set:{if $0{state.filamentQuery.manufacturers.insert(brand)}else{state.filamentQuery.manufacturers.remove(brand)};state.filamentQuery.offset=0}))}}
            }
            HStack {
                Toggle("Favorites",isOn:$state.filamentQuery.favoritesOnly)
                Toggle("Recent",isOn:$state.filamentQuery.recentOnly)
            }.toggleStyle(.button)
            Picker("Sort",selection:$state.filamentQuery.sort){ForEach(["Name","Manufacturer","Material","Price / kg","Recently Used","Favorite","Difficulty","Drying Requirement"],id:\.self){Text($0)}}
            Text("Unknown values sort last. Price uses your saved inventory; difficulty and drying requirements are shown only when supplied.").font(.caption2).foregroundStyle(.secondary)
            Button("Reset Filters"){state.filamentQuery=FilamentQuery()}
            Text("\(page.matches.formatted()) of \(page.total.formatted()) spool options · \(state.filamentCounts.products.formatted()) products · \(state.filamentCounts.variants.formatted()) colors").font(.caption)
            if state.filamentLoading {ProgressView(state.filamentStatus);Button("Cancel refresh"){state.catalogTask?.cancel()}}
            if searching{ProgressView("Searching local library…")}
            if let failure=state.filamentFailure{Text(failure).font(.caption).foregroundStyle(.orange);Button("Retry local refresh"){state.refreshFilaments()}}
            if page.rows.isEmpty && !searching && !state.filamentLoading {
                ContentUnavailableView("No filaments match these filters",systemImage:"line.3.horizontal.decrease.circle",description:Text("Clear manufacturer or material filters, or use Reset Filters."))
            }
            if layout=="Table" {
                ComparisonBrowser(key:"v4.catalog.table",columns:["Name","Manufacturer","Material","Color","Spool","Printing","Price / kg","Difficulty","Drying Requirement","Favorite"],records:page.rows.map{row in
                    ComparisonRecord(id:row.id,values:["Name":row.name,"Manufacturer":row.brand,"Material":row.family,"Color":row.color,"Spool":row.spool,"Printing":row.printing,"Price / kg":row.price.isEmpty ? "Not entered":row.price,"Difficulty":row.difficulty.isEmpty ? "Unknown":row.difficulty,"Drying Requirement":row.drying.isEmpty ? "Unknown":row.drying,"Favorite":row.favorite ? "★":""])
                },open:{id in if let row=page.rows.first(where:{$0.id==id}){catalogProductID=UUID(uuidString:row.productID);selectedVariant=UUID(uuidString:row.variantID);selectedSize=UUID(uuidString:row.id)}})
            } else {List(page.rows){row in
                HStack(alignment:.top) {
                    Button {catalogProductID=UUID(uuidString:row.productID);selectedVariant=UUID(uuidString:row.variantID);selectedSize=UUID(uuidString:row.id)} label:{
                        VStack(alignment:.leading,spacing:4){Text(row.brand+" "+row.name).font(.headline);Text(row.family+" · "+row.color).font(.subheadline);Text(row.spool).font(.caption);Text(row.printing).font(.caption2).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading)
                    }.buttonStyle(.plain)
                    Button{favorite(row)}label:{Image(systemName:row.favorite ? "star.fill":"star")}.buttonStyle(.plain).accessibilityLabel(row.favorite ? "Remove favorite":"Favorite filament")
                }.contextMenu{Button(row.favorite ? "Remove favorite":"Favorite"){favorite(row)};Button("Open details"){catalogProductID=UUID(uuidString:row.productID);selectedVariant=UUID(uuidString:row.variantID);selectedSize=UUID(uuidString:row.id)}}
            }
            }
            HStack {
                Button("Previous"){state.filamentQuery.offset=max(0,state.filamentQuery.offset-100)}.disabled(state.filamentQuery.offset==0)
                Text("Page \(state.filamentQuery.offset/100+1)").font(.caption)
                Button("Next"){state.filamentQuery.offset+=100}.disabled(state.filamentQuery.offset+100>=page.matches)
            }
        }.padding(.horizontal)
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
                    onUse: handleUse,
                    initialVariant:selectedVariant,initialSize:selectedSize
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
        state.usedMaterial(material)
        if let onUse { onUse(material) }
        else {
            tab = .mine
            materialID = material.id
        }
    }

    private func editInventory(_ id:String,_ field:String,_ value:String)->Bool {
        guard var material=state.library.filaments.first(where:{$0.id.uuidString==id}) else{return false}
        switch field {
        case "Price / kg":guard value.range(of:"^[+]?(?:[0-9]+(?:[.][0-9]*)?|[.][0-9]+)$",options:.regularExpression) != nil,let amount=Decimal(string:value),!amount.isNaN,amount>=0 else{state.error="Enter a valid nonnegative price per kg.";return false};material.pricePerKG=amount
        case "Stock (g)":guard value.range(of:"^[+]?(?:[0-9]+(?:[.][0-9]*)?|[.][0-9]+)$",options:.regularExpression) != nil,let amount=Decimal(string:value),!amount.isNaN,amount>=0 else{state.error="Enter valid nonnegative remaining grams.";return false};if material.stock==nil{material.stock=FilamentStock()};material.stock?.remainingGrams=amount
        case "Nickname":guard !value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{state.error="Enter a product nickname.";return false};material.productName=value
        case "Notes":if material.stock==nil{material.stock=FilamentStock()};material.stock?.notes=value
        default:return false
        }
        return state.saveMaterial(material)
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

            SwiftUI.Section("User Overrides") {
                Text("Source values stay unchanged. Clear an override to use its source value. Technical values are reference data; quote costs use your entered price.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(materialOverrideKeys, id: \.self) { key in
                    let source=draft.catalogSnapshot?.fields[key]?.value ?? "Unknown"
                    VStack(alignment:.leading) {
                        Text(key.replacingOccurrences(of:"_",with:" ")).font(.headline)
                        Text("Source Value: " + source).font(.caption)
                        TextField("User Override",text:Binding(get:{draft.technicalOverrides?[key] ?? ""},set:{value in
                            if draft.technicalOverrides == nil {draft.technicalOverrides=[:]}
                            if value.isEmpty {draft.technicalOverrides?.removeValue(forKey:key)} else {draft.technicalOverrides?[key]=value}
                        }))
                        Text("Effective Value: " + (draft.technicalOverrides?[key] ?? source)).font(.caption).foregroundStyle(.secondary)
                    }
                }
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

    var initialVariant:UUID? = nil
    var initialSize:UUID? = nil
    @State private var variantID: UUID?
    @State private var sizeID: UUID?
    @State private var pricePerKG: Decimal = 0

    private var variant: CatalogColorVariant? {
        product.variants.first(where: { $0.id == (variantID ?? initialVariant) }) ?? product.variants.first
    }

    private var size: CatalogSpoolSize? {
        variant?.sizes.first(where: { $0.id == (sizeID ?? initialSize) }) ?? variant?.sizes.first
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

            ForEach(["Printing", "Drying", "Mechanical Properties", "Overview"],id: \.self) { section in
                SwiftUI.Section(section) {
                    let fields=FieldPrecedence.merge(existing:FieldPrecedence.merge(existing:product.fields,incoming:variant?.fields ?? [:]),incoming:size?.fields ?? [:])
                    let keys=fields.keys.filter{materialSection($0)==section}.sorted()
                    if keys.isEmpty {Text("No verified source data").foregroundStyle(.secondary)}
                    ForEach(keys,id: \.self) { key in
                        if let field=fields[key] {
                            LabeledContent(key.replacingOccurrences(of:"_",with:" "),value:field.value)
                            DisclosureGroup("Source"){Text(field.sourcePath).font(.caption).textSelection(.enabled)}
                        }
                    }
                }
            }
            SwiftUI.Section("Compatibility") {
                ForEach(materialSystems,id: \.self) { system in
                    let key="compatibility_"+system.lowercased().replacingOccurrences(of:" ",with:"_")
                    LabeledContent(system,value:savedMaterial?.technicalOverrides?[key] ?? product.fields[key]?.value ?? "Unknown / not verified")
                }
                Text("Compatibility is evaluated separately for each feeder. Generic feeder claims do not establish support for a particular system.").font(.caption).foregroundStyle(.secondary)
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

private let materialSystems=["AMS", "AMS Lite", "AMS 2 Pro", "AMS HT", "ACE Pro", "ACE 2 Pro", "IFS", "MMU", "CFS", "External Spool"]
private let materialOverrideKeys=["nozzle_min_c", "nozzle_max_c", "bed_min_c", "bed_max_c", "drying_temperature_c", "drying_hours", "flow_ratio", "max_volumetric_speed", "density_g_cm3", "notes"] + materialSystems.map{"compatibility_"+$0.lowercased().replacingOccurrences(of:" ",with:"_")}
private func materialSection(_ key:String)->String {
    if key.contains("dry") {return "Drying"}
    if ["nozzle", "bed", "flow", "speed", "temperature"].contains(where:key.contains){return "Printing"}
    if ["density", "strength", "modulus", "elongation", "hardness"].contains(where:key.contains){return "Mechanical Properties"}
    return "Overview"
}
