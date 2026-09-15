import Foundation

public struct ModelInspectionField: Codable, Sendable, Identifiable {
    public var category: String
    public var source: String
    public var key: String
    public var value: String
    public var id: String { source + "\n" + key + "\n" + category }
    public init(category: String, source: String, key: String, value: String) {
        self.category = category; self.source = source; self.key = key; self.value = value
    }
}
public struct ModelInspectionReport: Codable, Sendable {
    public var fileName: String
    public var format: String
    public var fields: [ModelInspectionField]
    public var warnings: [String]
    public init(fileName: String, format: String, fields: [ModelInspectionField], warnings: [String]) {
        self.fileName = fileName; self.format = format; self.fields = fields; self.warnings = warnings
    }
}
