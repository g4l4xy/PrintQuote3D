import Foundation
import SQLite3
import QuoteDomain

public struct FilamentImportDiagnostic: Codable, Sendable {
    public var sourceID:String
    public var reason:String
    public var count:Int
}
public struct FilamentImportCounts: Codable, Sendable {
    public var products=0, variants=0, discovered=0, decoded=0, normalized=0, rejected=0, inserted=0, updated=0, duplicates=0, stored=0
    public var quarantine:[FilamentImportDiagnostic]=[]
    public init(){}
}
public struct FilamentQuery: Sendable, Equatable {
    public var text=""
    public var families:Set<String>=[]
    public var manufacturers:Set<String>=[]
    public var favoritesOnly=false
    public var recentOnly=false
    public var sort="Name"
    public var offset=0
    public var limit=100
    public init(){}
}
public struct FilamentSearchRow: Sendable, Identifiable {
    public var id:String, productID:String, variantID:String, name:String, brand:String, family:String, color:String, spool:String, printing:String
    public var favorite:Bool
    public var lastUsed:Double
    public var price="",difficulty="",drying=""
}
public struct FilamentPage: Sendable {
    public var rows:[FilamentSearchRow]=[]
    public var matches=0
    public var total=0
    public init(){}
}
private final class FilamentConnection: @unchecked Sendable {
    let handle:OpaquePointer
    init(_ path:String)throws {
        var connection:OpaquePointer?
        guard sqlite3_open_v2(path,&connection,SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_FULLMUTEX,nil)==SQLITE_OK,let connection else{if let connection{sqlite3_close(connection)};throw PricingError.invalid("Cannot open local filament search database.")}
        handle=connection
    }
    deinit{sqlite3_close(handle)}
}
/// Durable catalog index. Shop inventory remains in LibrarySnapshot; preferences survive catalog replacement.
public actor FilamentRepository {
    private let connection:FilamentConnection
    private var inventorySignature:Int?
    private var db:OpaquePointer{connection.handle}
    public init(url:URL?=nil)throws {
        if let url {try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)}
        connection=try FilamentConnection(url?.path ?? ":memory:")
        let sql="""
        PRAGMA journal_mode=WAL;
        CREATE TABLE IF NOT EXISTS filament(id TEXT PRIMARY KEY,product TEXT,variant TEXT,name TEXT,brand TEXT,family TEXT,color TEXT,spool TEXT,printing TEXT);
        CREATE INDEX IF NOT EXISTS filament_brand ON filament(brand);
        CREATE INDEX IF NOT EXISTS filament_family ON filament(family);
        CREATE INDEX IF NOT EXISTS filament_name ON filament(name);
        CREATE VIRTUAL TABLE IF NOT EXISTS filament_search USING fts5(id UNINDEXED,tokens,tokenize='unicode61 remove_diacritics 2');
        CREATE TABLE IF NOT EXISTS preference(id TEXT PRIMARY KEY,favorite INTEGER DEFAULT 0,lastUsed REAL DEFAULT 0);
        CREATE INDEX IF NOT EXISTS preference_favorite ON preference(favorite);
        CREATE INDEX IF NOT EXISTS preference_recent ON preference(lastUsed);
        CREATE TABLE IF NOT EXISTS inventory_price(id TEXT PRIMARY KEY,price TEXT);
        CREATE INDEX IF NOT EXISTS inventory_price_amount ON inventory_price(price);
        CREATE TABLE IF NOT EXISTS filament_spec(id TEXT PRIMARY KEY,difficulty TEXT,drying TEXT);
        CREATE INDEX IF NOT EXISTS filament_spec_difficulty ON filament_spec(difficulty);
        CREATE INDEX IF NOT EXISTS filament_spec_drying ON filament_spec(drying);
        CREATE TABLE IF NOT EXISTS catalog_meta(key TEXT PRIMARY KEY,value TEXT);
        """
        guard sqlite3_exec(connection.handle,sql,nil,nil,nil)==SQLITE_OK else{throw PricingError.invalid("Cannot initialize local filament index: \(String(cString:sqlite3_errmsg(connection.handle)))")}
    }
    private func statement(_ sql:String,_ args:[String]=[])throws->OpaquePointer {
        var p:OpaquePointer?;guard sqlite3_prepare_v2(db,sql,-1,&p,nil)==SQLITE_OK,let p else{throw PricingError.invalid("Filament query failed: \(String(cString:sqlite3_errmsg(db)))")}
        for (i,value) in args.enumerated(){_ = value.withCString{sqlite3_bind_text(p,Int32(i+1),$0,-1,unsafeBitCast(-1,to:sqlite3_destructor_type.self))}}
        return p
    }
    private func next(_ statement:OpaquePointer)throws->Bool {
        let result=sqlite3_step(statement)
        if result==SQLITE_ROW {return true}
        if result==SQLITE_DONE {return false}
        throw PricingError.invalid("Filament database read failed: \(String(cString:sqlite3_errmsg(db)))")
    }
    private func run(_ sql:String,_ args:[String]=[])throws{let p=try statement(sql,args);defer{sqlite3_finalize(p)};guard sqlite3_step(p)==SQLITE_DONE else{throw PricingError.invalid("Filament database update failed: \(String(cString:sqlite3_errmsg(db)))")}}
    private func string(_ p:OpaquePointer,_ i:Int32)->String{sqlite3_column_text(p,i).map{String(cString:$0)} ?? ""}
    private func scalar(_ sql:String,_ args:[String]=[])throws->Int{let p=try statement(sql,args);defer{sqlite3_finalize(p)};guard try next(p) else{return 0};return Int(sqlite3_column_int64(p,0))}
    public func counts()throws->FilamentImportCounts? {
        let p=try statement("SELECT value FROM catalog_meta WHERE key='counts'");defer{sqlite3_finalize(p)}
        guard try next(p) else{return nil};return try JSONDecoder().decode(FilamentImportCounts.self,from:Data(string(p,0).utf8))
    }
    public func brands()throws->[String]{try distinct("brand")}
    public func families()throws->[String]{try distinct("family")}
    private func distinct(_ column:String)throws->[String]{let p=try statement("SELECT DISTINCT \(column) FROM filament ORDER BY \(column) COLLATE NOCASE");defer{sqlite3_finalize(p)};var result=[String]();while try next(p){result.append(string(p,0))};return result}
    public func favorite(_ id:String,enabled:Bool)throws{try run("INSERT INTO preference(id,favorite) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET favorite=excluded.favorite",[id,enabled ? "1":"0"])}
    public func used(_ id:String)throws{try run("INSERT INTO preference(id,lastUsed) VALUES(?,?) ON CONFLICT(id) DO UPDATE SET lastUsed=excluded.lastUsed",[id,String(Date().timeIntervalSince1970)])}
    public func syncInventoryPrices(_ materials:[FilamentProduct])throws {
        var hasher=Hasher();for material in materials{hasher.combine(material.id);hasher.combine(material.pricePerKG.description)}
        let signature=hasher.finalize();if signature==inventorySignature{return}
        try run("BEGIN IMMEDIATE")
        do {try run("DELETE FROM inventory_price");for material in materials{try Task.checkCancellation();try run("INSERT OR REPLACE INTO inventory_price VALUES(?,?)",[material.id.uuidString,material.pricePerKG.description])};try run("COMMIT");inventorySignature=signature}
        catch{try? run("ROLLBACK");throw error}
    }
    public func search(_ query:FilamentQuery)throws->FilamentPage {
        try Task.checkCancellation()
        var whereSQL=[String]();var args=[String]()
        let words=query.text.components(separatedBy:CharacterSet.alphanumerics.inverted).filter{!$0.isEmpty}
        if !words.isEmpty {whereSQL.append("f.id IN (SELECT id FROM filament_search WHERE filament_search MATCH ?)");args.append(words.prefix(20).map{"\""+$0+"\"*"}.joined(separator:" AND "))}
        for (column,values) in [("family",query.families),("brand",query.manufacturers)] where !values.isEmpty {whereSQL.append("f.\(column) IN (\(values.map{_ in "?"}.joined(separator:",")))");args += values.sorted()}
        if query.favoritesOnly{whereSQL.append("COALESCE(p.favorite,0)=1")};if query.recentOnly{whereSQL.append("COALESCE(p.lastUsed,0)>0")}
        let filter=whereSQL.isEmpty ? "" : " WHERE "+whereSQL.joined(separator:" AND ")
        let from=" FROM filament f LEFT JOIN preference p ON p.id=f.id LEFT JOIN inventory_price ip ON ip.id=f.id LEFT JOIN filament_spec s ON s.id=f.id"
        let order=["Name":"f.name COLLATE NOCASE,f.color COLLATE NOCASE","Manufacturer":"f.brand COLLATE NOCASE,f.name COLLATE NOCASE","Material":"f.family,f.name COLLATE NOCASE","Recently Used":"COALESCE(p.lastUsed,0) DESC,f.name","Favorite":"COALESCE(p.favorite,0) DESC,f.name","Price / kg":"ip.price IS NULL,CAST(ip.price AS REAL),f.name","Difficulty":"CASE WHEN COALESCE(s.difficulty,'')='' THEN 1 ELSE 0 END,s.difficulty COLLATE NOCASE,f.name","Drying Requirement":"CASE WHEN COALESCE(s.drying,'')='' THEN 1 ELSE 0 END,s.drying COLLATE NOCASE,f.name"][query.sort] ?? "f.name COLLATE NOCASE"
        var page=FilamentPage();page.total=try scalar("SELECT COUNT(*) FROM filament");page.matches=try scalar("SELECT COUNT(*)"+from+filter,args)
        let p=try statement("SELECT f.id,f.product,f.variant,f.name,f.brand,f.family,f.color,f.spool,f.printing,COALESCE(p.favorite,0),COALESCE(p.lastUsed,0),ip.price,s.difficulty,s.drying"+from+filter+" ORDER BY "+order+",f.id LIMIT ? OFFSET ?",args+[String(min(200,max(1,query.limit))),String(max(0,query.offset))]);defer{sqlite3_finalize(p)}
        while try next(p) {try Task.checkCancellation();page.rows.append(.init(id:string(p,0),productID:string(p,1),variantID:string(p,2),name:string(p,3),brand:string(p,4),family:string(p,5),color:string(p,6),spool:string(p,7),printing:string(p,8),favorite:sqlite3_column_int(p,9)==1,lastUsed:sqlite3_column_double(p,10),price:string(p,11),difficulty:string(p,12),drying:string(p,13)))}
        return page
    }
    /// Per-product decoding failures are quarantined with their number of affected spool records.
    /// A failed refresh rolls back, leaving the last successful local index and preferences available.
    public func rebuild(data:Data,progress:@Sendable (String)->Void = {_ in})throws->(OpenFilamentCatalog,FilamentImportCounts) {
        progress("Decoding local catalog…")
        guard var root=try JSONSerialization.jsonObject(with:data) as? [String:Any],let products=root["products"] as? [[String:Any]] else{throw PricingError.invalid("Filament catalog has no products array. Existing local index is still available.")}
        guard root["schemaVersion"] as? Int == 2 else{throw PricingError.invalid("Unsupported filament schema version. Existing local index is still available.")}
        var counts=FilamentImportCounts();counts.products=products.count;var decoded=[CatalogFilament]();var seen=Set<String>()
        for (n,p) in products.enumerated(){
            try Task.checkCancellation()
            let variants=p["variants"] as? [[String:Any]] ?? [];let records=variants.reduce(0){$0+(($1["sizes"] as? [Any])?.count ?? 0)}
            counts.variants += variants.count;counts.discovered += records
            if variants.isEmpty {counts.quarantine.append(.init(sourceID:p["id"] as? String ?? "product[\(n)]",reason:"Product has no color variants or searchable spool options",count:0))}
            for variant in variants where (variant["sizes"] as? [Any] ?? []).isEmpty {counts.quarantine.append(.init(sourceID:variant["id"] as? String ?? "variant",reason:"Color variant has no spool sizes",count:0))}
            do {let product=try JSONDecoder().decode(CatalogFilament.self,from:JSONSerialization.data(withJSONObject:p));decoded.append(product);counts.decoded += records}
            catch {counts.rejected += records;counts.quarantine.append(.init(sourceID:p["id"] as? String ?? "product[\(n)]",reason:"JSON decoding failed: \(error)",count:records))}
        }
        root["products"]=[]
        var catalog=try JSONDecoder().decode(OpenFilamentCatalog.self,from:JSONSerialization.data(withJSONObject:root));catalog.products=decoded
        let existing=try ids();try run("BEGIN IMMEDIATE")
        do {
            try run("DELETE FROM filament");try run("DELETE FROM filament_search");try run("DELETE FROM filament_spec")
            for product in decoded {for variant in product.variants {for size in variant.sizes {
                try Task.checkCancellation();let id=size.id.uuidString
                var reason:String?
                if product.materialFamily.trimmingCharacters(in:.whitespaces).isEmpty {reason="Missing material family"}
                else if product.brand.isEmpty || product.name.isEmpty {reason="Missing brand or product name"}
                else if let hex=variant.colorHex, !hex.isEmpty, !Self.validColor(hex) {reason="Malformed color value"}
                else if let d=size.diameterMM, !d.isFinite || d<=0 {reason="Invalid spool diameter"}
                else if let g=size.netWeightGrams, !g.isFinite || g<=0 {reason="Invalid spool size"}
                if let reason{counts.rejected+=1;counts.quarantine.append(.init(sourceID:id,reason:reason,count:1));continue}
                guard seen.insert(id).inserted else{counts.duplicates+=1;counts.quarantine.append(.init(sourceID:id,reason:"Duplicate external spool ID",count:1));continue}
                let fields=FieldPrecedence.merge(existing:FieldPrecedence.merge(existing:product.fields,incoming:variant.fields),incoming:size.fields)
                let tokens=([product.brand,product.name,product.materialFamily,variant.name]+fields.map{$0.key+" "+$0.value.value}).joined(separator:" ")
                let spool="\(size.diameterMM.map{String($0)} ?? "?") mm · \(size.netWeightGrams.map{String($0)} ?? "?") g"
                let printing="Nozzle \(fields["nozzle_min_c"]?.value ?? "?")–\(fields["nozzle_max_c"]?.value ?? "?") °C · Bed \(fields["bed_min_c"]?.value ?? "?")–\(fields["bed_max_c"]?.value ?? "?") °C"
                try run("INSERT INTO filament VALUES(?,?,?,?,?,?,?,?,?)",[id,product.id.uuidString,variant.id.uuidString,product.name,product.brand,product.materialFamily,variant.name,spool,printing])
                try run("INSERT INTO filament_spec VALUES(?,?,?)",[id,fields["difficulty"]?.value ?? "",fields["drying_required"]?.value ?? ""])
                try run("INSERT INTO filament_search(id,tokens) VALUES(?,?)",[id,tokens]);counts.normalized+=1
                if existing.contains(id){counts.updated+=1}else{counts.inserted+=1}
                if counts.normalized%500==0{progress("Indexing \(counts.normalized) of \(counts.discovered) spool options…")}
            }}}
            counts.stored=try scalar("SELECT COUNT(*) FROM filament")
            try run("INSERT OR REPLACE INTO catalog_meta VALUES('counts',?)",[String(decoding:try JSONEncoder().encode(counts),as:UTF8.self)])
            try Task.checkCancellation();try run("COMMIT")
        }catch{try? run("ROLLBACK");throw error}
        progress("Local filament library ready")
        return (catalog,counts)
    }
    private static func validColor(_ color:String)->Bool {
        let digits=color.hasPrefix("#") ? color.dropFirst() : color[...]
        return [6,8].contains(digits.count) && digits.allSatisfy(\.isHexDigit)
    }
    private func ids()throws->Set<String>{let p=try statement("SELECT id FROM filament");defer{sqlite3_finalize(p)};var ids=Set<String>();while try next(p){ids.insert(string(p,0))};return ids}
}
