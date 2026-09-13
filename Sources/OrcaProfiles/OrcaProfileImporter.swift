import Foundation
import CryptoKit
import QuoteDomain

public struct OrcaProfileDTO {
    public let path: String
    public let values: [String: Any]
    public init(path: String, data: Data) throws {
        self.path = path
        guard let object = try JSONSerialization.jsonObject(with:data) as? [String:Any] else { throw PricingError.invalid("Profile must be a JSON object: \(path)") }
        values = object
    }
    public var name: String { values["name"] as? String ?? "" }
    public var vendor: String { path.split(separator:"/").dropFirst(2).first.map(String.init) ?? "Unknown" }
}
public final class OrcaProfileImporter {
    private let records: [String: OrcaProfileDTO]
    private let names: [String: [String]]
    public init(records: [OrcaProfileDTO]) throws {
        guard Set(records.map(\.path)).count == records.count else { throw PricingError.invalid("Duplicate profile paths.") }
        self.records = Dictionary(uniqueKeysWithValues:records.map {($0.path,$0)})
        self.names = Dictionary(grouping:records.filter {!$0.name.isEmpty},by: \.name).mapValues {$0.map(\.path)}
    }
    private func resolve(_ path: String, visiting: Set<String> = []) throws -> (values: [String:Any], paths: [String], origins: [String:String]) {
        guard !visiting.contains(path), visiting.count < 64 else { throw PricingError.invalid("Inheritance cycle/depth limit at \(path)") }
        guard let dto = records[path] else { throw PricingError.invalid("Missing profile: \(path)") }
        guard let parentName = dto.values["inherits"] as? String, !parentName.isEmpty else { return (dto.values,[],Dictionary(uniqueKeysWithValues:dto.values.keys.map {($0,path)})) }
        let candidates = names[parentName] ?? []
        let sameVendor = candidates.filter {records[$0]?.vendor == dto.vendor && records[$0]?.values["type"] as? String == dto.values["type"] as? String}
        let matches = sameVendor.isEmpty ? candidates : sameVendor
        guard matches.count == 1, let parent = matches.first else { throw PricingError.invalid("Missing or ambiguous parent \(parentName) for \(path)") }
        var visited = visiting; visited.insert(path)
        let resolved = try resolve(parent,visiting:visited)
        return (resolved.values.merging(dto.values) {_,new in new},resolved.paths + [parent],resolved.origins.merging(Dictionary(uniqueKeysWithValues:dto.values.keys.map {($0,path)})) {_,new in new})
    }
    public func importProfiles(paths: [String], commitSHA: String, importedAt: Date = Date()) throws -> TechnicalProfileCatalog {
        guard commitSHA.count == 40, commitSHA.allSatisfy({$0.isHexDigit}) else { throw PricingError.invalid("An exact 40-character upstream commit SHA is required.") }
        var profiles: [NormalizedTechnicalProfile] = []; var diagnostics: [String] = []
        for path in paths.sorted() {
            do {
                guard let dto = records[path] else { throw PricingError.invalid("Missing selected file \(path)") }
                let resolved = try resolve(path)
                let source = ExternalProfileSource(sourcePath:path,inheritedPaths:resolved.paths,commitSHA:commitSHA,importedAt:importedAt)
                var profile = try OrcaProfileMapper.map(dto:dto,resolved:resolved.values,source:source)
                profile.fieldSourcePaths = resolved.origins.filter { profile.technicalValues[$0.key] != nil || ["name","type","printer_model","filament_type","printable_height","nozzle_diameter","toolhead_count"].contains($0.key) }
                profiles.append(profile)
            } catch { diagnostics.append("\(path): \(error.localizedDescription)") }
        }
        return TechnicalProfileCatalog(profiles:profiles,diagnostics:diagnostics)
    }
}
public enum OrcaProfileMapper {
    public static func map(dto: OrcaProfileDTO, resolved v: [String:Any], source: ExternalProfileSource) throws -> NormalizedTechnicalProfile {
        func strings(_ key:String) -> [String] {
            if let a = v[key] as? [String] { return a }
            if let s = v[key] as? String { return [s] }
            if let n = v[key] as? NSNumber { return [n.stringValue] }
            if let a = v[key] as? [NSNumber] { return a.map(\.stringValue) }
            return []
        }
        func scalar(_ key:String) -> String? { strings(key).first }
        func positive(_ key:String) -> Double? { guard let x=scalar(key).flatMap(Double.init),x.isFinite,x>0 else {return nil}; return x }
        let kind = scalar("type") ?? ""
        guard ["machine","filament"].contains(kind), !dto.name.isEmpty else { throw PricingError.invalid("Unsupported profile type or missing name.") }
        let allowed = ["printer_variant","nozzle_temperature","nozzle_temperature_initial_layer","nozzle_temperature_range_low","nozzle_temperature_range_high","hot_plate_temp","textured_plate_temp","cool_plate_temp","chamber_temperature","fan_min_speed","fan_max_speed","filament_max_volumetric_speed","filament_density","filament_flow_ratio","filament_shrink","compatible_printers","default_print_profile","default_filament_profile","gcode_flavor","nozzle_type","printable_area","bed_exclude_area","physical_extruder_map","extruder_offset"]
        let technical = Dictionary(uniqueKeysWithValues:allowed.compactMap {key -> (String,[String])? in let values = strings(key); return values.isEmpty ? nil : (key,values)})
        var reasons: [String] = []
        var x:Double?; var y:Double?
        let points = strings("printable_area").compactMap {point -> (Double,Double)? in let xy=point.split(separator:"x"); guard xy.count==2,let a=Double(xy[0]),let b=Double(xy[1]),a.isFinite,b.isFinite else {return nil}; return (a,b) }
        if points.count >= 3, points.count == strings("printable_area").count {
            x = points.map {$0.0}.max()! - points.map {$0.0}.min()!; y = points.map {$0.1}.max()! - points.map {$0.1}.min()!
            reasons.append("Build X/Y are bounding extents; exclusions and nonrectangular bed geometry require review.")
        }
        let toolCount = scalar("toolhead_count").flatMap(Int.init).flatMap {(1...12).contains($0) ? $0 : nil}
        if kind == "machine" && toolCount == nil { reasons.append("Physical toolhead count is unknown. Extruder/nozzle arrays and feeder slots are not interpreted as physical toolheads.") }
        if kind == "machine" && (x == nil || y == nil || positive("printable_height") == nil) { reasons.append("Incomplete build dimensions.") }
        reasons.append("Technical profile only; purchase prices, power draw and shop rates require user entry.")
        let digest = Array(SHA256.hash(data:Data(("OrcaSlicer/" + dto.path).utf8)).prefix(16))
        var bytes = digest; bytes[6] = (bytes[6] & 0x0f) | 0x50; bytes[8] = (bytes[8] & 0x3f) | 0x80
        let hex = bytes.map {String(format:"%02x",$0)}.joined()
        let formatted = "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20))"
        return NormalizedTechnicalProfile(id:UUID(uuidString:formatted)!,kind:kind,vendor:dto.vendor,name:dto.name,model:scalar("printer_model"),materialFamily:scalar("filament_type"),buildXMM:x,buildYMM:y,buildZMM:positive("printable_height"),nozzleDiametersMM:strings("nozzle_diameter").compactMap(Double.init).filter {$0.isFinite && $0>0},physicalToolheadCount:toolCount,technicalValues:technical,source:source,reviewReasons:reasons)
    }
}
