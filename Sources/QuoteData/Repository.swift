import Foundation
import SwiftData
import QuoteDomain

@MainActor public protocol LibraryRepository {
    func load() throws -> LibrarySnapshot?
    func save(_ library: LibrarySnapshot) throws
}
@Model final class LibraryRecord {
    @Attribute(.unique) var key: String
    var payload: Data
    init(payload: Data) { self.key = "library-v1"; self.payload = payload }
}
@MainActor public final class SwiftDataLibraryRepository: LibraryRepository {
    private let container: ModelContainer
    public init(url: URL? = nil, inMemory: Bool = false) throws {
        let configuration: ModelConfiguration
        if let url { configuration = ModelConfiguration(url: url) }
        else { configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory) }
        container = try ModelContainer(for: LibraryRecord.self, configurations: configuration)
    }
    public func load() throws -> LibrarySnapshot? {
        guard let record = try container.mainContext.fetch(FetchDescriptor<LibraryRecord>()).first else { return nil }
        let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: record.payload)
        guard snapshot.schemaVersion == 1 else { throw PricingError.invalid("Unsupported saved data version.") }
        return snapshot
    }
    public func save(_ library: LibrarySnapshot) throws {
        let payload = try JSONEncoder().encode(library)
        let context = container.mainContext
        if let record = try context.fetch(FetchDescriptor<LibraryRecord>()).first { record.payload = payload }
        else { context.insert(LibraryRecord(payload: payload)) }
        do { try context.save() } catch { context.rollback(); throw error }
    }
}
public enum SeedLoader {
    public static func load() throws -> LibrarySnapshot {
        let embedded = Bundle.main.resourceURL.flatMap { Bundle(url: $0.appendingPathComponent("PrintQuote3D_QuoteData.bundle")) }
        let resources = embedded ?? Bundle.module
        guard let url = resources.url(forResource: "library_seed_v1", withExtension: "json") else { throw PricingError.invalid("Missing seed data.") }
        return try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: url))
    }
}
// TODO: Isolate STL/3MF import behind an ImportService protocol in the next milestone.
