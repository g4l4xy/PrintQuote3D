import Foundation
import OrcaProfiles

// Local-only CLI. Update script supplies a clean, pinned upstream checkout.
let args = Array(CommandLine.arguments.dropFirst())
func option(_ name:String) -> String? { guard let i=args.firstIndex(of:name), i+1<args.count else {return nil}; return args[i+1] }
do {
    guard let root=option("--profiles"),let sha=option("--commit"),let selection=option("--selection"),let output=option("--output") else { throw NSError(domain:"Usage: swift run OrcaProfileImporter --profiles PATH/resources/profiles --commit SHA --selection paths.json --output catalog.json",code:1) }
    let rootURL=URL(fileURLWithPath:root).standardizedFileURL
    var selected = try JSONDecoder().decode([String].self,from:Data(contentsOf:URL(fileURLWithPath:selection)))
    guard let enumerator=FileManager.default.enumerator(at:rootURL,includingPropertiesForKeys:[.isRegularFileKey],options:[.skipsHiddenFiles]) else { throw NSError(domain:"Cannot read profiles",code:2) }
    // Vendor manifests define active profiles; backup JSON files are not inheritance candidates.
    var registered = Set<String>()
    for url in try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil) where url.pathExtension == "json" {
        guard let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any] else { continue }
        for key in ["machine_list", "filament_list"] {
            for entry in manifest[key] as? [[String: String]] ?? [] {
                if let path = entry["sub_path"] { registered.insert("resources/profiles/" + url.deletingPathExtension().lastPathComponent + "/" + path) }
            }
        }
    }
    var records:[OrcaProfileDTO]=[]
    for case let url as URL in enumerator where url.pathExtension == "json" {
        guard try url.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile == true else {continue}
        let relative = "resources/profiles/" + url.path.dropFirst(rootURL.path.count+1)
        guard registered.contains(relative) else { continue }
        // Vendor manifests are not individual profiles.
        if let dto=try? OrcaProfileDTO(path:relative,data:Data(contentsOf:url)), !dto.name.isEmpty { records.append(dto) }
    }
    if args.contains("--all-printers") {
        selected = selected.filter { !$0.contains("/machine/") }
        selected += records.filter { $0.values["type"] as? String == "machine" && $0.values["instantiation"] as? String == "true" }.map(\.path)
    }
    let catalog = try OrcaProfileImporter(records:records).importProfiles(paths:selected,commitSHA:sha)
    let encoder=JSONEncoder(); encoder.outputFormatting=[.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
    try encoder.encode(catalog).write(to:URL(fileURLWithPath:output),options:.atomic)
    print("Imported \(catalog.profiles.count) profiles; \(catalog.diagnostics.count) diagnostics.")
    for diagnostic in catalog.diagnostics { print(diagnostic) }
    if !catalog.diagnostics.isEmpty { exit(2) }
} catch { FileHandle.standardError.write(Data(("\(error)\n").utf8)); exit(1) }
