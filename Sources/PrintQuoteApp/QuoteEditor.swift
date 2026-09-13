import SwiftUI
import QuoteDomain

struct QuoteEditor: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var quote: Quote
    @State private var saved = false
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
    var result: Result<PricingResult, Error> { Result { try PricingEngine.calculate(quote.input) } }
    var body: some View {
        VStack(spacing:0) {
            HStack { VStack(alignment:.leading) { Text(existing ? "Edit quote" : "New estimate").font(.title.bold()); Text(quote.number).foregroundStyle(.secondary) }; Spacer(); if saved { Text("Saved locally").font(.caption).foregroundStyle(.secondary) }; if existing { Button("Close") { dismiss() } }; Button("Save quote") { save() }.buttonStyle(.borderedProminent).disabled((try? result.get()) == nil) }.padding(24)
            // Use the available detail width, not the combined intrinsic widths of
            // the grouped form and cost breakdown (which can expand the window).
            GeometryReader { geometry in
                let formWidth = (geometry.size.width - 1) * 0.58
                HStack(spacing: 0) {
                Form {
                    SwiftUI.Section("Project") {
                        TextField("Project name",text:$quote.projectName)
                        TextField("Customer",text:$quote.customer)
                        Picker("Status", selection:$quote.status) { ForEach(["draft","sent","approved","rejected","expired","convertedToJob"],id:\.self) { Text($0.capitalized).tag($0) } }
                        DatePicker("Expires",selection:$quote.expiresAt,displayedComponents:.date)
                        TextField("Notes",text:$quote.notes,axis:.vertical)
                    }
                    SwiftUI.Section("Equipment & material") {
                        Menu(quote.printer?.name ?? "Select printer") {
                            ForEach(state.library.printers) { p in Button(p.name) { quote.printer = p; if quote.input.toolJob != nil { quote.input.toolJob?.system = p.toolSystem ?? PrinterToolSystem() }; quote.input.averageWatts = p.typicalPowerWatts; quote.input.machineRate = p.machineRate; quote.input.maintenanceRate = p.maintenanceRate } }
                        }
                        Menu(quote.filament?.name ?? "Select filament") {
                            ForEach(state.library.filaments) { f in Button(f.name) { quote.filament = f; quote.input.pricePerKG = f.pricePerKG; quote.input.supportPricePerKG = f.pricePerKG; quote.input.interfacePricePerKG = f.pricePerKG } }
                        }
                        Menu(quote.preset?.name ?? "Apply pricing preset") { ForEach(state.library.presets) { p in Button(p.name) { quote.preset = p; quote.input.pricingMode = p.mode; quote.input.profitRate = p.rate; quote.input.machineRate = p.machineRate; quote.input.laborRate = p.laborRate; quote.input.minimumCharge = p.minimumCharge; quote.input.materialMultiplier = p.materialMultiplier; quote.input.rushMultiplier = p.rushMultiplier } } }
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
                    SwiftUI.Section("Drying & direct costs") {
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
                }.formStyle(.grouped).frame(width: formWidth)
                Divider()
                ScrollView {
                    VStack(alignment:.leading,spacing:16) {
                        Text("COST BREAKDOWN").font(.headline).foregroundStyle(.secondary)
                        switch result {
                        case .success(let r):
                            ForEach(r.components.filter {$0.amount != 0}) { c in row(c.name,c.amount) }
                            Divider(); row("Production cost",r.productionCost)
                            row("Overhead",r.overhead)
                            Divider()
                            Text("CUSTOMER PRICE").font(.headline).foregroundStyle(.secondary)
                            Text(money(r.total,currency:quote.currency)).font(.system(size:42,weight:.semibold,design:.rounded)).foregroundStyle(.blue)
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
                    }.padding(24)
                }.frame(width: max(0, geometry.size.width - formWidth - 1))
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }.onChange(of:quote.input) { _,_ in saved = false }
        .onChange(of:quote.projectName) { _,_ in saved = false }
        .onChange(of:quote.customer) { _,_ in saved = false }
        .onChange(of:quote.status) { _,_ in saved = false }
        .onChange(of:quote.notes) { _,_ in saved = false }
        .onChange(of:quote.expiresAt) { _,_ in saved = false }
        .onChange(of:quote.printer) { _,_ in saved = false }
        .onChange(of:quote.filament) { _,_ in saved = false }
        .onChange(of:quote.preset) { _,_ in saved = false }
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
    func save() { do { quote.schemaVersion = 2; quote.result = try result.get(); saved = state.save(quote) } catch { state.error = error.localizedDescription } }
}
