import XCTest
import QuoteDomain
@testable import QuoteData

final class DraftRecoveryTests: XCTestCase {
    func testRecoveryIsAtomicAndDoesNotLoseQuoteOverrides() async throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let store=DraftRecoveryStore(directory:directory)
        var quote=Quote();quote.projectName="Recovery test";quote.input.pricePerKG=47;quote.notes="Keep my settings"
        try await store.save(quote)
        quote.notes="Newest edit";try await store.save(quote)
        let recovered=try await DraftRecoveryStore(directory:directory).recover()
        XCTAssertEqual(recovered.count,1);XCTAssertEqual(recovered[0].id,quote.id)
        XCTAssertEqual(recovered[0].input.pricePerKG,47);XCTAssertEqual(recovered[0].notes,"Newest edit")
        try await store.discard(quote.id)
        let empty=try await store.recover();XCTAssertTrue(empty.isEmpty)
    }
    func testUnreadableJournalIsPreservedAndReported() async throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:directory)}
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let file=directory.appendingPathComponent(UUID().uuidString+".json")
        try Data("corrupt journal".utf8).write(to:file)
        do {_ = try await DraftRecoveryStore(directory:directory).recover();XCTFail("Report unreadable journal")} catch {}
        XCTAssertTrue(FileManager.default.fileExists(atPath:file.path))
        let store=DraftRecoveryStore(directory:directory);let valid=Quote();try await store.save(valid)
        let report=try await store.scan();XCTAssertEqual(report.drafts.map(\.id),[valid.id]);XCTAssertEqual(report.issues.count,1)
    }
}
