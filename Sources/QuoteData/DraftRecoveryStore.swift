import Foundation
import QuoteDomain

/// Atomic, per-quote recovery journals. Recovery never silently replaces the saved quote.
public actor DraftRecoveryStore {
    private let directory:URL
    public init(directory:URL?=nil){self.directory=directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("PrintQuote3D/Recovery")}
    public func save(_ quote:Quote)throws {
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        let file=directory.appendingPathComponent(quote.id.uuidString+".json")
        try JSONEncoder().encode(quote).write(to:file,options:.atomic)
        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
    }
    public func recover()throws->[Quote] {
        guard FileManager.default.fileExists(atPath:directory.path) else{return []}
        let files=try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:[.contentModificationDateKey]).filter{$0.pathExtension=="json"}
        return try files.sorted{((try? $0.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast)>((try? $1.resourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate) ?? .distantPast)}.map{try JSONDecoder().decode(Quote.self,from:Data(contentsOf:$0))}
    }
    public func scan()throws->(drafts:[Quote],issues:[String]) {
        guard FileManager.default.fileExists(atPath:directory.path) else{return ([],[])}
        let files=try FileManager.default.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil).filter{$0.pathExtension=="json"}
        var drafts=[Quote]();var issues=[String]()
        for file in files {
            do {drafts.append(try JSONDecoder().decode(Quote.self,from:Data(contentsOf:file)))}
            catch {issues.append(file.lastPathComponent+": "+error.localizedDescription)}
        }
        return (drafts.sorted{$0.createdAt>$1.createdAt},issues)
    }
    public func discard(_ id:UUID)throws {
        let file=directory.appendingPathComponent(id.uuidString+".json")
        if FileManager.default.fileExists(atPath:file.path){try FileManager.default.removeItem(at:file)}
    }
}
