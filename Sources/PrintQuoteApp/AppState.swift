import SwiftUI
import QuoteDomain
import QuoteData

@MainActor @Observable final class AppState {
    var library = LibrarySnapshot()
    var error: String?
    var ready = false
    private var repository: (any LibraryRepository)?
    init() {
        do {
            let repo = try SwiftDataLibraryRepository()
            repository = repo
            library = try repo.load() ?? SeedLoader.load()
            try repo.save(library)
            ready = true
        } catch { self.error = error.localizedDescription }
    }
    @discardableResult func persist() -> Bool {
        do {
            guard let repository, ready else { throw PricingError.invalid("Storage is unavailable. Restart after resolving the storage error.") }
            for printer in library.printers { try printer.toolSystem?.validate() }
            try repository.save(library); return true
        } catch { self.error = error.localizedDescription; return false }
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
