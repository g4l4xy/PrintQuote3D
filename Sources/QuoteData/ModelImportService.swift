import Foundation
import QuoteDomain
import ZIPFoundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public enum ModelImportError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}
private func requireImport(_ condition: Bool, _ message: String) throws {
    if !condition { throw ModelImportError.invalid(message) }
}
/// Read-only inspection. The report never mutates a pricing snapshot.
public enum ModelImportService {
    public static func inspect(url: URL, cancelled: @escaping () -> Bool = { false }) throws -> ModelInspectionReport {
        let reader = InspectionReader(cancelled: cancelled)
        return try reader.read(url)
    }
}
private final class InspectionReader {
    let cancelled: () -> Bool
    var fields = [ModelInspectionField]()
    let entryLimit = 128 * 1024 * 1024
    init(cancelled: @escaping () -> Bool) { self.cancelled = cancelled }
    func check() throws { if cancelled() { throw CancellationError() } }
    func add(_ category: String, _ source: String, _ key: String, _ value: String) throws {
        try check()
        try requireImport(fields.count < 30_000 && value.utf8.count <= 65_536 && key.utf8.count <= 65_536, "Metadata exceeds inspection limits.")
        fields.append(.init(category: category, source: source, key: key, value: value))
    }
    func read(_ url: URL) throws -> ModelInspectionReport {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        try requireImport(size > 0 && size <= 512 * 1024 * 1024, "File is empty or exceeds 512 MiB.")
        let ext = url.pathExtension.lowercased(); var warnings = [String]()
        if ext == "stl" {
            try requireImport(size <= entryLimit, "STL exceeds the 128 MiB inspection limit.")
            try stl(Data(contentsOf: url), source: url.lastPathComponent)
            warnings = ["STL has no standard unit, printer, toolhead or filament settings. Bounds use file coordinates. No material usage, supports or prime-tower estimate is inferred.", "STL attribute bytes and header are retained for inspection; vendor color conventions are not decoded. Topology and printable volume are not validated."]
        } else if ext == "3mf" {
            let archive = try Archive(url: url, accessMode: .read)
            var entries = [Entry](); var names = Set<String>(); var total: UInt64 = 0
            for entry in archive {
                try check()
                let name = entry.path
                try requireImport(entries.count < 4096 && name.utf8.count <= 4096 && !name.hasPrefix("/") && !name.contains("\\") && !name.contains(":") && !name.split(separator: "/").contains(where: { $0 == ".." || $0 == "." }) && names.insert(name).inserted, "Unsafe, duplicate or excessive archive entries.")
                try requireImport(entry.uncompressedSize <= UInt64(entryLimit), "Archive entry exceeds 128 MiB.")
                total += entry.uncompressedSize
                try requireImport(total <= 512 * 1024 * 1024, "Expanded archive exceeds 512 MiB.")
                entries.append(entry)
            }
            try requireImport(entries.contains { ["model", "gcode"].contains(($0.path as NSString).pathExtension.lowercased()) }, "No model or sliced G-code in this 3MF.")
            for entry in entries where entry.type != .directory {
                try add("Package", entry.path, "uncompressed bytes", String(entry.uncompressedSize))
                let suffix = (entry.path as NSString).pathExtension.lowercased()
                guard ["model", "xml", "rels", "config", "json", "gcode"].contains(suffix) else { continue }
                var data = Data()
                let crc = try archive.extract(entry, bufferSize: 65_536) { chunk in
                    try self.check()
                    try requireImport(data.count + chunk.count <= self.entryLimit && UInt64(data.count + chunk.count) <= entry.uncompressedSize, "Expanded entry exceeds declared size.")
                    data.append(chunk)
                }
                try requireImport(UInt64(data.count) == entry.uncompressedSize && crc == entry.checksum, "Archive entry is damaged.")
                guard let text = String(data: data, encoding: .utf8), !text.contains("\0") else { throw ModelImportError.invalid("Metadata must use UTF-8 text.") }
                let category = entry.path.hasSuffix("slice_info.config") || suffix == "gcode" ? "Sliced results" : entry.path.hasSuffix("project_settings.config") ? "Project settings" : "Metadata"
                if suffix == "gcode" {
                    var last = ""
                    for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                        try check(); let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if line.hasPrefix(";") {
                            let body = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                            if (body.contains("=") || body.contains(":")) && body != last { try add(category, entry.path, "line \(index + 1)", body); last = body }
                        }
                    }
                } else if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") || text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") {
                    try validateJSONDepth(text)
                    try json(JSONSerialization.jsonObject(with: data), path: "", source: entry.path, category: category, depth: 0)
                } else if text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
                    try requireImport(!text.uppercased().contains("<!DOCTYPE") && !text.uppercased().contains("<!ENTITY"), "DTD/entity declarations are not supported.")
                    let delegate = InspectionXML(reader: self, source: entry.path, category: category, model: suffix == "model")
                    let parser = XMLParser(data: data); parser.shouldResolveExternalEntities = false; parser.delegate = delegate
                    let success = parser.parse()
                    if let error = delegate.error { throw error }
                    try requireImport(success, "Malformed XML in \(entry.path): \(parser.parserError?.localizedDescription ?? "unknown error")")
                } else { try add("Metadata", entry.path, "unrecognized text", text) }
            }
            warnings = ["Project settings are not sliced usage. Sliced results are exporter estimates, not actual printer measurements. Missing values remain unknown; duplicate statistics are not summed.", "Mesh bounds are local resource coordinates. Build/component transforms, object roles and material assignments are retained as metadata. No assembled dimensions, toolpath-derived support/tower grams, texture or paint decoding is performed."]
        } else { throw ModelImportError.invalid("Choose an STL or 3MF file.") }
        return .init(fileName: url.lastPathComponent, format: ext.uppercased(), fields: fields, warnings: warnings)
    }
    func validateJSONDepth(_ text: String) throws {
        var depth = 0; var quoted = false; var escaped = false
        for c in text { if escaped { escaped = false; continue }; if quoted && c == "\\" { escaped = true; continue }; if c == "\"" { quoted.toggle() }; if !quoted { if c == "{" || c == "[" { depth += 1; try requireImport(depth <= 64, "JSON nesting limit exceeded.") }; if c == "}" || c == "]" { depth -= 1 } } }
    }
    func json(_ value: Any, path: String, source: String, category: String, depth: Int) throws {
        try requireImport(depth <= 64, "JSON nesting limit exceeded.")
        if let object = value as? [String: Any] {
            if object.isEmpty { try add(category, source, path, "{}") }
            for key in object.keys.sorted() { try json(object[key]!, path: path.isEmpty ? key : path + "." + key, source: source, category: category, depth: depth + 1) }
        } else if let array = value as? [Any] {
            if array.isEmpty { try add(category, source, path, "[]") }
            for (index, item) in array.enumerated() { try json(item, path: path + "[\(index)]", source: source, category: category, depth: depth + 1) }
        } else { try add(category, source, path, value is NSNull ? "null" : String(describing: value)) }
    }
    func stl(_ data: Data, source: String) throws {
        func u32(_ offset: Int) -> UInt32 { (0..<4).reduce(UInt32(0)) { $0 | UInt32(data[offset + $1]) << ($1 * 8) } }
        func float(_ offset: Int) -> Double { Double(Float(bitPattern: u32(offset))) }
        let count = data.count >= 84 ? UInt64(u32(80)) : UInt64.max
        var bounds = InspectionBounds(); var triangles = 0
        if count != UInt64.max && 84 + 50 * count == UInt64(data.count) {
            var attributes = 0
            for i in 0..<Int(count) {
                try check(); let offset = 84 + 50 * i
                try requireImport((0..<3).allSatisfy { float(offset + 4 * $0).isFinite }, "Invalid STL normal.")
                for v in 0..<3 { try bounds.vertex((0..<3).map { float(offset + 12 + v * 12 + $0 * 4) }) }
                if data[offset + 48] != 0 || data[offset + 49] != 0 { attributes += 1 }; triangles += 1
            }
            try add("Geometry", source, "encoding", "Binary STL")
            try add("Metadata", source, "header", String(data: data.prefix(80), encoding: .isoLatin1)?.trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? "")
            try add("Metadata", source, "facets with attribute bytes", String(attributes))
        } else {
            guard let text = String(data: data, encoding: .utf8) else { throw ModelImportError.invalid("Invalid or truncated STL.") }
            var stage = 0; var vertices = 0; var solid = false; var ended = false
            for line in text.split(whereSeparator: \.isNewline) {
                try check(); let t = line.split(whereSeparator: \.isWhitespace).map(String.init); guard let token = t.first else { continue }
                switch token {
                case "solid": try requireImport(stage == 0 && !solid, "Malformed ASCII STL."); solid = true; ended = false
                case "facet": try requireImport(solid && stage == 0 && t.count == 5 && t[1] == "normal" && t.dropFirst(2).allSatisfy { Double($0)?.isFinite == true }, "Malformed STL facet."); stage = 1
                case "outer": try requireImport(stage == 1 && t == ["outer", "loop"], "Malformed STL loop."); stage = 2; vertices = 0
                case "vertex": try requireImport(stage == 2 && vertices < 3 && t.count == 4, "Malformed STL vertex."); try bounds.vertex(t.dropFirst().map { Double($0) ?? .nan }); vertices += 1
                case "endloop": try requireImport(stage == 2 && vertices == 3 && t.count == 1, "Malformed STL loop."); stage = 3
                case "endfacet": try requireImport(stage == 3 && t.count == 1, "Malformed STL facet."); stage = 0; triangles += 1
                case "endsolid": try requireImport(solid && stage == 0, "Malformed STL solid."); solid = false; ended = true
                default: throw ModelImportError.invalid("Unrecognized or truncated STL data.")
                }
            }
            try requireImport(ended && !solid && stage == 0, "Truncated ASCII STL.")
            try add("Geometry", source, "encoding", "ASCII STL")
        }
        try requireImport(triangles > 0, "STL contains no triangles.")
        try add("Geometry", source, "triangles", String(triangles)); try add("Geometry", source, "bounds", bounds.description)
    }
}
private struct InspectionBounds {
    var min = [Double](repeating: .infinity, count: 3)
    var max = [Double](repeating: -.infinity, count: 3)
    mutating func vertex(_ value: [Double]) throws {
        try requireImport(value.count == 3 && value.allSatisfy(\.isFinite), "Nonfinite geometry coordinate.")
        for i in 0..<3 { min[i] = Swift.min(min[i], value[i]); max[i] = Swift.max(max[i], value[i]) }
    }
    var description: String { "min (\(min.map { String($0) }.joined(separator: ", "))); max (\(max.map { String($0) }.joined(separator: ", ")))" }
}
private final class InspectionXML: NSObject, XMLParserDelegate {
    let reader: InspectionReader; let source: String; let category: String; let model: Bool
    var error: Error?; var stack = [String](); var counts = [[String: Int]()]; var bodies = [String]()
    var bounds = InspectionBounds(); var vertices = 0; var triangles = 0; var objectPath = ""; var properties = [String: Int]()
    init(reader: InspectionReader, source: String, category: String, model: Bool) { self.reader = reader; self.source = source; self.category = category; self.model = model }
    func run(_ parser: XMLParser, _ action: () throws -> Void) { guard error == nil else { return }; do { try action() } catch { self.error = error; parser.abortParsing() } }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName qName: String?, attributes a: [String: String]) {
        run(parser) {
            try reader.check(); try requireImport(stack.count < 64, "XML nesting limit exceeded.")
            let index = (counts[counts.count - 1][name] ?? 0) + 1; counts[counts.count - 1][name] = index
            stack.append("\(name)[\(index)]"); counts.append([:]); bodies.append("")
            let tag = name.split(separator: ":").last.map(String.init) ?? name; let path = stack.joined(separator: "/")
            if model && stack.count == 1 { try requireImport(tag == "model", "Invalid 3MF model root.") }
            if model && tag == "object" { bounds = InspectionBounds(); vertices = 0; triangles = 0; properties = [:]; objectPath = path }
            if model && tag == "vertex" { try bounds.vertex(["x", "y", "z"].map { Double(a[$0] ?? "") ?? .nan }); vertices += 1 }
            else if model && tag == "triangle" {
                try requireImport(["v1", "v2", "v3"].allSatisfy { key in guard let index = Int(a[key] ?? "") else { return false }; return index >= 0 && index < vertices }, "Invalid triangle vertex reference.")
                triangles += 1
                for (key, value) in a where !["v1", "v2", "v3"].contains(key) { try requireImport(properties.count < 30_000, "Triangle property limit exceeded."); properties[key + "=" + value, default: 0] += 1 }
            } else {
                for key in a.keys.sorted() { try reader.add(category, source, path + "/@" + key, a[key]!) }
                if let key = a["key"], let value = a["value"] { try reader.add(category, source, path + "/" + key, value) }
            }
        }
    }
    func parser(_ parser: XMLParser, foundCharacters text: String) {
        run(parser) { if !bodies.isEmpty && !(model && ["vertices", "triangles"].contains(stack.last?.components(separatedBy: "[").first?.components(separatedBy: ":").last ?? "")) { try requireImport(bodies[bodies.count - 1].utf8.count + text.utf8.count <= 65_536, "XML text exceeds limit."); bodies[bodies.count - 1] += text } }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName qName: String?) {
        run(parser) {
            let body = bodies.removeLast().trimmingCharacters(in: .whitespacesAndNewlines)
            if !body.isEmpty { try reader.add(category, source, stack.joined(separator: "/"), body) }
            if model && name.split(separator: ":").last == "object" {
                try reader.add("Geometry", source, objectPath + "/vertices", String(vertices)); try reader.add("Geometry", source, objectPath + "/triangles", String(triangles))
                if vertices > 0 { try reader.add("Geometry", source, objectPath + "/local bounds", bounds.description) }
                for key in properties.keys.sorted() { try reader.add("Geometry", source, objectPath + "/triangle property " + key, String(properties[key]!)) }
            }
            stack.removeLast(); counts.removeLast()
        }
    }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? { error = ModelImportError.invalid("External entities are disabled."); parser.abortParsing(); return nil }
}
