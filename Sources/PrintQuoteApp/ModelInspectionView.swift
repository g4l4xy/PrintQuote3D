import SwiftUI
import UniformTypeIdentifiers
import QuoteDomain
import QuoteData

struct LegacyModelInspectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var choosing = false
    @State private var busy = false
    @State private var report: ModelInspectionReport?
    @State private var error: String?
    @State private var search = ""
    @State private var category = "All"
    @State private var progress: Progress?
    private let categories = ["All", "Geometry", "Project settings", "Sliced results", "Metadata", "Package"]
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Inspect STL / 3MF").font(.title2.bold())
                Text("Review geometry and OrcaSlicer / Bambu Studio metadata. Your quotes stay unchanged.").foregroundStyle(.secondary)
                HStack {
                    Button("Choose file") { choosing = true }.buttonStyle(.borderedProminent).disabled(busy)
                    if busy { ProgressView(); Button("Cancel") { progress?.cancel() } }
                }
                if let error { Text(error).foregroundStyle(.red).textSelection(.enabled) }
                if let report {
                    Text(report.fileName).font(.headline).textSelection(.enabled)
                    DisclosureGroup("How to read this report") { ForEach(report.warnings, id: \.self) { Text($0).font(.caption).padding(.vertical, 4) } }
                    TextField("Search printer, filament, color, support, tower…", text: $search).textFieldStyle(.roundedBorder)
                    Picker("Category", selection: $category) { ForEach(categories, id: \.self) { Text($0) } }.pickerStyle(.menu)
                    let rows = report.fields.filter { (category == "All" || $0.category == category) && (search.isEmpty || ($0.source + " " + $0.key + " " + $0.value).localizedCaseInsensitiveContains(search)) }
                    Text("\(rows.count) of \(report.fields.count) fields").font(.caption).foregroundStyle(.secondary)
                    List(Array(rows.enumerated()), id: \.offset) { _, field in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(field.key).font(.subheadline.bold()).textSelection(.enabled)
                            Text(field.value.isEmpty ? "(empty)" : field.value).textSelection(.enabled)
                            Text(field.category + " · " + field.source).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }.padding(.vertical, 4)
                    }.listStyle(.plain)
                } else { Spacer(); Text("Choose an STL, project 3MF, or sliced .gcode.3mf file. Missing sliced results remain unknown.").foregroundStyle(.secondary); Spacer() }
            }.padding()
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $choosing, allowedContentTypes: [UTType(filenameExtension: "stl") ?? .data, UTType(filenameExtension: "3mf") ?? .data]) { result in
                switch result {
                case .failure(let failure): error = failure.localizedDescription
                case .success(let url):
                    let operation = Progress(totalUnitCount: 1); progress = operation; busy = true; error = nil; report = nil
                    Task {
                        do {
                            let imported = try await Task.detached(priority: .userInitiated) {
                                let access = url.startAccessingSecurityScopedResource()
                                defer { if access { url.stopAccessingSecurityScopedResource() } }
                                return try ModelImportService.inspect(url: url, cancelled: { operation.isCancelled })
                            }.value
                            if !operation.isCancelled { report = imported }
                        } catch { if !operation.isCancelled { self.error = error.localizedDescription } }
                        busy = false
                    }
                }
            }
            .onDisappear { progress?.cancel() }
        }
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 850, minHeight: 500, idealHeight: 700)
        #endif
    }
}
