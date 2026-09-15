import Foundation
import QuoteDomain
#if canImport(FoundationXML)
import FoundationXML
#endif

final class SecureThreeMFXML: NSObject, XMLParserDelegate {
    let context: ThreeMFContext
    let start: (String, [String: String], String) throws -> Void
    let end: (String, String, String) throws -> Void
    var names = [String](); var counts = [[String: Int]()]; var paths = [String](); var texts = [String]()
    var failure: Error?
    init(context: ThreeMFContext, start: @escaping (String, [String: String], String) throws -> Void, end: @escaping (String, String, String) throws -> Void) { self.context = context; self.start = start; self.end = end }
    static func parse(_ data: Data, context: ThreeMFContext, start: @escaping (String, [String: String], String) throws -> Void, end: @escaping (String, String, String) throws -> Void = { _,_,_ in }) throws {
        try context.check()
        guard String(data: data, encoding: .utf8) != nil, !data.contains(0) else { throw ThreeMFFailure.damaged("XML must use valid UTF-8.") }
        guard data.range(of: Data("<!DOCTYPE".utf8)) == nil, data.range(of: Data("<!ENTITY".utf8)) == nil else { throw ThreeMFFailure.security("DTD and entity declarations are prohibited.") }
        let delegate = SecureThreeMFXML(context: context, start: start, end: end)
        let parser = XMLParser(data: data); parser.delegate = delegate; parser.shouldResolveExternalEntities = false
        let success = parser.parse()
        if let error = delegate.failure { throw error }
        if !success { throw ThreeMFFailure.damaged("Malformed XML (line \(parser.lineNumber)).") }
    }
    func run(_ parser: XMLParser, _ action: () throws -> Void) { if failure != nil { return }; do { try context.check(); try action() } catch { failure = error; parser.abortParsing() } }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String]) {
        run(parser) {
            guard names.count < context.limits.xmlDepth else { throw ThreeMFFailure.security("XML depth limit exceeded.") }
            guard counts[counts.count-1].count < 4096 || counts[counts.count-1][name] != nil else {throw ThreeMFFailure.security("Excessive distinct XML sibling names.")}
            let n = (counts[counts.count - 1][name] ?? 0) + 1; counts[counts.count - 1][name] = n
            paths.append("\(name)[\(n)]"); names.append(name); counts.append([:]); texts.append("")
            try start(name.components(separatedBy: ":").last!, a, paths.joined(separator: "/"))
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        run(parser) {
            guard !texts.isEmpty else { return }
            if ["vertices", "triangles", "mesh", "resources", "build", "components"].contains(names.last!.components(separatedBy: ":").last!) && string.allSatisfy(\.isWhitespace) { return }
            guard texts[texts.count - 1].utf8.count + string.utf8.count <= 65_536 else { throw ThreeMFFailure.security("XML text-node limit exceeded.") }
            texts[texts.count - 1] += string
        }
    }
    func parser(_ parser: XMLParser, foundCDATA data: Data) { if let text = String(data: data, encoding: .utf8) { self.parser(parser, foundCharacters: text) } else { failure = ThreeMFFailure.damaged("Invalid CDATA."); parser.abortParsing() } }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        run(parser) { try end(name.components(separatedBy: ":").last!, texts.removeLast(), paths.joined(separator: "/")); names.removeLast(); paths.removeLast(); counts.removeLast() }
    }
    func parser(_ parser: XMLParser, resolveExternalEntityName name: String, systemID: String?) -> Data? { failure = ThreeMFFailure.security("External entities are disabled."); parser.abortParsing(); return nil }
}

enum ThreeMFContainerReader {
    static func inspect(_ reader: SafeArchiveReader, context: ThreeMFContext) throws -> ThreeMFContainerManifest {
        var result = ThreeMFContainerManifest(); result.entries = reader.paths
        for path in reader.paths where path.hasSuffix(".rels") || path == "[Content_Types].xml" {
            do {
                let data = try reader.read(path)
                try SecureThreeMFXML.parse(data, context: context, start: { name, a, _ in
                    if name == "Override", let part = a["PartName"], let type = a["ContentType"] { result.contentTypes[part.trimmingCharacters(in: CharacterSet(charactersIn: "/"))] = type }
                    if name == "Relationship", let target = a["Target"], let type = a["Type"] {
                        let external = a["TargetMode"]?.lowercased() == "external"
                        var owner = ""
                        if path != "_rels/.rels" { owner = path.replacingOccurrences(of: "/_rels/", with: "/"); owner = String(owner.dropLast(5)) }
                        if external { result.relationships.append(.init(source: owner, target: target, type: type, external: true)); context.diagnostic(.warning, "3MF.Container", "externalRelationship", "External relationship retained but never fetched.", path: path); return }
                        let resolved = try SafeArchiveReader.resolve(target, relativeTo: owner)
                        result.relationships.append(.init(source: owner, target: resolved, type: type, external: false))
                        if path == "_rels/.rels" && type.hasSuffix("/3dmodel") { result.roots.append(resolved) }
                        if !reader.paths.contains(resolved) { context.diagnostic(.recoverableError, "3MF.Container", "missingPart", "Relationship target is absent: \(resolved)", path: path) }
                    }
                })
            } catch is CancellationError { throw CancellationError() }
              catch ThreeMFFailure.security(let s) { throw ThreeMFFailure.security(s) }
              catch { context.diagnostic(.recoverableError, "3MF.Container", "manifest", error.localizedDescription, path: path) }
        }
        if result.roots.isEmpty {
            result.roots = reader.paths.filter { result.contentTypes[$0]?.contains("3dmodel") == true }
            if result.roots.isEmpty { result.roots = reader.paths.filter { $0.lowercased().hasSuffix(".model") && !$0.lowercased().contains("/objects/") }.sorted() }
            context.diagnostic(.warning, "3MF.Container", "rootFallback", "No usable package model relationship; model roots selected by content type or model-part extension. Review build membership.")
        }
        return result
    }
}
struct MFVector {
    var x: Double; var y: Double; var z: Double
    var array: [Double] { [x,y,z] }
    static let zero = MFVector(x: 0,y: 0,z: 0)
    static func -(a: Self, b: Self) -> Self { .init(x:a.x-b.x,y:a.y-b.y,z:a.z-b.z) }
    func cross(_ b: Self) -> Self { .init(x:y*b.z-z*b.y,y:z*b.x-x*b.z,z:x*b.y-y*b.x) }
    func dot(_ b: Self) -> Double { x*b.x+y*b.y+z*b.z }
    var length: Double { sqrt(dot(self)) }
}
struct MFTransform {
    var values: [Double]
    static let identity = MFTransform(values: [1,0,0,0,1,0,0,0,1,0,0,0])
    init(values: [Double]) { self.values = values }
    init(_ source: String?, unitScale: Double) throws {
        guard let source else { self = .identity; return }
        let v = source.split(whereSeparator: \.isWhitespace).compactMap { Double($0) }
        guard v.count == 12, v.allSatisfy(\.isFinite) else { throw ThreeMFFailure.damaged("Invalid affine transform; expected 12 finite values.") }
        self.values = v; for i in 9...11 { values[i] *= unitScale }
        guard determinant.isFinite, determinant != 0, values.allSatisfy(\.isFinite) else { throw ThreeMFFailure.damaged("Singular or overflowing transform.") }
    }
    func apply(_ p: MFVector) -> MFVector { .init(x:values[0]*p.x+values[3]*p.y+values[6]*p.z+values[9],y:values[1]*p.x+values[4]*p.y+values[7]*p.z+values[10],z:values[2]*p.x+values[5]*p.y+values[8]*p.z+values[11]) }
    func then(_ next: Self) -> Self {
        // Compose matrix coefficients directly. Subtracting transformed basis points
        // loses scale/rotation when a large translation consumes floating-point precision.
        var result=[Double](repeating:0,count:12)
        for row in 0..<3 { for col in 0..<3 {
            for k in 0..<3 {result[row*3+col] += values[row*3+k]*next.values[k*3+col]}
        }}
        for col in 0..<3 {
            result[9+col]=next.values[9+col]
            for k in 0..<3 {result[9+col] += values[9+k]*next.values[k*3+col]}
        }
        return .init(values:result)
    }
    var determinant: Double { MFVector(x:values[0],y:values[1],z:values[2]).dot(MFVector(x:values[3],y:values[4],z:values[5]).cross(.init(x:values[6],y:values[7],z:values[8]))) }
}
struct MFTriangle { var a: Int; var b: Int; var c: Int }
struct MFReference { var object: String; var transform: MFTransform }
struct MFResource {
    var id: String; var name: String?; var role: String; var path: String; var unit: String
    var vertices: [MFVector] = []; var triangles: [MFTriangle] = []; var components: [MFReference] = []
    var valid = true
}
struct MFStandardResult {
    var resources: [String: MFResource] = [:]
    var builds: [String: [MFReference]] = [:]
    var metadata: [UnmappedThreeMFMetadata] = []
    var materials: [ImportedMaterial] = []
    var assignments: [ImportedAssignment] = []
}
enum StandardThreeMFParser {
    static func parse(_ reader: SafeArchiveReader, manifest: ThreeMFContainerManifest, context: ThreeMFContext) throws -> MFStandardResult {
        var output = MFStandardResult()
        let paths = reader.paths.filter { $0.lowercased().hasSuffix(".model") || manifest.contentTypes[$0]?.contains("3dmodel") == true }
        for (index, path) in paths.enumerated() {
            context.progress(.init("Parsing model", 0.15 + 0.3 * Double(index) / Double(max(1,paths.count))))
            var current: MFResource?; var unit = "millimeter"; var scale = 1.0; var metadataKey: String?; var propertyID = ""; var propertyIndex = 0; var objectDepth: String?
            var namespace = [String: String]()
            func retain(_ record: UnmappedThreeMFMetadata) throws { try context.retain(record); output.metadata.append(record) }
            do {
                let data = try reader.read(path, metadata: false)
                try SecureThreeMFXML.parse(data, context: context, start: { name, a, scope in
                    if scope.split(separator: "/").count == 1 {
                        guard name == "model" else { throw ThreeMFFailure.damaged("Invalid model root.") }
                        unit = a["unit"] ?? "millimeter"
                        guard let s = ["micron":0.001,"micrometer":0.001,"millimeter":1.0,"centimeter":10.0,"inch":25.4,"foot":304.8,"meter":1000.0][unit] else { throw ThreeMFFailure.damaged("Unsupported model unit: \(unit)") }; scale = s
                        namespace = a.filter { $0.key.hasPrefix("xmlns") }
                        if let extensions = a["requiredextensions"], !extensions.isEmpty {
                            context.diagnostic(.warning,"3MF.XML","requiredExtensions","Required extensions declared: \(extensions). Core geometry is available; extension-specific manufacturing semantics require review.",path:path)
                        }
                    }
                    let tag = scope.split(separator:"/").last?.split(separator:"[").first.map(String.init) ?? name
                    if let colon=tag.firstIndex(of:":"), namespace["xmlns:"+String(tag[..<colon])] != "http://schemas.microsoft.com/3dmanufacturing/core/2015/02" {
                        for (key,value) in a {try retain(.init(path:path,scope:scope,key:key,value:value,namespace:namespace["xmlns:"+String(tag[..<colon])]))}
                        return
                    }
                    if name == "object" {
                        guard current == nil else { throw ThreeMFFailure.damaged("Nested object resources are invalid.") }
                        guard output.resources.count < context.limits.objectCount else { throw ThreeMFFailure.security("Object count limit exceeded.") }
                        guard let raw = a["id"], Int(raw).map({ $0 > 0 }) == true else { throw ThreeMFFailure.damaged("Object has no valid resource ID.") }
                        let id = path + "#" + raw
                        current = .init(id: id, name: a["name"], role: a["type"] ?? "model", path: path, unit: unit); objectDepth = scope
                        if output.resources[id] != nil { current?.valid = false; context.diagnostic(.recoverableError,"3MF.Geometry","duplicateObject","Duplicate resource ID; first object retained.",path:path) }
                    }
                    if name == "vertex", current != nil {
                        context.vertexCount += 1; guard context.vertexCount <= context.limits.vertexCount else { throw ThreeMFFailure.security("Vertex count limit exceeded.") }
                        let xyz = ["x","y","z"].map { Double(a[$0] ?? "") ?? .nan }.map { $0 * scale }
                        if xyz.allSatisfy(\.isFinite) { current!.vertices.append(.init(x:xyz[0],y:xyz[1],z:xyz[2])) } else { current?.valid = false; current!.vertices.append(.zero) }
                    } else if name == "triangle", current != nil {
                        context.triangleCount += 1; guard context.triangleCount <= context.limits.triangleCount else { throw ThreeMFFailure.security("Triangle count limit exceeded.") }
                        let indices = ["v1","v2","v3"].map { Int(a[$0] ?? "") ?? -1 }
                        if indices.allSatisfy({ $0 >= 0 && $0 < current!.vertices.count }) { current!.triangles.append(.init(a:indices[0],b:indices[1],c:indices[2])) } else { current?.valid = false }
                        // Preserve per-face property/paint evidence without dropping its face scope.
                        for (key,value) in a where !["v1","v2","v3"].contains(key) { try retain(.init(path:path,scope:scope,key:key,value:value,namespace:namespace["xmlns:" + key.components(separatedBy: ":")[0]])) }
                    } else {
                        if name == "component" || name == "item" {
                            do {
                                guard let raw = a["objectid"] else { throw ThreeMFFailure.damaged("Missing referenced object ID.") }
                                let external = a.first { $0.key.hasSuffix(":path") }?.value
                                let part = try external.map { try SafeArchiveReader.resolve($0, relativeTo: path) } ?? path
                                let reference = MFReference(object: part + "#" + raw, transform: try .init(a["transform"],unitScale:scale))
                                if name == "component" { current?.components.append(reference) } else { output.builds[path,default:[]].append(reference) }
                            } catch ThreeMFFailure.security(let s) { throw ThreeMFFailure.security(s) }
                              catch { context.diagnostic(.recoverableError,"3MF.Geometry","invalidReference",error.localizedDescription,path:path) }
                        }
                        if name == "basematerials" || name == "colorgroup" { propertyID = a["id"] ?? "unknown"; propertyIndex = 0 }
                        if name == "base" || name == "color" {
                            var material = ImportedMaterial(id: path + "#" + propertyID + "/" + String(propertyIndex)); propertyIndex += 1
                            if let value = a["name"] { material.productName = .init(value,path:path,key:scope+"/@name",type:.standard3MF) }
                            if let value = a["displaycolor"] ?? a["color"] { material.sourceColorHex = .init(value,path:path,key:scope,type:.standard3MF); material.normalizedColorHex = ThreeMFMetadataRouter.color(value) }
                            output.materials.append(material)
                        }
                        if name == "metadata" { metadataKey = a["name"] ?? a["key"] }
                        for (key,value) in a { try retain(.init(path:path,scope:scope,key:key,value:value,namespace:namespace["xmlns:" + key.components(separatedBy: ":")[0]])) }
                        if let pid = a["pid"], let pindex = a["pindex"] { output.assignments.append(.init(scope:current?.id ?? scope,role:"object",materialID:path+"#"+pid+"/"+pindex,source:.init(pid+"/"+pindex,path:path,key:scope,type:.standard3MF))) }
                    }
                }, end: { name, text, scope in
                    let tag=scope.split(separator:"/").last?.split(separator:"[").first.map(String.init) ?? name
                    if let colon=tag.firstIndex(of:":"), namespace["xmlns:"+String(tag[..<colon])] != "http://schemas.microsoft.com/3dmanufacturing/core/2015/02" {
                        if !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {try retain(.init(path:path,scope:scope,key:"text",value:text))};return
                    }
                    if name == "metadata", let key = metadataKey { try retain(.init(path:path,scope:scope,key:key,value:text)); metadataKey = nil }
                    if name == "object", scope == objectDepth, let resource = current {
                        if resource.valid { output.resources[resource.id] = resource } else { context.diagnostic(.recoverableError,"3MF.Geometry","invalidObject","Object geometry is invalid; valid sibling objects remain available.",path:resource.id) }
                        current = nil; objectDepth = nil
                    }
                })
            } catch is CancellationError { throw CancellationError() }
              catch ThreeMFFailure.security(let s) { throw ThreeMFFailure.security(s) }
              catch { context.diagnostic(.recoverableError,"3MF.XML","modelSection",error.localizedDescription,path:path) }
        }
        return output
    }
    static func geometry(_ model: MFStandardResult, roots: [String], context: ThreeMFContext) throws -> [ImportedObject] {
        var output = model.resources.values.sorted { $0.id < $1.id }.map { r -> ImportedObject in
            var o = ImportedObject(id:r.id,resourceID:r.id,sourcePath:r.path,role:r.role,triangleCount:r.triangles.count,unit:r.unit); o.name = r.name; o.children = r.components.map(\.object); return o
        }
        var instances = 0
        func visit(_ reference: MFReference, parent: String?, outer: MFTransform, ancestry: Set<String>, depth: Int) throws {
            try context.check()
            guard depth <= context.limits.referenceDepth, !ancestry.contains(reference.object) else { context.diagnostic(.recoverableError,"3MF.Geometry","referenceCycle","Recursive or excessively deep component reference skipped.",path:reference.object); return }
            guard let r = model.resources[reference.object] else { context.diagnostic(.recoverableError,"3MF.Geometry","missingObject","Referenced object is unavailable.",path:reference.object); return }
            instances += 1; guard instances <= context.limits.instanceCount else { throw ThreeMFFailure.security("Expanded instance count exceeded.") }
            let id = "instance:\(instances)"; let transform = reference.transform.then(outer)
            guard transform.values.allSatisfy(\.isFinite) else { context.diagnostic(.recoverableError,"3MF.Geometry","transformOverflow","Transform overflow; instance skipped.",path:r.id); return }
            var item = ImportedObject(id:id,resourceID:r.id,sourcePath:r.path,role:r.role,triangleCount:r.triangles.count,unit:r.unit); item.parentID = parent; item.name = r.name; item.sourceTransform = transform.values; item.mirrored = transform.determinant < 0; item.instanceCount = 1
            if !r.triangles.isEmpty {
                var low = [Double](repeating:.infinity,count:3); var high = [Double](repeating:-.infinity,count:3); var area = 0.0; var volume = 0.0
                struct Edge: Hashable { var a: Int; var b: Int }
                var edges = [Edge:(count:Int,direction:Int)]()
                let validateVolume = r.triangles.count <= 50_000
                let anchor=transform.apply(r.vertices[0])
                for t in r.triangles {
                    try context.check(); let points = [t.a,t.b,t.c].map { transform.apply(r.vertices[$0]) }
                    guard points.allSatisfy({ $0.array.allSatisfy(\.isFinite) }) else { context.diagnostic(.recoverableError,"3MF.Geometry","measurementOverflow","Nonfinite transformed geometry; this instance was skipped.",path:r.id); return }
                    for p in points { for i in 0..<3 { low[i] = min(low[i],p.array[i]); high[i] = max(high[i],p.array[i]) } }
                    area += (points[1]-points[0]).cross(points[2]-points[0]).length / 2
                    volume += (points[0]-anchor).dot((points[1]-anchor).cross(points[2]-anchor)) / 6
                    if validateVolume { for (a,b) in [(t.a,t.b),(t.b,t.c),(t.c,t.a)] { let key = Edge(a:min(a,b),b:max(a,b)); let old = edges[key] ?? (0,0); edges[key] = (old.count+1,old.direction+(a < b ? 1 : -1)) } }
                }
                guard area.isFinite, volume.isFinite, zip(high,low).allSatisfy({ ($0-$1).isFinite }) else { context.diagnostic(.recoverableError,"3MF.Geometry","measurementOverflow","Geometry measurement overflow; this instance was skipped.",path:r.id); return }
                item.boundsMM = .init(.init(minimum:low,maximum:high),path:r.path,key:r.id,type:.derived)
                item.surfaceAreaMM2 = .init(area,path:r.path,key:r.id,type:.derived)
                if validateVolume && area>0 && edges.values.allSatisfy({ $0.count == 2 && $0.direction == 0 }) { item.enclosedVolumeMM3 = .init(abs(volume),path:r.path,key:r.id,type:.derived,confidence:.medium) }
                else { context.diagnostic(.warning,"3MF.Geometry","volumeUnknown","Volume withheld: mesh is open/inconsistently oriented or exceeds the topology-check budget. Surface area is triangle area, not a printable-material estimate.",path:r.id) }
            }
            output.append(item)
            if let parent, let i = output.firstIndex(where: { $0.id == parent }) { output[i].children.append(id) }
            if let i = output.firstIndex(where: { $0.id == r.id }) { output[i].instanceCount += 1 }
            for component in r.components { try visit(component,parent:id,outer:transform,ancestry:ancestry.union([r.id]),depth:depth+1) }
            if !r.components.isEmpty, let index=output.firstIndex(where:{$0.id==id}) {
                let children=output.filter{$0.parentID==id}
                let boxes=children.compactMap{$0.boundsMM?.value} + [item.boundsMM?.value].compactMap{$0}
                if let first=boxes.first {
                    var low=first.minimum;var high=first.maximum
                    for box in boxes.dropFirst(){for axis in 0..<3{low[axis]=min(low[axis],box.minimum[axis]);high[axis]=max(high[axis],box.maximum[axis])}}
                    output[index].boundsMM = .init(.init(minimum:low,maximum:high),path:r.path,key:r.id,type:.derived)
                }
                output[index].triangleCount += children.reduce(0){$0+$1.triangleCount}
            }
        }
        for root in roots { for item in model.builds[root] ?? [] { try visit(item,parent:nil,outer:.identity,ancestry:[],depth:0) } }
        if instances == 0 { context.diagnostic(.warning,"3MF.Geometry","emptyBuild","Model resources were read, but no build instances are available for pricing.") }
        return output
    }
}
