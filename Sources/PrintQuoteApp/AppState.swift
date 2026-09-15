import SwiftUI
import QuoteDomain
import QuoteData

@MainActor @Observable final class AppState {
    var library = LibrarySnapshot()
    var error: String?
    var ready = false
    var technicalCatalog: TechnicalProfileCatalog?
    var filamentCatalog: OpenFilamentCatalog?
    var sourceCatalog: FilamentSourceCatalog?
    var filamentRepository:FilamentRepository?
    var filamentCounts=FilamentImportCounts()
    var filamentStatus="Loading filament library…"
    var filamentLoading=false
    var filamentFailure:String?
    var filamentBrands:[String]=[]
    var filamentFamilies:[String]=[]
    var filamentQuery=FilamentQuery()
    var filamentVisibleCount=0
    var catalogTask:Task<Void,Never>?
    var printerTask:Task<Void,Never>?
    var printerLoading=false
    var printerStatus="Offline printer profiles"
    var toast:String?
    var recoveredDrafts:[Quote]=[]
    let recovery=DraftRecoveryStore()
    var commandRequested=false
    var quickQuote:Quote?
    var requestedPrinter:UUID?
    var navigationRequest:String?
    var v4Favorites:Set<String>=Set(UserDefaults.standard.stringArray(forKey:"v4.favorites") ?? [])
    var v4Recent:[String:Double]=UserDefaults.standard.dictionary(forKey:"v4.recent") as? [String:Double] ?? [:]

    private var repository: (any LibraryRepository)?
    init() {
        do {
            let repo = try SwiftDataLibraryRepository(inMemory: ProcessInfo.processInfo.arguments.contains("--ui-testing"))
            repository = repo
            library = try repo.load() ?? SeedLoader.load()
            for index in library.printers.indices where library.printers[index].toolSystem == nil {
                var system = PrinterToolSystem(); system.architecture = .custom
                library.printers[index].toolSystem = system
            }
            library.schemaVersion = 2
            technicalCatalog = try SeedLoader.resource("orca_profiles_v2", as: TechnicalProfileCatalog.self)
            if let technicalCatalog { library.includePrinters(from: technicalCatalog) }
            let manufacturerCatalog = try SeedLoader.resource("manufacturer_printers_v2", as: TechnicalProfileCatalog.self)
            library.includePrinters(from: manufacturerCatalog)
            try repo.save(library)
            sourceCatalog = try SeedLoader.resource("filament_sources_v2", as: FilamentSourceCatalog.self)
            ready = true
        } catch { self.error = error.localizedDescription }
        refreshFilaments()
        Task {do{let report=try await recovery.scan();recoveredDrafts=report.drafts;if !report.issues.isEmpty{self.error="Some recovery drafts could not be read. Their files are preserved. "+report.issues.joined(separator:"\n")}}catch{self.error="Draft recovery needs attention. Recovery files are preserved. \(error.localizedDescription)"}}
    }
    func favorite(_ kind:String,_ id:String) {
        let key=kind+":"+id
        if v4Favorites.contains(key){v4Favorites.remove(key)}else{v4Favorites.insert(key)}
        UserDefaults.standard.set(Array(v4Favorites),forKey:"v4.favorites")
    }
    func used(_ kind:String,_ id:String){v4Recent[kind+":"+id]=Date().timeIntervalSince1970;UserDefaults.standard.set(v4Recent,forKey:"v4.recent")}

    func refreshFilaments() {
        guard !filamentLoading else{return}
        filamentLoading=true;filamentFailure=nil
        catalogTask=Task {
            do {
                let url=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("PrintQuote3D/catalog-v4.sqlite")
                let repo=try filamentRepository ?? FilamentRepository(url:ProcessInfo.processInfo.arguments.contains("--ui-testing") ? nil:url)
                filamentRepository=repo
                let data=try await Task.detached{try SeedLoader.data("open_filaments_v2")}.value
                let (catalog,counts)=try await repo.rebuild(data:data,progress:{stage in Task{@MainActor in self.filamentStatus=stage}})
                filamentCatalog=catalog;filamentCounts=counts;filamentBrands=try await repo.brands();filamentFamilies=try await repo.families()
                filamentStatus="Offline catalog ready";toast="Filament database refreshed"
            }catch is CancellationError {filamentStatus="Refresh canceled. Existing local library remains available."}
            catch {filamentFailure="Filament database could not be refreshed. Existing local data is preserved. \(error.localizedDescription)";filamentStatus="Catalog needs attention"}
            filamentLoading=false
        }
    }
    func startQuote(printer:PrinterProfile) {
        var q=Quote();q.number="PQ-"+String(UUID().uuidString.prefix(8));q.currency=library.settings.currency;q.expiresAt=Date().addingTimeInterval(Double(library.settings.expirationDays)*86400)
        q.input.electricityRate=library.settings.electricityRate;q.input.taxRate=library.settings.taxRate
        q.printer=printer;q.input.averageWatts=printer.typicalPowerWatts;q.input.machineRate=printer.machineRate;q.input.maintenanceRate=printer.maintenanceRate
        if let material=library.filaments.first{q.filament=material;q.input.pricePerKG=material.pricePerKG;q.input.supportPricePerKG=material.pricePerKG;q.input.interfacePricePerKG=material.pricePerKG}
        used("printers",printer.id.uuidString);quickQuote=q
    }
    func refreshPrinters() {
        guard !printerLoading else{return};printerLoading=true;printerStatus="Reading offline printer profiles…"
        printerTask=Task {
            do {
                let catalogs=try await Task.detached{try [SeedLoader.resource("orca_profiles_v2",as:TechnicalProfileCatalog.self),SeedLoader.resource("manufacturer_printers_v2",as:TechnicalProfileCatalog.self)]}.value
                try Task.checkCancellation();let previous=library;let before=library.printers.count
                for catalog in catalogs{library.includePrinters(from:catalog)}
                if persist(){printerStatus="Validated printer data; \(library.printers.count-before) new profiles. Existing configurations retained.";toast="Printer database refreshed"}else{library=previous;printerStatus="Printer refresh failed; existing data retained."}
            }catch is CancellationError{printerStatus="Printer refresh canceled; existing data retained."}
            catch{printerStatus="Printer refresh failed; existing profiles retained.";self.error="Printer data could not be refreshed: \(error.localizedDescription)"}
            printerLoading=false
        }
    }
    func usedMaterial(_ material:FilamentProduct) {used("filaments",material.id.uuidString);Task{do{try await filamentRepository?.used(material.id.uuidString)}catch{self.error=error.localizedDescription}}}

    @discardableResult func persist() -> Bool {
        do {
            guard let repository, ready else { throw PricingError.invalid("Storage is unavailable. Restart after resolving the storage error.") }
            for printer in library.printers { try printer.toolSystem?.validate(); try printer.hardware?.validate() }
            for material in library.filaments { try material.validateMaterial() }
            try repository.save(library); return true
        } catch { self.error = error.localizedDescription; return false }
    }
    @discardableResult func saveMaterial(_ material: FilamentProduct) -> Bool {
        do { try material.validateMaterial() } catch { self.error = error.localizedDescription; return false }
        let previous = library
        if let index = library.filaments.firstIndex(where: { $0.id == material.id }) { library.filaments[index] = material }
        else { library.filaments.append(material) }
        if persist() { toast="Material saved";return true }
        library = previous
        return false
    }
    @discardableResult func deleteMaterial(id: UUID) -> Bool {
        let previous = library
        library.filaments.removeAll { $0.id == id }
        if persist() { return true }
        library = previous
        return false
    }
    func save(_ quote: Quote) -> Bool {
        let previous = library
        if let index = library.quotes.firstIndex(where: {$0.id == quote.id}) { library.quotes[index] = quote }
        else { library.quotes.insert(quote, at: 0) }
        if persist() { toast="Quote saved";return true }; library = previous; return false
    }
}
func money(_ value: Decimal, currency: String = "USD") -> String {
    value.formatted(.currency(code: currency))
}
