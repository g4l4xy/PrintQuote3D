import SwiftUI
import QuoteDomain
import QuoteData

struct QuoteEditor: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var quote: Quote
    @State private var saved = false
    @State private var compactTab = 0
    @State private var showingPrinterPicker = false
    @State private var showingMaterials = false
    @State private var editRevision=0
    @State private var saveStatus=""
    @State private var saveFailure:String?
    @State private var confirmClose=false
    @State private var reviewingModel=false
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var scheme
    private let existing: Bool
    init(state: AppState, initial: Quote?) {
        self.state = state; existing = initial != nil
        var q = initial ?? Quote()
        if initial == nil {
            q.number = "PQ-" + String(UUID().uuidString.prefix(8)).uppercased()
            q.currency = state.library.settings.currency
            q.input.electricityRate = state.library.settings.electricityRate
            q.input.taxRate = state.library.settings.taxRate
            q.expiresAt = Date().addingTimeInterval(Double(state.library.settings.expirationDays) * 86400)
            if let p = state.library.printers.first { q.printer = p; q.input.averageWatts = p.typicalPowerWatts; q.input.machineRate = p.machineRate; q.input.maintenanceRate = p.maintenanceRate }
            if let f = state.library.filaments.first { q.filament = f; q.input.pricePerKG = f.pricePerKG; q.input.supportPricePerKG = f.pricePerKG; q.input.interfacePricePerKG = f.pricePerKG }
        }
        _quote = State(initialValue:q)
    }
    private var headerSource: some View {
        HStack { Text(quote.number).font(.caption).foregroundStyle(.secondary); Button("Model & source",systemImage:"cube.transparent"){reviewingModel=true} }
    }
    private var headerActions: some View {
        HStack {
            Text(saveStatus.isEmpty ? (saved ? "Saved":"") : saveStatus).font(.caption).foregroundStyle(.secondary)
            if existing { Button("Close") { close() } }
            Button("Save quote") { save() }.keyboardShortcut("s",modifiers:.command).buttonStyle(.borderedProminent).disabled((try? result.get()) == nil)
        }
    }
    var result: Result<PricingResult, Error> { Result { try PricingEngine.calculate(quote.input) } }
    var body: some View {
        VStack(spacing:0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(existing ? quote.projectName : "New estimate").font(PQTypography.pageTitle)
                ViewThatFits(in:.horizontal) {
                    HStack { headerSource; Spacer(); headerActions }
                    VStack(alignment:.leading,spacing:PQSpacing.sm) { headerSource; headerActions }
                }
            }.padding(PQSpacing.lg).pqGlass(.toolbar).padding(PQSpacing.md)
            GeometryReader { geometry in
                if geometry.size.width >= PQLayout.expanded && !typeSize.isAccessibilitySize {
                    HStack(spacing: 0) {
                        if geometry.size.width >= PQLayout.wide {
                            modelContext.frame(width:220)
                            Divider()
                        }
                        inputForm.frame(maxWidth:.infinity)
                        Divider()
                        costBreakdown.frame(width:320).background(PQColor.panel(scheme == .dark))
                    }
                } else {
                    VStack(spacing: 0) {
                        Picker("Estimate view", selection: $compactTab) {
                            Text("Details").tag(0)
                            Text("Price breakdown").tag(1)
                        }.pickerStyle(.segmented).padding(.horizontal).padding(.bottom, 8)
                        if compactTab == 0 { inputForm } else { costBreakdown }
                    }
                }
            }
        }
        .pqWorkspace()
        .sheet(isPresented:$reviewingModel){ModelInspectionView(state:state)}
        .task(id:editRevision){if editRevision>0{await autosave()}}
        .onDisappear{if saved{let id=quote.id;Task{try? await state.recovery.discard(id)}}}
        .interactiveDismissDisabled(!saved && editRevision>0)
        .confirmationDialog("This draft has unsaved changes",isPresented:$confirmClose,titleVisibility:.visible){Button("Keep editing",role:.cancel){};Button("Close without saving again",role:.destructive){dismiss()}} message:{Text(saveFailure ?? "A recovery draft is kept locally. Wait for Saved before closing if you want it in the quote library.")}
        .onChange(of:quote.input) { _,_ in changed() }
        .onChange(of:quote.projectName) { _,_ in changed() }
        .onChange(of:quote.customer) { _,_ in changed() }
        .onChange(of:quote.status) { _,_ in changed() }
        .onChange(of:quote.notes) { _,_ in changed() }
        .onChange(of:quote.expiresAt) { _,_ in changed() }
        .onChange(of:quote.printer) { _,_ in changed() }
        .onChange(of:quote.filament) { _,_ in changed() }
        .onChange(of:quote.preset) { _,_ in changed() }
    }
    private var modelContext:some View {
        ScrollView {VStack(alignment:.leading,spacing:PQSpacing.lg){
            Label("Model & source",systemImage:"cube.transparent").font(PQTypography.sectionTitle)
            if let source=quote.manufacturingImport {Text(source.filename).font(.headline);Text("Accepted manufacturing data").foregroundStyle(.secondary);Text("Parser \(source.parserVersion)").font(.caption)}
            else {Text("Manual estimate").font(.headline);Text("Inspect a source file to review geometry and manufacturing evidence.").foregroundStyle(.secondary)}
            Button("Inspect STL / 3MF"){reviewingModel=true}.buttonStyle(.bordered)
            Divider()
            PQSectionHeader(title:"Equipment",subtitle:quote.printer?.name ?? "Choose a printer")
            Text(quote.filament?.name ?? "Choose material").font(.subheadline)
            Text("Source inspection does not silently replace this quote's values.").font(.caption).foregroundStyle(.secondary)
        }.padding(PQSpacing.lg)}
    }
    private var inputForm: some View {
                Form {
                    SwiftUI.Section("Project") {
                        TextField("Project name",text:$quote.projectName)
                        TextField("Customer",text:$quote.customer)
                        Picker("Status", selection:$quote.status) { ForEach(["draft","sent","approved","rejected","expired","convertedToJob"],id:\.self) { Text($0.capitalized).tag($0) } }
                        DatePicker("Expires",selection:$quote.expiresAt,displayedComponents:.date)
                        TextField("Notes",text:$quote.notes,axis:.vertical)
                    }
                    SwiftUI.Section("Equipment & material") {
                        Button(quote.printer?.name ?? "Select printer") { showingPrinterPicker = true }
                            .sheet(isPresented: $showingPrinterPicker) {
                                PrinterPicker(printers: state.library.printers) { p in
                                    state.used("printers",p.id.uuidString)
                                    quote.printer = p
                                    if quote.input.toolJob != nil { quote.input.toolJob?.system = p.toolSystem ?? PrinterToolSystem() }
                                    quote.input.averageWatts = p.typicalPowerWatts
                                    quote.input.machineRate = p.machineRate
                                    quote.input.maintenanceRate = p.maintenanceRate
                                }
                            }
                        if quote.printer?.externalProfile?.userOverride == false {
                            Text("Imported technical profile: enter average power, machine and maintenance rates below. Tool setup needs review.").font(.caption).foregroundStyle(.orange)
                        }
                        Button(quote.filament?.name ?? "Choose material") { showingMaterials = true }
                            .sheet(isPresented: $showingMaterials) {
                                MaterialsView(state: state, onUse: { f in
                                    state.usedMaterial(f)
                                    quote.filament = f
                                    quote.input.pricePerKG = f.pricePerKG
                                    quote.input.supportPricePerKG = f.pricePerKG
                                    quote.input.interfacePricePerKG = f.pricePerKG
                                    showingMaterials = false
                                }).desktopSheet(width: 950, height: 720)
                            }
                        Menu(quote.preset?.name ?? "Apply pricing preset") { ForEach(state.library.presets) { p in Button(p.name) { state.used("presets",p.id.uuidString); quote.preset = p; quote.input.pricingMode = p.mode; quote.input.profitRate = p.rate; quote.input.machineRate = p.machineRate; quote.input.laborRate = p.laborRate; quote.input.minimumCharge = p.minimumCharge; quote.input.materialMultiplier = p.materialMultiplier; quote.input.rushMultiplier = p.rushMultiplier } } }
                    }
                    SwiftUI.Section("Manufacturing mode") {
                        Toggle("Assign materials to physical tools", isOn: Binding(get: { quote.input.toolJob != nil }, set: { enabled in
                            if enabled { enableToolAssignments() } else { quote.input.toolJob = nil }
                        }))
                    }
                    if quote.input.toolJob != nil {
                        ToolAssignmentsEditor(job: Binding(get: {quote.input.toolJob ?? ToolJob()}, set: {quote.input.toolJob = $0}), filaments: state.library.filaments)
                    } else {
                    SwiftUI.Section("Material consumption") {
                        DecimalField(title:"Model (g)",value:$quote.input.modelGrams)
                        DecimalField(title:"Supports (g)",value:$quote.input.supportGrams)
                        DecimalField(title:"Support interface (g)",value:$quote.input.interfaceGrams)
                        DecimalField(title:"Purge / flush (g)",value:$quote.input.purgeGrams)
                        DecimalField(title:"Prime tower (g)",value:$quote.input.towerGrams)
                        DecimalField(title:"Startup purge (g)",value:$quote.input.startupGrams)
                        DecimalField(title:"Model / waste price per kg",value:$quote.input.pricePerKG)
                        DecimalField(title:"Support price per kg",value:$quote.input.supportPricePerKG)
                        DecimalField(title:"Interface price per kg",value:$quote.input.interfacePricePerKG)
                    }
                    }
                    SwiftUI.Section("Machine, electricity & labor") {
                        DecimalField(title:"Print time (hours)",value:$quote.input.printHours)
                        DecimalField(title:"Average printer watts",value:$quote.input.averageWatts)
                        DecimalField(title:"Electricity per kWh",value:$quote.input.electricityRate)
                        DecimalField(title:"Machine rate per hour",value:$quote.input.machineRate)
                        DecimalField(title:"Maintenance per hour",value:$quote.input.maintenanceRate)
                        DecimalField(title:"Labor minutes",value:$quote.input.laborMinutes)
                        DecimalField(title:"Labor hourly rate",value:$quote.input.laborRate)
                    }
                    DisclosureGroup("Advanced · drying & direct costs") {
                        DecimalField(title:"Dryer watts",value:$quote.input.dryerWatts)
                        DecimalField(title:"Drying hours",value:$quote.input.dryingHours)
                        DecimalField(title:"Jobs sharing drying cycle",value:$quote.input.dryingSharedJobs)
                        DecimalField(title:"Nozzle / consumable wear",value:$quote.input.wearCost)
                        DecimalField(title:"Packaging",value:$quote.input.packaging)
                        DecimalField(title:"Outside services",value:$quote.input.outsideServices)
                        DecimalField(title:"Other direct costs",value:$quote.input.otherCosts)
                    }
                    SwiftUI.Section("Pricing rules · enter rates as decimals (0.40 = 40%)") {
                        Picker("Pricing method",selection:$quote.input.pricingMode) { Text("Target margin").tag(PricingMode.margin); Text("Markup").tag(PricingMode.markup) }
                        DecimalField(title:"Profit rate",value:$quote.input.profitRate)
                        DecimalField(title:"Failure probability",value:$quote.input.failureProbability)
                        DecimalField(title:"Overhead rate",value:$quote.input.overheadRate)
                        DecimalField(title:"Material selling multiplier",value:$quote.input.materialMultiplier)
                        DecimalField(title:"Minimum charge",value:$quote.input.minimumCharge)
                        DecimalField(title:"Rush multiplier",value:$quote.input.rushMultiplier)
                        DecimalField(title:"Discount rate",value:$quote.input.discountRate)
                        DecimalField(title:"Tax rate",value:$quote.input.taxRate)
                        DecimalField(title:"Shipping",value:$quote.input.shipping)
                    }
                }.formStyle(.grouped)
    }
    private var costBreakdown: some View {
                ScrollView {
                    VStack(alignment:.leading,spacing:16) {
                        switch result {
                        case .success(let r):
                            Text("CUSTOMER PRICE").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(money(r.total,currency:quote.currency)).font(PQTypography.display).monospacedDigit().foregroundStyle(PQColor.accent(scheme == .dark))
                            Divider()
                            PQSectionHeader(title:"Cost breakdown")
                            ForEach(r.components.filter {$0.amount != 0}) { c in row(c.name,c.amount) }
                            Divider(); row("Production cost",r.productionCost)
                            row("Overhead",r.overhead)
                            Divider()
                            row("Subtotal",r.subtotal); row("Discount", -r.discount); row("Tax",r.tax); row("Shipping",r.shipping)
                            if r.minimumApplied { Label("Minimum charge applied",systemImage:"info.circle").foregroundStyle(.orange) }
                            Divider()
                            Text("Consumed: \(r.totalGrams.formatted()) g")
                            Text("Material efficiency: \((r.materialEfficiency * 100).formatted(.number.precision(.fractionLength(1))))%")
                            if let job = quote.input.toolJob, let toolCost = try? ToolCostEngine.calculate(job, printHours: quote.input.printHours) {
                                Text("Added change time: \((toolCost.changeHours * 60).formatted(.number.precision(.fractionLength(2)))) min")
                                ForEach(Array(Set(toolCost.warnings)).sorted(), id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                            }
                            if quote.input.toolJob == nil && quote.input.purgeGrams > quote.input.modelGrams { Label("Purge exceeds final-part weight",systemImage:"exclamationmark.triangle").foregroundStyle(.orange) }
                            Text("Manual estimate · verify against slicer output. Print hours should include material changes. Labor should include setup, drying handling and finishing.").font(.caption).foregroundStyle(.secondary)
                        case .failure(let error): Label(error.localizedDescription,systemImage:"exclamationmark.triangle").foregroundStyle(.orange)
                        }
                    }.padding(PQSpacing.section)
                }
    }
    func enableToolAssignments() {
        var job = ToolJob(); job.system = quote.printer?.toolSystem ?? PrinterToolSystem()
        let inputs: [(MaterialRole, Decimal, Decimal)] = [
            (.model, quote.input.modelGrams, quote.input.pricePerKG),
            (.support, quote.input.supportGrams, quote.input.supportPricePerKG),
            (.interface, quote.input.interfaceGrams, quote.input.interfacePricePerKG),
            (.waste, quote.input.purgeGrams + quote.input.towerGrams + quote.input.startupGrams, quote.input.pricePerKG)
        ]
        for (role, grams, price) in inputs where grams > 0 {
            var assignment = ToolMaterialAssignment(); assignment.role = role; assignment.grams = grams; assignment.pricePerKG = price
            assignment.materialID = quote.filament?.id; assignment.materialName = quote.filament?.name ?? "Manual material"
            assignment.materialFamily = quote.filament?.materialFamily ?? "Unknown"; assignment.colorName = quote.filament?.colorName ?? ""
            job.assignments.append(assignment)
        }
        if job.assignments.isEmpty { job.assignments.append(ToolMaterialAssignment()) }
        quote.input.toolJob = job
    }
    func row(_ name:String,_ value:Decimal) -> some View { HStack { Text(name); Spacer(); Text(money(value,currency:quote.currency)).monospacedDigit() } }
    func changed(){saved=false;editRevision+=1;saveStatus="Saving…"}
    func close(){if !saved && editRevision>0{confirmClose=true}else{dismiss()}}
    func autosave() async {
        let snapshot=quote
        do {
            try await state.recovery.save(snapshot)
            try await Task.sleep(for:.milliseconds(800));try Task.checkCancellation()
            var prepared=snapshot;prepared.result=try PricingEngine.calculate(snapshot.input)
            let previousError=state.error
            if state.save(prepared){saved=true;saveStatus="Saved";saveFailure=nil}
            else{saveFailure=state.error;state.error=previousError;saveStatus="Save failed — recovery draft retained"}
        }catch is CancellationError{return}
        catch{saveStatus="Save failed — keep editing";saveFailure=error.localizedDescription}
    }
    func save() { do { quote.schemaVersion = 2; quote.result = try result.get(); saved = state.save(quote);saveStatus=saved ? "Saved":"Save failed";if saved{Task{try? await state.recovery.discard(quote.id)}} } catch { state.error = error.localizedDescription;saveStatus="Save failed" } }
}
