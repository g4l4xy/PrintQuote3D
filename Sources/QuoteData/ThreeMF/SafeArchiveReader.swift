import Foundation
import CryptoKit
import ZIPFoundation
import QuoteDomain

public struct ThreeMFImportLimits: Codable, Sendable {
    public var archiveBytes = 512 * 1024 * 1024
    public var expandedBytes = 512 * 1024 * 1024
    public var entryBytes = 128 * 1024 * 1024
    public var metadataBytes = 16 * 1024 * 1024
    public var retainedMetadataBytes = 16 * 1024 * 1024
    public var entryCount = 4096
    public var compressionRatio = 2000.0
    public var xmlDepth = 64
    public var objectCount = 10_000
    public var vertexCount = 1_000_000
    public var triangleCount = 1_000_000
    public var instanceCount = 10_000
    public var referenceDepth = 64
    public var seconds = 120.0
    public init() {}
    func validate() throws {
        guard [archiveBytes, expandedBytes, entryBytes, metadataBytes, retainedMetadataBytes, entryCount, xmlDepth, objectCount, vertexCount, triangleCount, instanceCount, referenceDepth].allSatisfy({ $0 > 0 }), seconds.isFinite, seconds > 0, compressionRatio.isFinite, compressionRatio > 0 else { throw ThreeMFFailure.security("Invalid importer limits.") }
    }
}
public struct ThreeMFImportProgress: Sendable {
    public var stage: String
    public var fraction: Double
    public init(_ stage: String, _ fraction: Double) { self.stage = stage; self.fraction = fraction }
}
enum ThreeMFFailure: Error, LocalizedError {
    case security(String), damaged(String), unsupported(String)
    var errorDescription: String? { switch self { case .security(let s), .damaged(let s), .unsupported(let s): s } }
}
final class ThreeMFContext {
    let limits: ThreeMFImportLimits
    let cancelled: @Sendable () -> Bool
    let progress: @Sendable (ThreeMFImportProgress) -> Void
    let started = ContinuousClock.now
    var diagnostics = [ImportDiagnostic]()
    var metadataBytes = 0
    var vertexCount = 0
    var triangleCount = 0
    init(_ limits: ThreeMFImportLimits, cancelled: @escaping @Sendable () -> Bool, progress: @escaping @Sendable (ThreeMFImportProgress) -> Void) { self.limits = limits; self.cancelled = cancelled; self.progress = progress }
    func check() throws {
        if cancelled() || Task.isCancelled { throw CancellationError() }
        if started.duration(to: .now) > .seconds(limits.seconds) { throw ThreeMFFailure.security("Processing time budget exceeded.") }
    }
    func retain(_ record: UnmappedThreeMFMetadata) throws {
        metadataBytes += record.sourcePath.utf8.count + record.scope.utf8.count + record.key.utf8.count + (record.value?.utf8.count ?? 0) + (record.namespace?.utf8.count ?? 0)
        if metadataBytes > limits.retainedMetadataBytes { throw ThreeMFFailure.security("Retained metadata budget exceeded.") }
    }
    func diagnostic(_ severity: ImportSeverity, _ category: String, _ code: String, _ message: String, path: String? = nil) {
        if diagnostics.count < 2000 { diagnostics.append(.init(severity, category, code, message, path: path)) }
    }
}
struct ThreeMFSourceSnapshot: Sendable {
    var url: URL; var originalName: String; var sha256: String; var size: Int
    static func create(_ url: URL, limits: ThreeMFImportLimits, cancelled: @Sendable () -> Bool) throws -> Self {
        // URL resource values can be cached across reimports of the same path.
        // Read filesystem attributes afresh both before and after the snapshot.
        let values = try FileManager.default.attributesOfItem(atPath:url.path)
        let initialSize=(values[.size] as? NSNumber)?.intValue
        guard values[.type] as? FileAttributeType == .typeRegular, (initialSize ?? 0) <= limits.archiveBytes else { throw ThreeMFFailure.security("Source is not a regular file or exceeds the archive limit.") }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("PrintQuote-3MF-\(UUID().uuidString).tmp")
        FileManager.default.createFile(atPath: temporary.path, contents: nil, attributes: [.posixPermissions: 0o600])
        do {
            let input = try FileHandle(forReadingFrom: url); defer { try? input.close() }
            let output = try FileHandle(forWritingTo: temporary); defer { try? output.close() }
            var hash = SHA256(); var size = 0; let start = ContinuousClock.now
            while true {
                if cancelled() || Task.isCancelled { throw CancellationError() }
                if start.duration(to: .now) > .seconds(limits.seconds) { throw ThreeMFFailure.security("Source read time budget exceeded.") }
                guard let data = try input.read(upToCount: 65_536), !data.isEmpty else { break }
                size += data.count
                guard size <= limits.archiveBytes else { throw ThreeMFFailure.security("Archive size budget exceeded while reading.") }
                hash.update(data: data); try output.write(contentsOf: data)
            }
            let after = try FileManager.default.attributesOfItem(atPath:url.path)
            guard size > 0, size == initialSize, (after[.size] as? NSNumber)?.intValue == initialSize, after[.modificationDate] as? Date == values[.modificationDate] as? Date else { throw ThreeMFFailure.damaged("Source changed during import; select it again.") }
            return .init(url: temporary, originalName: url.lastPathComponent, sha256: hash.finalize().map { String(format: "%02x", $0) }.joined(), size: size)
        } catch { try? FileManager.default.removeItem(at: temporary); throw error }
    }
}
struct ThreeMFContainerManifest {
    var entries: [String] = []
    var roots: [String] = []
    var relationships: [ThreeMFRelationship] = []
    var contentTypes: [String: String] = [:]
}
struct ThreeMFRelationship { var source: String; var target: String; var type: String; var external: Bool }
final class SafeArchiveReader {
    let archive: Archive
    let context: ThreeMFContext
    private var entries: [String: Entry] = [:]
    let paths: [String]
    init(url: URL, context: ThreeMFContext) throws {
        self.context = context
        try context.check(); archive = try Archive(url: url, accessMode: .read)
        var order = [String](); var total: UInt64 = 0
        for e in archive {
            try context.check()
            guard order.count < context.limits.entryCount, e.path.utf8.count < 4096, !e.path.isEmpty, !e.path.hasPrefix("/"), !e.path.contains("\\"), !e.path.contains(":"), !e.path.contains("//"), !e.path.unicodeScalars.contains(where: { $0.value < 32 || (127...159).contains($0.value) }), !e.path.split(separator: "/").contains(where: { $0 == "." || $0 == ".." }), entries[e.path] == nil, e.type != .symlink else { throw ThreeMFFailure.security("Unsafe, duplicate, symbolic-link or excessive ZIP entries.") }
            guard e.uncompressedSize <= context.limits.entryBytes else { throw ThreeMFFailure.security("Entry size limit exceeded: \(e.path)") }
            total += e.uncompressedSize
            guard total <= context.limits.expandedBytes, Double(e.uncompressedSize) / Double(max(1, e.compressedSize)) <= context.limits.compressionRatio else { throw ThreeMFFailure.security("Expanded archive or compression-ratio limit exceeded.") }
            entries[e.path] = e; order.append(e.path)
        }
        paths = order
    }
    func read(_ path: String, metadata: Bool = true, retain: Bool = true) throws -> Data {
        guard let e = entries[path], e.type == .file else { throw ThreeMFFailure.damaged("Missing archive file: \(path)") }
        let cap = metadata ? context.limits.metadataBytes : context.limits.entryBytes
        guard e.uncompressedSize <= cap else { throw ThreeMFFailure.security("Entry exceeds its reading budget: \(path)") }
        var data = Data(); var expanded = 0
        let crc = try archive.extract(e, bufferSize: 65_536) { chunk in
            try self.context.check(); expanded += chunk.count
            guard expanded <= cap, UInt64(expanded) <= e.uncompressedSize else { throw ThreeMFFailure.security("Entry expands beyond its declared size: \(path)") }
            if retain { data.append(chunk) }
        }
        guard expanded == e.uncompressedSize, crc == e.checksum else { throw ThreeMFFailure.damaged("Size/checksum mismatch: \(path)") }
        return data
    }
    /// Resolve OPC part names only. Never pass relationship targets to a network client.
    static func resolve(_ target: String, relativeTo part: String) throws -> String {
        guard let decoded = target.removingPercentEncoding, !decoded.contains(":"), !decoded.contains("\\"), !decoded.contains("?"), !decoded.contains("#"), !decoded.unicodeScalars.contains(where: { $0.value < 32 || (127...159).contains($0.value) }) else { throw ThreeMFFailure.damaged("Invalid internal relationship target.") }
        var components = decoded.hasPrefix("/") ? [] : Array(part.split(separator: "/").dropLast()).map(String.init)
        for value in decoded.split(separator: "/") {
            if value == "." { continue }
            if value == ".." { guard !components.isEmpty else { throw ThreeMFFailure.security("Relationship escapes the archive root.") }; components.removeLast() }
            else { components.append(String(value)) }
        }
        return components.joined(separator: "/")
    }
}
