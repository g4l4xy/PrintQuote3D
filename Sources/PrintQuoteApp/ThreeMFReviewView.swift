import SwiftUI
import UniformTypeIdentifiers
import QuoteDomain
import QuoteData

struct ModelInspectionView: View {
    let state: AppState
    @State private var legacy = false
    var body: some View {
        if legacy { LegacyModelInspectionView() }
        else { ThreeMFReviewView(state:state,legacy:{legacy=true}) }
    }
}
struct ThreeMFReviewView: View {
    let state: AppState
    let legacy: ()->Void
    @Environment(\.dismiss) private var dismiss
    @State private var choosing=false
    @State private var busy=false
    @State private var result:ThreeMFImportResult?
    @State private var originalResult:ThreeMFImportResult?
    @State private var source:URL?
    @State private var progress=ThreeMFImportProgress("Choose a 3MF project",0)
    @State private var operation:Progress?
    @State private var failure:String?
    @State private var selectedPrinter:UUID?
    @State private var selectedMaterial:UUID?
    @State private var selectedQuote:UUID?
    @State private var useImportedTools=false
    @State private var fields=Set<String>()
    @State private var editor:Quote?
    @State private var changes=[ConfigurationDifference]()
    @State private var search=""
    @State private var generation=UUID()
    @State private var exportingDiagnostics=false
    @State private var supportDocument=ThreeMFSupportDocument(data:Data())
    private var printer:PrinterProfile? {state.library.printers.first{$0.id==selectedPrinter}}
    private var target:Quote? {state.library.quotes.first{$0.id==selectedQuote}}
    var body:some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:16) {
                    Text("3MF manufacturing import").font(.title2.bold())
                    Text("Review source evidence, matched profiles and manufacturing quantities before accepting selected updates.").foregroundStyle(.secondary)
                    ViewThatFits(in:.horizontal){HStack {Button("Choose 3MF"){choosing=true}.disabled(busy);Button("STL / legacy inspector",action:legacy).disabled(busy)};VStack(alignment:.leading){Button("Choose 3MF"){choosing=true}.disabled(busy);Button("STL / legacy inspector",action:legacy).disabled(busy)}}.padding(PQSpacing.md).pqGlass(.toolbar)
                    if busy {ProgressView(value:progress.fraction);HStack{Text(progress.stage);Button("Cancel"){operation?.cancel()}}}
                    if let failure {Text(failure).foregroundStyle(.red)}
                    if let project=result?.project {summary(project);reviewControls(project);evidence(project)}
                    diagnostics
                }.padding()
            }
            .toolbar {ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}
            .fileImporter(isPresented:$choosing,allowedContentTypes:[UTType(filenameExtension:"3mf") ?? .data]) { choice in
                switch choice {case .success(let url):source=url;analyze(url,force:false);case .failure(let e):failure=e.localizedDescription}
            }
            .fileExporter(isPresented:$exportingDiagnostics,document:supportDocument,contentType:.json,defaultFilename:"PrintQuote-3MF-diagnostics"){completion in if case .failure(let error)=completion{failure=error.localizedDescription}}
            .sheet(item:$editor){quote in QuoteEditor(state:state,initial:quote).desktopSheet(width:1050,height:760)}
            .onDisappear {operation?.cancel();generation=UUID()}
            .onChange(of:selectedPrinter){_,_ in rematch()}
            .onChange(of:selectedQuote){_,_ in rematch()}
        }
        #if os(macOS)
        .frame(minWidth:600,idealWidth:950,minHeight:550,idealHeight:800)
        #endif
    }
    @ViewBuilder private func summary(_ project:ImportedPrintProject)->some View {
        GroupBox("Source and detection") {
            VStack(alignment:.leading,spacing:6) {
                Text(project.filename).font(.headline)
                Text("\(project.slicer.name) · \(project.slicer.version ?? "version unknown") · \(project.slicer.confidence.rawValue) confidence")
                Text("Printer: \(project.printer.model?.value ?? project.printer.presetName?.value ?? "unknown")")
                Text("Physical toolheads: \(project.toolSystem.physicalToolheads.map{String($0.value)} ?? "needs review") · Filament inputs: \(project.toolSystem.filamentInputs.map{String($0.value)} ?? "unknown") · Feeder slots: \(project.toolSystem.feederSlots.map{String($0.value)} ?? "unknown")")
                Text("\(project.plates.count) plates · \(project.materials.count) material records · \(project.objects.filter{$0.id.hasPrefix("instance:")}.count) build instances")
                Text("Importer \(project.threeMFImporterVersion) · \(result?.cacheHit == true ? "Cached normalized data":"Re-analyzed file")").font(.caption)
                Text("SHA-256: \(project.sha256)").font(.caption2).textSelection(.enabled)
                Button("Export support diagnostics") {
                    do {if let result {supportDocument=ThreeMFSupportDocument(data:try ThreeMFImportService.supportSummary(result));exportingDiagnostics=true}}catch{failure=error.localizedDescription}
                }
                Text("Diagnostics include the filename, hash and metadata keys; source geometry and metadata values are excluded.").font(.caption2)
                Button("Re-analyze 3MF"){if let source{analyze(source,force:true)}}.disabled(busy)
            }.frame(maxWidth:.infinity,alignment:.leading)
        }
        let duplicates=state.library.quotes.filter{$0.manufacturingImport?.sha256==project.sha256}
        if !duplicates.isEmpty {GroupBox("Previously imported source"){ForEach(duplicates){q in HStack{Text(q.projectName);Button("Open existing quote"){editor=q};Button("Review selected updates"){selectedQuote=q.id}}}}}
        if !changes.isEmpty {DisclosureGroup("Changes since previous analysis"){ForEach(Array(changes.enumerated()),id:\.offset){_,d in Text("\(d.field): \(d.current) → \(d.imported)")}}}
    }
    @ViewBuilder private func reviewControls(_ project:ImportedPrintProject)->some View {
        GroupBox("Review configuration") {
            VStack(alignment:.leading,spacing:12) {
                Picker("Destination",selection:$selectedQuote){Text("New quote from this file").tag(UUID?.none);ForEach(state.library.quotes){Text($0.projectName).tag(Optional($0.id))}}
                Picker("Printer",selection:$selectedPrinter){Text("Keep current / choose later").tag(UUID?.none);ForEach(state.library.printers){Text($0.name).tag(Optional($0.id))}}
                if let match=result?.printerMatches.first{Text("Suggested match: \(match.name) · \(match.quality). Choose explicitly.").font(.caption)}
                Toggle("Use reviewed 3MF tool settings in this quote snapshot",isOn:$useImportedTools).disabled(project.toolSystem.reviewedSystem()==nil || printer==nil)
                Text("Saved printer modifications remain unchanged. Unchecked uses your configured printer.").font(.caption).foregroundStyle(.secondary)
                Picker("Material price",selection:$selectedMaterial){Text("Keep current inventory / configured price").tag(UUID?.none);ForEach(state.library.filaments){Text($0.name).tag(Optional($0.id))}}
                Text("Embedded slicer costs are evidence only and are never automatically applied.").font(.caption)
                ForEach(Array((result?.differences ?? []).enumerated()),id:\.offset){_,d in Text("\(d.field) — imported: \(d.imported); configured: \(d.current)").font(.caption)}
            }
        }
        GroupBox("Select pricing updates") {
            VStack(alignment:.leading,spacing:8) {
                Text("Select one source per field and one plate per quote. Total consumed filament is not automatically treated as model material.").font(.caption)
                ForEach(Array(project.estimates.enumerated()),id:\.offset){_,q in
                    let key=ThreeMFQuotePreview.key(q)
                    if ["model","support","supportInterface","purge","primeTower","printTime"].contains(q.role) {
                        Toggle(isOn:Binding(get:{fields.contains(key)},set:{if $0{fields.insert(key)}else{fields.remove(key)}})){Text("\(q.role): \(q.amount.value.formatted()) \(q.unit) · plate \(q.plateID ?? "unspecified")\n\(q.amount.sourcePath) · \(q.amount.confidence.rawValue)")}
                    } else {Text("\(q.role): \(q.amount.value.formatted()) \(q.unit) · evidence only").font(.caption)}
                }
                Button("Accept selected import into quote draft",action:accept).buttonStyle(.borderedProminent).disabled(busy)
                Text("The draft opens for review. Save it in the quote editor to persist changes.").font(.caption)
            }.frame(maxWidth:.infinity,alignment:.leading)
        }
    }
    @ViewBuilder private func evidence(_ project:ImportedPrintProject)->some View {
        DisclosureGroup("Materials, tools and assignments") {
            ForEach(Array(project.materials.enumerated()),id:\.offset){_,m in VStack(alignment:.leading){Text("\(m.id): \(m.family?.value ?? m.productName?.value ?? "unknown material") · \(m.sourceColorHex?.value ?? "color unknown")");if let cost=m.embeddedSlicerCost{Text("Embedded slicer cost: \(NSDecimalNumber(decimal:cost.value).stringValue) — unverified currency/basis").font(.caption)}}}
            ForEach(Array(project.materials.enumerated()),id:\.offset){_,m in
                if let match=result?.materialMatches[m.id]?.first {Text("\(m.id) → \(match.name) · \(match.quality) · review before selecting a price").font(.caption)}
            }
            ForEach(Array(project.toolSystem.tools.enumerated()),id:\.offset){_,tool in Text("Tool \(tool.index): \(tool.nozzleDiameterMM.map{String($0.value)} ?? "unknown") mm · \(tool.nozzleMaterial?.value ?? "nozzle material unknown")").font(.caption)}
            ForEach(Array(project.assignments.enumerated()),id:\.offset){_,a in Text("\(a.scope): \(a.role) → material \(a.materialID ?? "unknown"), tool \(a.toolIndex.map{String($0)} ?? "unknown")").font(.caption)}
        }
        DisclosureGroup("Transformed geometry in millimeters") {
            ForEach(project.objects.filter{$0.id.hasPrefix("instance:")}){o in VStack(alignment:.leading){Text(o.name ?? o.id);if let b=o.boundsMM{Text("\(b.value.dimensions.map{String(format:"%.2f",$0)}.joined(separator:" × ")) mm · \(o.triangleCount) triangles")};Text("Volume: \(o.enclosedVolumeMM3.map{String(format:"%.2f",$0.value)} ?? "not validated") mm³ · mirrored: \(o.mirrored == true ? "yes":"no")").font(.caption)}}
        }
        DisclosureGroup("Process and purge settings") {
            ForEach(Array((project.processSettings.settings+project.processSettings.purgeSettings).prefix(200).enumerated()),id:\.offset){_,s in Text("\(s.scope) · \(s.name): \(s.source.value)").font(.caption)}
        }
        DisclosureGroup("Unknown metadata") {
            TextField("Search metadata keys",text:$search).textFieldStyle(.roundedBorder)
            let rows=project.unmappedMetadata.filter{search.isEmpty || ($0.key+" "+($0.value ?? "")).localizedCaseInsensitiveContains(search)}
            Text("\(rows.count) retained records; showing first 200 matches.").font(.caption)
            ForEach(Array(rows.prefix(200).enumerated()),id:\.offset){_,m in Text("\(m.sourcePath) · \(m.scope) · \(m.key): \(m.value ?? "")").font(.caption).textSelection(.enabled)}
        }
    }
    @ViewBuilder private var diagnostics:some View {
        if let result {GroupBox("Import diagnostics"){VStack(alignment:.leading,spacing:8){ForEach(result.diagnostics){d in Text("\(d.severity.rawValue) · \(d.message)").font(.caption).foregroundStyle(d.severity == .fatalError ? .red:.secondary)}}.frame(maxWidth:.infinity,alignment:.leading)}}
    }
    private func analyze(_ url:URL,force:Bool) {
        generation=UUID();let request=generation
        let cancellation=Progress(totalUnitCount:1);operation=cancellation;busy=true;failure=nil;fields=[]
        let previous=result?.project
        Task {
            do {
                let parsed=try await ThreeMFImportService.importFile(url:url,forceReanalysis:force,cancelled:{cancellation.isCancelled},progress:{p in Task{@MainActor in if !cancellation.isCancelled{progress=p}}})
                if !cancellation.isCancelled && generation==request {originalResult=parsed;result=parsed;rematch();if let previous,let new=parsed.project{changes=ThreeMFQuotePreview.differences(old:previous,new:new)}}
            } catch {if !cancellation.isCancelled{failure=error.localizedDescription}}
            busy=false
        }
    }
    private func rematch() {
        guard let originalResult else{return}
        let printers=state.library.printers;let materials=state.library.filaments;let catalog=state.filamentCatalog?.products ?? [];let selected=printer ?? target?.printer;let request=generation;let printerID=selectedPrinter;let quoteID=selectedQuote
        Task {let reviewed=await Task.detached{ThreeMFImportService.review(originalResult,printers:printers,materials:materials,catalog:catalog,selectedPrinter:selected)}.value;if generation==request && selectedPrinter==printerID && selectedQuote==quoteID {result=reviewed}}
    }
    private func accept() {
        guard let project=result?.project else{return}
        var base=target ?? Quote()
        if target==nil {base.projectName=project.filename;base.number="PQ-"+String(UUID().uuidString.prefix(7));base.input.modelGrams=0;base.input.supportGrams=0;base.input.interfaceGrams=0;base.input.purgeGrams=0;base.input.towerGrams=0;base.input.printHours=0;base.currency=state.library.settings.currency;base.input.electricityRate=state.library.settings.electricityRate;base.input.taxRate=state.library.settings.taxRate}
        do {editor=try ThreeMFQuotePreview.apply(project,to:base,selected:fields,printer:printer,useImportedTools:useImportedTools,material:state.library.filaments.first{$0.id==selectedMaterial})}catch{failure=error.localizedDescription}
    }
}

private struct ThreeMFSupportDocument: FileDocument {
    static var readableContentTypes:[UTType]{[.json]}
    var data:Data
    init(data:Data){self.data=data}
    init(configuration:ReadConfiguration)throws{data=configuration.file.regularFileContents ?? Data()}
    func fileWrapper(configuration:WriteConfiguration)throws->FileWrapper{FileWrapper(regularFileWithContents:data)}
}
