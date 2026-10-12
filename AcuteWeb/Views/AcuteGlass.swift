import SwiftUI

struct AcuteGlassContainer<Content: View>: View {
    let content: Content
    let spacing: CGFloat

    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.spacing = spacing
    }

    var body: some View {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
#else
        content
#endif
    }
}

extension View {
    func acuteGlass(cornerRadius: CGFloat) -> some View {
        modifier(AcuteGlassSurface(cornerRadius: cornerRadius))
    }
}

private struct AcuteGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.primary.opacity(contrast == .increased ? 0.45 : 0.15), lineWidth: 1)
                        .allowsHitTesting(false)
                }
        } else {
#if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.primary.opacity(contrast == .increased ? 0.45 : 0.1), lineWidth: 1)
                        .allowsHitTesting(false)
                }
        }
#else
        content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.primary.opacity(contrast == .increased ? 0.45 : 0.1), lineWidth: 1)
                    .allowsHitTesting(false)
            }
#endif
        }
    }
}
