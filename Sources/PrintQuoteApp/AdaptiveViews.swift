import SwiftUI

/// Wide windows show two panes; narrow windows and phones show one pane at a time.
struct AdaptiveLibrary<Master: View, Detail: View>: View {
    @Binding var selection: UUID?
    let backTitle: String
    @ViewBuilder var master: () -> Master
    @ViewBuilder var detail: () -> Detail
    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width >= 720 {
                HStack(spacing: 0) {
                    master().frame(width: min(340, geometry.size.width * 0.36))
                    Divider()
                    detail().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if selection != nil {
                VStack(alignment: .leading, spacing: 0) {
                    Button { selection = nil } label: { Label(backTitle, systemImage: "chevron.left") }.padding()
                    detail().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else { master() }
        }
    }
}

extension View {
    @ViewBuilder func desktopSheet(width: CGFloat, height: CGFloat) -> some View {
        #if os(macOS)
        self.frame(width: width, height: height)
        #else
        self.frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
    @ViewBuilder func desktopWindowMinimum() -> some View {
        #if os(macOS)
        self.frame(minWidth: 760, minHeight: 600)
        #else
        self
        #endif
    }
}
