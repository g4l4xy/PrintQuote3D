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
            filamentCatalog = try SeedLoader.resource("open_filaments_v2", as: OpenFilamentCatalog.self)
            sourceCatalog = try SeedLoader.resource("filament_sources_v2", as: FilamentSourceCatalog.self)
            ready = true
        } catch { self.error = error.localizedDescription }
    }
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
        if persist() { return true }
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
        if persist() { return true }; library = previous; return false
    }
}
func money(_ value: Decimal, currency: String = "USD") -> String {
    value.formatted(.currency(code: currency))
}
