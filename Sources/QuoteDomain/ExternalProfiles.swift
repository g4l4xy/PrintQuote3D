import Foundation
public struct ExternalProfileSource: Codable, Equatable, Sendable {
    public var sourceName: String
    public var repositoryURL: String
    public var sourcePath: String
    public var inheritedPaths: [String]
    public var commitSHA: String
    public var importedAt: Date
    public var needsReview: Bool
    public var userOverride: Bool
    public init(sourcePath: String, inheritedPaths: [String] = [], commitSHA: String, importedAt: Date = Date()) {
        self.sourceName = "OrcaSlicer"
        self.repositoryURL = "https://github.com/OrcaSlicer/OrcaSlicer"
        self.sourcePath = sourcePath; self.inheritedPaths = inheritedPaths
        self.commitSHA = commitSHA; self.importedAt = importedAt
        self.needsReview = true; self.userOverride = false
    }
}
