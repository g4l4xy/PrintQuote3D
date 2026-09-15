import SwiftUI

// Semantic adapter for SharedSchemas/pq-design-tokens.json.
enum PQSpacing { static let xs:CGFloat=4, sm:CGFloat=8, md:CGFloat=12, lg:CGFloat=16, xl:CGFloat=20, section:CGFloat=24, page:CGFloat=32 }
enum PQRadius { static let control:CGFloat=6, panel:CGFloat=12, floating:CGFloat=20 }
enum PQElevation { static let tools:CGFloat=3, modal:CGFloat=8 }
enum PQBorder { static let normal:CGFloat=1, emphasized:CGFloat=2 }
enum PQIconSize { static let navigation:CGFloat=24, identity:CGFloat=40 }
enum PQControlSize { static let desktop:CGFloat=32, touch:CGFloat=44 }
enum PQTypography { static let display:Font = .largeTitle.weight(.semibold), pageTitle:Font = .title.weight(.semibold), sectionTitle:Font = .title3.weight(.semibold), technical:Font = .body.monospacedDigit() }
enum PQMotion { static let fast=0.12, standard=0.18, pane=0.24 }
enum PQLayout {
    static let medium:CGFloat=600, expanded:CGFloat=840, wide:CGFloat=1200
    static var defaultLibraryLayout:String {
        #if os(macOS)
        "Table"
        #else
        "Cards"
        #endif
    }
}
enum PQColor {
    static func hex(_ n:UInt32)->Color {Color(red:Double((n>>16)&255)/255,green:Double((n>>8)&255)/255,blue:Double(n&255)/255)}
    static func workspace(_ dark:Bool)->Color{hex(dark ? 0x151A21:0xF4F6F9)}
    static func panel(_ dark:Bool)->Color{hex(dark ? 0x1E2631:0xFFFFFF)}
    static func raised(_ dark:Bool)->Color{hex(dark ? 0x293545:0xE8EDF4)}
    static func accent(_ dark:Bool)->Color{hex(dark ? 0x8BB5FF:0x205BCD)}
}
private struct PQOpaquePreviewKey:EnvironmentKey {static let defaultValue=false}
extension EnvironmentValues {var pqOpaquePreview:Bool {get{self[PQOpaquePreviewKey.self]}set{self[PQOpaquePreviewKey.self]=newValue}}}
enum PQGlassMaterial {case navigation, toolbar, floating, inspector, modal}
private struct PQGlassModifier:ViewModifier {
    var role:PQGlassMaterial
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.pqOpaquePreview) private var opaquePreview
    @AppStorage("pq.reduceEffects") private var reduceEffects=false
    func body(content:Content)->some View {
        let shape=RoundedRectangle(cornerRadius:role == .toolbar ? PQRadius.panel:PQRadius.floating)
        if reduceTransparency || reduceEffects || opaquePreview || contrast == .increased {
            content.background(PQColor.panel(scheme == .dark),in:shape).overlay(shape.stroke(.primary.opacity(0.35),lineWidth:PQBorder.emphasized))
        } else if #available(macOS 26.0,iOS 26.0,*) {
            content.glassEffect(.regular,in:shape)
        } else {
            content.background(.regularMaterial,in:shape).overlay(shape.stroke(.primary.opacity(0.15),lineWidth:PQBorder.normal))
        }
    }
}
private struct PQWorkspaceModifier:ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content:Content)->some View{content.background(PQColor.workspace(scheme == .dark)).tint(PQColor.accent(scheme == .dark))}
}
extension View {
    func pqGlass(_ role:PQGlassMaterial = .toolbar)->some View{modifier(PQGlassModifier(role:role))}
    func pqWorkspace()->some View{modifier(PQWorkspaceModifier())}
}
struct PQSectionHeader:View {
    var title:String
    var subtitle:String=""
    var body:some View{VStack(alignment:.leading,spacing:PQSpacing.xs){Text(title).font(PQTypography.sectionTitle);if !subtitle.isEmpty{Text(subtitle).font(.subheadline).foregroundStyle(.secondary)}}.frame(maxWidth:.infinity,alignment:.leading).accessibilityElement(children:.combine)}
}
struct PQMetric:View {
    var title:String, value:String, icon:String
    @Environment(\.colorScheme) private var scheme
    var body:some View{VStack(alignment:.leading,spacing:PQSpacing.md){Label(title,systemImage:icon).font(.subheadline).foregroundStyle(.secondary);Text(value).font(PQTypography.display).monospacedDigit().textSelection(.enabled)}.frame(maxWidth:.infinity,alignment:.leading).padding(PQSpacing.lg).background(PQColor.panel(scheme == .dark),in:RoundedRectangle(cornerRadius:PQRadius.panel)).accessibilityElement(children:.combine)}
}
struct PQAppearanceSettings:View {
    @AppStorage("pq.appearance") private var appearance="System"
    @AppStorage("pq.reduceEffects") private var reduceEffects=false
    var body:some View {
        SwiftUI.Section("Appearance & accessibility") {
            Picker("Theme",selection:$appearance){ForEach(["System","Light","Dark"],id:\.self){Text($0).tag($0)}}
            Toggle("Reduce visual effects",isOn:$reduceEffects)
            Text("Opaque tool surfaces retain the same controls. System contrast, text size and accessibility settings remain respected.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
/// Representative component prototypes; fixture values are preview-only and never saved.
struct PQDesignPreview:View {
    var screen:String
    @State private var query=""
    var body:some View {
        ScrollView{VStack(alignment:.leading,spacing:PQSpacing.section){
            HStack{BrandIcon().frame(width:PQIconSize.identity,height:PQIconSize.identity);Text(screen).font(PQTypography.pageTitle);Spacer()}
            HStack{TextField("Search \(screen.lowercased())",text:$query);Button("Actions",systemImage:"ellipsis"){}}.padding(PQSpacing.md).pqGlass()
            if screen == "Dashboard" {PQMetric(title:"Quote activity",value:"12",icon:"doc.text");PQSectionHeader(title:"Recent quotes",subtitle:"Your work, ready to continue")}
            else if screen == "Quote Builder" {PQSectionHeader(title:"Manufacturing",subtitle:"Printer, material and process");PQMetric(title:"Customer price",value:"$55.52",icon:"dollarsign.circle")}
            else if screen == "Settings" {Form{PQAppearanceSettings()}.frame(minHeight:220)}
            else {PQSectionHeader(title:screen.contains("Filament") ? "Material specifications":"Machine capabilities",subtitle:"Source values and your overrides stay separate")}
            ForEach(0..<4){n in HStack{Text(n==0 ? "Overview":"Technical property \(n)");Spacer();Text(n==0 ? "Ready":"Unknown").font(PQTypography.technical)}.padding(.vertical,PQSpacing.sm);Divider()}
        }.padding(PQSpacing.section)}.pqWorkspace()
    }
}
#Preview("Dashboard · Light"){PQDesignPreview(screen:"Dashboard").preferredColorScheme(.light).frame(width:900,height:650)}
#Preview("Quote Builder · Dark"){PQDesignPreview(screen:"Quote Builder").preferredColorScheme(.dark).frame(width:1000,height:700)}
#Preview("Filament Library · Compact"){PQDesignPreview(screen:"Filament Library").frame(width:390,height:700)}
#Preview("Printer Library · Medium"){PQDesignPreview(screen:"Printer Library").frame(width:700,height:700)}
#Preview("Printer Detail · Large text"){PQDesignPreview(screen:"Printer Detail").environment(\.dynamicTypeSize,.accessibility2).frame(width:600,height:700)}
#Preview("Filament Detail · Opaque fallback"){PQDesignPreview(screen:"Filament Detail").environment(\.pqOpaquePreview,true).frame(width:600,height:700)}
#Preview("Settings · Opaque fallback"){PQDesignPreview(screen:"Settings").environment(\.pqOpaquePreview,true).frame(width:700,height:700)}
