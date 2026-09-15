import Foundation
import QuoteDomain
import ImageIO

struct MFMetadataRecord {
    var raw: UnmappedThreeMFMetadata
    var key: String { raw.key }
    var value: String { raw.value ?? "" }
    func imported(_ type: ImportSourceType = .slicerMetadata, confidence: ImportConfidence = .high) -> ImportedValue<String> { .init(value,path:raw.sourcePath,key:raw.scope+"/"+key,type:type,confidence:confidence) }
}
enum ThreeMFMetadataRouter {
    static func color(_ value: String) -> String? {
        let raw = value.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:"#",with:"")
        guard [6,8].contains(raw.count), raw.allSatisfy(\.isHexDigit) else { return nil }; return "#" + raw.uppercased()
    }
    static func values(_ text: String) -> [String] {
        if let data = text.data(using:.utf8), let array = try? JSONSerialization.jsonObject(with:data) as? [Any] { return array.prefix(1024).map { String(describing:$0) } }
        var output = [String](); var current = ""; var quoted = false; var escaped = false
        for c in text {
            if escaped { current.append(c); escaped = false; continue }
            if c == "\\" && quoted { escaped = true; continue }
            if c == "\"" { quoted.toggle(); continue }
            if (c == ";" || c == ",") && !quoted { output.append(current.trimmingCharacters(in:.whitespaces)); current = ""; if output.count>=1024{return output} } else { current.append(c) }
        }
        output.append(current.trimmingCharacters(in:.whitespaces)); return output
    }
    static func read(_ reader: SafeArchiveReader, manifest: ThreeMFContainerManifest, standard: MFStandardResult, context: ThreeMFContext) throws -> [MFMetadataRecord] {
        var records = standard.metadata.map { MFMetadataRecord(raw:$0) }
        for (index,path) in reader.paths.enumerated() where !path.hasSuffix(".model") && !path.hasSuffix(".rels") && path != "[Content_Types].xml" && manifest.contentTypes[path]?.contains("3dmodel") != true && !path.hasSuffix("/") {
            context.progress(.init("Parsing metadata",0.5+0.15*Double(index)/Double(max(1,reader.paths.count))))
            let ext = (path as NSString).pathExtension.lowercased()
            let imagePart = ["png","jpg","jpeg"].contains(ext)
            let textPart = ["config","json","xml","ini","gcode","txt"].contains(ext)
            func retain(_ scope: String, _ key: String, _ value: String) throws {
                let raw = UnmappedThreeMFMetadata(path:path,scope:scope,key:key,value:value); try context.retain(raw); records.append(.init(raw:raw))
            }
            do {
                let data = try reader.read(path,metadata:textPart && ext != "gcode",retain:textPart || imagePart)
                if imagePart {
                    guard let image=CGImageSourceCreateWithData(data as CFData,[kCGImageSourceShouldCache:false] as CFDictionary),CGImageSourceGetCount(image)>0 else {throw ThreeMFFailure.damaged("Invalid optional thumbnail/image header.")}
                    continue // Validate headers without allocating decoded pixel buffers.
                }
                guard textPart else { continue }
                guard var text = String(data:data,encoding:.utf8), !text.contains("\0") else { throw ThreeMFFailure.damaged("Invalid UTF-8 metadata.") }
                if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
                let trimmed = text.trimmingCharacters(in:.whitespacesAndNewlines)
                if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                    var depth = 0; var quoted = false; var escaped = false
                    for (i,c) in text.enumerated() { if i%4096 == 0 { try context.check() }; if escaped { escaped=false;continue };if c == "\\" && quoted { escaped=true;continue };if c == "\"" {quoted.toggle()};if !quoted {if c == "{" || c == "[" {depth+=1;if depth>context.limits.xmlDepth {throw ThreeMFFailure.security("JSON depth limit exceeded.")}};if c == "}" || c == "]" {depth-=1}} }
                    let decoded = try JSONSerialization.jsonObject(with:Data(text.utf8))
                    func walk(_ value: Any, scope: String) throws {
                        try context.check()
                        if let object = value as? [String:Any] {
                            for key in object.keys.sorted() {
                                let value = object[key]!
                                if value is [String:Any] { try walk(value,scope:scope+"/"+key) }
                                else if let a = value as? [Any], a.contains(where: { $0 is [String:Any] }) { for (i,item) in a.enumerated() { try walk(item,scope:scope+"/\(key)[\(i)]") } }
                                else if value is [Any] { try retain(scope,key,String(data:try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]),encoding:.utf8)!) }
                                else { try retain(scope,key,String(describing:value)) }
                            }
                        } else if let array = value as? [Any] { for (i,value) in array.enumerated() { try walk(value,scope:scope+"[\(i)]") } }
                        else { try retain(scope,"value",String(describing:value)) }
                    }
                    try walk(decoded,scope:"project")
                } else if trimmed.hasPrefix("<") {
                    var attributes = [[String:String]]()
                    try SecureThreeMFXML.parse(data,context:context,start:{ name,a,scope in
                        attributes.append(a)
                        if let key = a["key"] ?? a["name"], let value = a["value"] { try retain(scope,key,value) }
                        for key in a.keys.sorted() where !["key","value","name"].contains(key) { try retain(scope,key,a[key]!) }
                        if let nameValue = a["name"], a["value"] == nil { try retain(scope,"name",nameValue) }
                    },end:{ _,text,scope in
                        let a=attributes.removeLast(); let value=text.trimmingCharacters(in:.whitespacesAndNewlines)
                        if !value.isEmpty { try retain(scope,a["key"] ?? a["name"] ?? "text",value) }
                    })
                } else {
                    for (lineNumber,line) in text.split(whereSeparator:\.isNewline).enumerated() {
                        try context.check(); let clean=line.trimmingCharacters(in:.whitespaces).trimmingCharacters(in:CharacterSet(charactersIn:"; "))
                        if let delimiter=clean.firstIndex(of:"=") ?? clean.firstIndex(of:":") { try retain(ext == "gcode" ? "gcode/line[\(lineNumber+1)]" : "project",String(clean[..<delimiter]).trimmingCharacters(in:.whitespaces),String(clean[clean.index(after:delimiter)...]).trimmingCharacters(in:.whitespaces)) }
                        else if ext != "gcode" && !clean.isEmpty { try retain("line[\(lineNumber+1)]","text",clean) }
                    }
                }
            } catch is CancellationError { throw CancellationError() }
              catch ThreeMFFailure.security(let s) { throw ThreeMFFailure.security(s) }
              catch { context.diagnostic(.recoverableError,textPart ? "3MF.Metadata" : "3MF.Container","optionalPart",error.localizedDescription,path:path) }
        }
        return records
    }
}
enum ThreeMFSlicerDetector {
    static func detect(_ records: [MFMetadataRecord], paths: [String]) -> DetectedSlicer {
        var result=DetectedSlicer()
        let keys:Set<String>=["application","generator","slicer","slicer_name","producer","x-acnext-client-version"]
        let hints=records.filter { keys.contains($0.key.lowercased()) || $0.key.lowercased().contains("generator") }
        let names:[(String,String)]=[("AnycubicSlicerNext","Anycubic Slicer Next"),("Anycubic Slicer Next","Anycubic Slicer Next"),("AnycubicSlicer","Anycubic"),("OrcaSlicer","OrcaSlicer"),("BambuStudio","Bambu Studio"),("Bambu Studio","Bambu Studio"),("PrusaSlicer","PrusaSlicer"),("Creality","Creality Print"),("FlashPrint","FlashPrint"),("Cura","Cura")]
        var found=[String]()
        for hint in hints { for (needle,name) in names where hint.value.localizedCaseInsensitiveContains(needle) { if !found.contains(name) && !(name=="Anycubic" && found.contains("Anycubic Slicer Next")) {found.append(name)};result.evidence.append(hint.imported(hint.raw.sourcePath.hasSuffix(".model") ? .standard3MF : .slicerMetadata)) } }
        if found.count == 1 {
            result.name=found[0]; result.confidence = .high
            result.family = ["PrusaSlicer":"prusa","OrcaSlicer":"orca","Bambu Studio":"bambu","Anycubic":"anycubic","Anycubic Slicer Next":"anycubic","Creality Print":"creality"][result.name] ?? "generic"
            if let text=result.evidence.first?.value, let range=text.range(of:#"\d+\.\d+(?:\.\d+)?(?:[-+][A-Za-z0-9.]+)?"#,options:.regularExpression) { result.version=String(text[range]) }
        } else if found.count > 1 { result.name="Conflicting slicer identity";result.confidence = .low }
        else if paths.contains(where:{$0.contains("Slic3r_PE")}) { result.name="Unknown / Prusa-compatible";result.family="prusa";result.confidence = .low }
        else if records.contains(where:{$0.key == "printer_model"}) && paths.contains(where:{$0.hasSuffix("project_settings.config")}) { result.name="Unknown / Orca-compatible";result.family="orca";result.confidence = .low }
        return result
    }
}
protocol ThreeMFSlicerAdapter {
    var family: String { get }
    var capabilities: [String:String] { get }
    func normalize(_ records:[MFMetadataRecord], project:inout ImportedPrintProject, context:ThreeMFContext) throws
}
struct OrcaThreeMFAdapter: ThreeMFSlicerAdapter { let family="orca";var capabilities:[String:String]{FamilyThreeMFAdapter.capabilities};func normalize(_ r:[MFMetadataRecord],project:inout ImportedPrintProject,context:ThreeMFContext)throws{try FamilyThreeMFAdapter.normalize(r,project:&project,context:context)} }
struct BambuThreeMFAdapter: ThreeMFSlicerAdapter { let family="bambu";var capabilities:[String:String]{FamilyThreeMFAdapter.capabilities};func normalize(_ r:[MFMetadataRecord],project:inout ImportedPrintProject,context:ThreeMFContext)throws{try FamilyThreeMFAdapter.normalize(r,project:&project,context:context)} }
struct PrusaThreeMFAdapter: ThreeMFSlicerAdapter { let family="prusa";var capabilities:[String:String]{FamilyThreeMFAdapter.capabilities};func normalize(_ r:[MFMetadataRecord],project:inout ImportedPrintProject,context:ThreeMFContext)throws{try FamilyThreeMFAdapter.normalize(r,project:&project,context:context)} }
struct AnycubicThreeMFAdapter: ThreeMFSlicerAdapter { let family="anycubic";var capabilities:[String:String]{FamilyThreeMFAdapter.capabilities};func normalize(_ r:[MFMetadataRecord],project:inout ImportedPrintProject,context:ThreeMFContext)throws{try FamilyThreeMFAdapter.normalize(r,project:&project,context:context)} }
struct CrealityThreeMFAdapter: ThreeMFSlicerAdapter { let family="creality";var capabilities:[String:String]{FamilyThreeMFAdapter.capabilities};func normalize(_ r:[MFMetadataRecord],project:inout ImportedPrintProject,context:ThreeMFContext)throws{try FamilyThreeMFAdapter.normalize(r,project:&project,context:context)} }
struct GenericThreeMFAdapter: ThreeMFSlicerAdapter {
    let family="generic";let capabilities=["standard3MF":"supported","unknownMetadata":"preserved","printer":"unmapped","materials":"standard only","process":"unmapped"]
    func normalize(_ records:[MFMetadataRecord],project:inout ImportedPrintProject,context:ThreeMFContext)throws {project.unmappedMetadata=records.map(\.raw)}
}
enum FamilyThreeMFAdapter {
    static let capabilities=["printer":"known keys","materials":"known keys","process":"known keys","plates":"partial","purge":"settings and explicit quantities","paint":"raw evidence only","thumbnail":"CRC and image-header validation; no pixel decode","versions":"family fallback; unknown keys preserved"]
    static func adapter(_ family:String)->any ThreeMFSlicerAdapter {switch family{case "orca":OrcaThreeMFAdapter();case "bambu":BambuThreeMFAdapter();case "prusa":PrusaThreeMFAdapter();case "anycubic":AnycubicThreeMFAdapter();case "creality":CrealityThreeMFAdapter();default:GenericThreeMFAdapter()}}
    static func normalize(_ records:[MFMetadataRecord],project:inout ImportedPrintProject,context:ThreeMFContext)throws {
        var mapped=Set<Int>(); var filament=[String:ImportedMaterial](); var materialEvidence=[String:String](); var nozzleRecords=[MFMetadataRecord]()
        let peersByScope = Dictionary(grouping:records) { $0.raw.sourcePath + "|" + $0.raw.scope }
        let identityKeys:Set<String> = ["printer_vendor","machine_vendor","printer_model","machine_name","printer_settings_id","printer_preset","printer_variant","printer_preset_id","printer_profile_version","printer_operating_mode","physical_toolhead_count","nozzle_count","extruder_count","filament_input_count","feeder_slot_count","ams_slots","ace_slots","mmu_slots","cfs_slots","ifs_slots","tool_architecture","nozzle_diameter"]
        let aliases=["machine_name":"printer_model","machine_vendor":"printer_vendor","printer_preset":"printer_settings_id"]
        let groupedIdentity = Dictionary(grouping:records.filter { identityKeys.contains($0.key) }) {aliases[$0.key] ?? $0.key}
        let conflicting = Set(groupedIdentity.values.filter { Set($0.map { ThreeMFMetadataRouter.values($0.value) }).count > 1 }.flatMap{$0.map(\.key)})
        for key in conflicting.sorted() { context.diagnostic(.warning,"3MF.Printer","conflictingMetadata","Conflicting \(key) values retained for review; no global value was selected.") }
        let verifiedMajors:[String:Set<Int>] = ["orca":[2],"bambu":[2],"prusa":[2],"anycubic":[2],"creality":[6]]
        let major = project.slicer.version?.split(separator:".").first.flatMap { Int($0) }
        let versionCovered = major.map { verifiedMajors[project.slicer.family]?.contains($0) == true } ?? false
        project.slicer.capabilities["versionPolicy"] = versionCovered ? "fixture-covered family; known keys only" : "unverified version; conservative known-key fallback"
        if !versionCovered {context.diagnostic(.warning,"3MF.SlicerDetection","versionFallback","This slicer version is outside fixture coverage. Known fields are retained as evidence; review imported settings.")}

        func plateScope(_ scope:String)->String? { guard let range=scope.range(of:#"(?:plate|plater)\[\d+\]"#,options:.regularExpression) else{return nil};return String(scope[..<range.upperBound]) }
        let plateScopes=Set(records.compactMap{plateScope($0.raw.scope)}).sorted()
        var plateIDs=[String:String]()
        for scope in plateScopes {
            let local=records.filter{plateScope($0.raw.scope)==scope}
            let id=local.first{["plater_id","index","plate_id"].contains($0.key) || ($0.key=="id" && $0.raw.scope.contains("plate_info["))}?.value ?? scope
            plateIDs[scope]=id
            var plate=project.plates.first{$0.id==id} ?? ImportedPlate(id:id)
            if let name=local.first(where:{["plater_name","plate_name"].contains($0.key)}){plate.name=name.imported()}
            plate.objectIDs=Array(Set(plate.objectIDs+local.filter{$0.key=="object_id"}.map(\.value))).sorted()
            if let index=project.plates.firstIndex(where:{$0.id==id}) {project.plates[index]=plate}else{project.plates.append(plate)}
        }
        func positive(_ value:String)->Double? {guard let d=Double(value.trimmingCharacters(in:CharacterSet(charactersIn:"% "))),d.isFinite,d>=0 else{return nil};return d}
        let processKeys:Set<String>=["layer_height","first_layer_height","wall_loops","perimeters","top_shell_layers","bottom_shell_layers","top_solid_layers","bottom_solid_layers","sparse_infill_density","fill_density","sparse_infill_pattern","fill_pattern","outer_wall_speed","travel_speed","enable_support","support_material","support_type","support_threshold_angle","support_interface_top_layers","raft_layers","brim_width","skirt_loops","ironing_type","fuzzy_skin","print_sequence","adaptive_layer_height","curr_bed_type","bed_type","bed_surface"]
        let materialKeys:Set<String>=["filament_type","filament_settings_id","filament_vendor","filament_name","filament_colour","filament_color","filament_density","filament_diameter","filament_cost","nozzle_temperature","temperature","bed_temperature","chamber_temperature","filament_flow_ratio","extrusion_multiplier","filament_max_volumetric_speed","filament_drying_temperature","filament_drying_time","filament_is_abrasive"]
        for (index,r) in records.enumerated() {
            try context.check();let values=ThreeMFMetadataRouter.values(r.value);let first=values.first ?? "";let source=r.imported()
            func stringValue(_ value:String)->ImportedValue<String>{.init(value,path:r.raw.sourcePath,key:r.raw.scope+"/"+r.key)}
            func quantity(_ amount:Double,_ unit:String,_ role:String, slot:Int? = nil) {
                let plate=plateScope(r.raw.scope).flatMap{plateIDs[$0]}
                let peers=peersByScope[r.raw.sourcePath+"|"+r.raw.scope] ?? []
                let materialID=peers.first{$0.key=="id" && r.raw.scope.contains("filament[")}.map { "filament:"+$0.value }
                let q=ImportedQuantity(role:role,plateID:plate,materialID:slot.map { "filament:\($0+1)" } ?? materialID,amount:.init(amount,path:r.raw.sourcePath,key:r.raw.scope+"/"+r.key),unit:unit)
                project.estimates.append(q);if let p=project.plates.firstIndex(where:{$0.id==plate}) {project.plates[p].estimates.append(q)}
            }
            if conflicting.contains(r.key) { continue }
            if identityKeys.contains(r.key), let scope=plateScope(r.raw.scope), let id=plateIDs[scope], let p=project.plates.firstIndex(where:{$0.id==id}) {
                project.plates[p].settings.append(.init(r.key,scope:r.raw.scope,source:source))
                continue // Plate machine overrides never replace project-wide identity.
            }
            switch r.key {
            case "printer_vendor","machine_vendor":project.printer.manufacturer=stringValue(first);mapped.insert(index)
            case "printer_model","machine_name":project.printer.model=stringValue(first);mapped.insert(index)
            case "printer_settings_id","printer_preset":project.printer.presetName=stringValue(first);mapped.insert(index)
            case "printer_variant":project.printer.variant=stringValue(first);mapped.insert(index)
            case "printer_preset_id":project.printer.presetID=source;mapped.insert(index)
            case "printer_profile_version":project.printer.profileVersion=source;mapped.insert(index)
            case "printer_operating_mode":project.printer.operatingMode=source;mapped.insert(index)
            case "physical_toolhead_count":
                if let count=Int(first),(1...12).contains(count){project.toolSystem.physicalToolheads = .init(count,path:r.raw.sourcePath,key:r.key)}else{context.diagnostic(.warning,"3MF.Toolheads","invalidCount","Physical toolhead count must be in 1–12.",path:r.raw.sourcePath)};mapped.insert(index)
            case "nozzle_count":if let n=Int(first),(1...12).contains(n){project.toolSystem.nozzleCount = .init(n,path:r.raw.sourcePath,key:r.key)};mapped.insert(index)
            case "extruder_count":if let n=Int(first),(1...12).contains(n){project.toolSystem.extruderCount = .init(n,path:r.raw.sourcePath,key:r.key)};mapped.insert(index)
            case "filament_input_count","feeder_slot_count","ams_slots","ace_slots","mmu_slots","cfs_slots","ifs_slots":
                if let n=Int(first),(0...256).contains(n){if r.key=="filament_input_count" {project.toolSystem.filamentInputs = .init(n,path:r.raw.sourcePath,key:r.key)}else{project.toolSystem.feederSlots = .init(n,path:r.raw.sourcePath,key:r.key);project.toolSystem.feederType=stringValue(r.key.replacingOccurrences(of:"_slots",with:""))}};mapped.insert(index)
            case "tool_architecture":project.toolSystem.architecture=source;mapped.insert(index)
            case "nozzle_diameter":nozzleRecords.append(r);mapped.insert(index)
            case "prediction","estimated_print_time","estimated printing time (normal mode)","print_time":if let seconds=time(first){quantity(seconds,"seconds","printTime");mapped.insert(index)}
            case "used_g","total_filament_weight","filament used [g]","model_material_g","support_material_g","support_interface_g","purge_material_g","prime_tower_g","flush_g":
                let roles=["model_material_g":"model","support_material_g":"support","support_interface_g":"supportInterface","purge_material_g":"purge","prime_tower_g":"primeTower","flush_g":"flush"]
                for (slot,value) in values.enumerated(){if let n=positive(value){quantity(n,"grams",roles[r.key] ?? "total",slot:values.count>1 ? slot:nil)}};mapped.insert(index)
            case "used_m","filament used [mm]":if let n=positive(first){quantity(r.key=="used_m" ? n*1000:n,"millimeters","totalLength");mapped.insert(index)}
            case "filament_change_count","tool_change_count":if let n=positive(first){quantity(n,"count",r.key);mapped.insert(index)}
            case "extruder","support_filament","support_material_extruder","support_interface_filament","support_material_interface_extruder","filament_map":
                for (slot,value) in values.enumerated(){let role=r.key.contains("interface") ? "supportInterface":r.key.contains("support") ? "support":"model";project.assignments.append(.init(scope:r.raw.scope,role:role,materialID:"filament:"+(r.key=="filament_map" ? String(slot+1):value),toolIndex:nil,source:stringValue(value)))};mapped.insert(index)
            default:break
            }
            if materialKeys.contains(r.key) {
                for (slot,value) in values.enumerated() where slot<256 {
                    let profileScope=r.raw.scope.hasPrefix("gcode/line[") ? "gcode-profile" : (r.raw.scope.components(separatedBy:"/").last?.hasPrefix("metadata[") == true ? r.raw.scope.components(separatedBy:"/").dropLast().joined(separator:"/") : r.raw.scope)
                    let profileKey=r.raw.sourcePath+"|"+profileScope+"|"+String(slot)
                    let materialID = r.raw.scope == "project" && !filament.values.contains(where: { $0.id == "filament:\(slot+1)" && filament[profileKey] == nil }) ? "filament:\(slot+1)" : profileKey
                    var m=filament[profileKey] ?? ImportedMaterial(id:materialID)
                    m.properties.append(.init(r.key,scope:r.raw.scope,source:stringValue(value)))
                    let evidenceKey=profileKey+"|"+r.key
                    if let old=materialEvidence[evidenceKey],old != value {
                        context.diagnostic(.warning,"3MF.Materials","conflictingMaterial","Conflicting material profile values retained; first value kept for review.",path:r.raw.sourcePath)
                        filament[profileKey]=m;continue
                    }
                    materialEvidence[evidenceKey]=value
                    switch r.key {
                    case "filament_type":m.family=stringValue(value)
                    case "filament_settings_id":m.preset=stringValue(value)
                    case "filament_vendor":m.manufacturer=stringValue(value)
                    case "filament_name":m.productName=stringValue(value)
                    case "filament_colour","filament_color":m.sourceColorHex=stringValue(value);m.normalizedColorHex=ThreeMFMetadataRouter.color(value)
                    case "filament_density":if let d=positive(value),d>0 {m.densityGramsPerCM3 = .init(d,path:r.raw.sourcePath,key:r.key)}
                    case "filament_diameter":if let d=positive(value),d>0 {m.diameterMM = .init(d,path:r.raw.sourcePath,key:r.key)}
                    case "filament_cost":if let d=Decimal(string:value),!d.isNaN,d>=0 {m.embeddedSlicerCost = .init(d,path:r.raw.sourcePath,key:r.key,confidence:.low)}
                    default:if r.key.contains("temperature"),let d=positive(value){m.temperatures.append(.init(d,path:r.raw.sourcePath,key:r.key))};m.properties.append(.init(r.key,scope:r.raw.scope,source:stringValue(value)))
                    };filament[profileKey]=m
                };mapped.insert(index)
            }
            if processKeys.contains(r.key) || r.key.contains("purge") || r.key.contains("flush") || r.key.contains("prime_tower") || r.key.contains("wipe_tower") {
                let setting=ImportedSetting(r.key,scope:r.raw.scope,source:source)
                if r.key.contains("purge") || r.key.contains("flush") || r.key.contains("tower") {project.processSettings.purgeSettings.append(setting)}else{project.processSettings.settings.append(setting)}
                if let id=plateScope(r.raw.scope).flatMap({plateIDs[$0]}),let p=project.plates.firstIndex(where:{$0.id==id}){project.plates[p].settings.append(setting)};mapped.insert(index)
            }
        }
        project.materials += filament.keys.sorted().map{filament[$0]!}
        if records.contains(where: { ["filament_map","extruder","support_material_extruder","support_material_interface_extruder"].contains($0.key) }) {
            context.diagnostic(.info,"3MF.Toolheads","assignmentReview","Extruder/material routing is retained by source scope. Slicer slot indexes are not automatically promoted to physical toolhead assignments.")
        }
        if project.toolSystem.physicalToolheads == nil, let model=project.printer.model?.value {
            struct Knowledge:Decodable { struct Configuration:Decodable {var canonicalModel:String;var aliases:[String];var physicalToolheads:Int;var architecture:String};var configurations:[Configuration] }
            if let knowledge=try? SeedLoader.resource("three_mf_printer_aliases_v2",as:Knowledge.self),let match=knowledge.configurations.first(where:{$0.aliases.map(ThreeMFPrinterMatcher.normalize).contains(ThreeMFPrinterMatcher.normalize(model))}) {
                project.toolSystem.physicalToolheads = .init(match.physicalToolheads,path:"three_mf_printer_aliases_v2.json",key:match.canonicalModel,type:.printerProfile,confidence:.medium)
                project.toolSystem.architecture = .init(match.architecture,path:"three_mf_printer_aliases_v2.json",key:match.canonicalModel,type:.printerProfile,confidence:.medium)
                context.diagnostic(.info,"3MF.Printer","baselineArchitecture","Physical toolhead count matched an acceptance baseline configuration; modified hardware still requires review.")
            }
        }
        // No material-array or feeder-slot count is used as a physical-tool count.
        if let count=project.toolSystem.physicalToolheads?.value {
            project.toolSystem.tools=(1...count).map{ImportedToolhead(index:$0)}
            for r in nozzleRecords {let diameters=ThreeMFMetadataRouter.values(r.value);for (i,value) in diameters.enumerated() where i<count {if let d=Double(value),d.isFinite,d>0 {project.toolSystem.tools[i].nozzleDiameterMM = .init(d,path:r.raw.sourcePath,key:r.key+"[\(i)]")}}}
            project.toolSystem.needsReview=project.toolSystem.physicalToolheads?.sourceType != .slicerMetadata || project.toolSystem.tools.contains{$0.nozzleDiameterMM==nil}
        } else {
            for r in nozzleRecords {let diameters=ThreeMFMetadataRouter.values(r.value);for (i,value) in diameters.prefix(12).enumerated(){if let d=Double(value),d.isFinite,d>0 {var t=ImportedToolhead(index:i+1);t.nozzleDiameterMM = .init(d,path:r.raw.sourcePath,key:r.key+"[\(i)]");project.toolSystem.tools.append(t)}}}
            context.diagnostic(.warning,"3MF.Toolheads","ambiguousPhysicalCount","No explicit physical toolhead count. Nozzle entries and material inputs remain evidence requiring review.")
        }
        if project.slicer.family=="prusa", let count=project.toolSystem.physicalToolheads?.value, count>1 {
            for i in project.assignments.indices {
                let key=project.assignments[i].source.metadataKey.components(separatedBy:"/").last ?? ""
                if ["extruder","support_material_extruder","support_material_interface_extruder"].contains(key), let tool=Int(project.assignments[i].source.value),(1...count).contains(tool) {project.assignments[i].toolIndex=tool}
            }
        }
        project.unmappedMetadata=records.enumerated().filter{!mapped.contains($0.offset) || $0.element.value.utf8.count>65536}.map(\.element.raw)
        context.diagnostic(.info,"3MF.Metadata","unmappedPreserved","\(project.unmappedMetadata.count) unmapped metadata records preserved.")
    }
    static func time(_ text:String)->Double? {
        if let n=Double(text),n.isFinite,n>=0{return n}
        let pattern=#"(\d+(?:\.\d+)?)\s*(d|h|m|s)"#
        guard let regex=try? NSRegularExpression(pattern:pattern) else{return nil}
        let ns=text as NSString;let matches=regex.matches(in:text,range:NSRange(location:0,length:ns.length));guard !matches.isEmpty else{return nil}
        var seconds=0.0
        for m in matches {guard let value=Double(ns.substring(with:m.range(at:1))) else{return nil};seconds+=value*(["d":86400.0,"h":3600.0,"m":60.0,"s":1.0][ns.substring(with:m.range(at:2))] ?? 1)}
        return seconds.isFinite ? seconds:nil
    }
}
