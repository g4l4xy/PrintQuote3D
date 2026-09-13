import SwiftUI
import QuoteDomain

struct PrinterPicker: View {
    let printers: [PrinterProfile]
    let select: (PrinterProfile) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    private var matches: [PrinterProfile] {
        printers.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Choose printer").font(.title2.bold()); Spacer(); Button("Cancel") { dismiss() } }
            TextField("Search manufacturer, model or nozzle", text: $search).textFieldStyle(.roundedBorder)
            Text("\(matches.count) profiles").font(.caption).foregroundStyle(.secondary)
            List(matches) { printer in
                Button { select(printer); dismiss() } label: {
                    VStack(alignment: .leading) {
                        Text(printer.name)
                        Text(printer.source.name).font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()).padding(.vertical, 4)
                }.buttonStyle(.plain)
            }
        }.padding(20).desktopSheet(width: 580, height: 560)
    }
}
