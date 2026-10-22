import SwiftUI

extension View {
    /// Reports the system's preferred vertical-bar edge (iOS 27.1 and later), or nil where bars stay horizontal.
    func readVerticalBarEdge(into edge: Binding<HorizontalEdge?>) -> some View {
        modifier(VerticalBarEdgeReader(edge: edge))
    }

    /// Reports how an active fold divides this view (iOS 27.1 and later), so controls can stay clear of it.
    func readFoldLayout(into fold: Binding<FoldLayout>) -> some View {
        background {
            if #available(iOS 27.1, *) {
                GeometryReader { proxy in
                    let layout = FoldLayout.resolve(divisions: proxy.reservedRegions(kind: .division).map(\.paddedFrame),
                                                    in: proxy.size)
                    Color.clear
                        .onAppear { fold.wrappedValue = layout }
                        .onChange(of: layout) { _, value in fold.wrappedValue = value }
                }
            }
        }
    }

    /// Keeps a view clear of hardware occlusions such as the outer front camera (iOS 27.1 and later).
    func avoidingOcclusions() -> some View {
        modifier(OcclusionPadding())
    }
}

private struct VerticalBarEdgeReader: ViewModifier {
    @Binding var edge: HorizontalEdge?

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.modifier(SystemVerticalBarEdge(edge: $edge))
        } else {
            content
        }
    }
}

@available(iOS 27.1, *)
private struct SystemVerticalBarEdge: ViewModifier {
    @Environment(\.toolbarVerticalEdge) private var systemEdge
    @Binding var edge: HorizontalEdge?

    func body(content: Content) -> some View {
        content.onChange(of: systemEdge, initial: true) { _, value in edge = value }
    }
}

private struct OcclusionPadding: ViewModifier {
    @State private var insets = EdgeInsets()

    func body(content: Content) -> some View {
        content
            .padding(insets)
            .background {
                if #available(iOS 27.1, *) {
                    GeometryReader { proxy in
                        let value = Self.insets(for: proxy.reservedRegions(kind: .occlusion).map(\.paddedFrame), in: proxy.size)
                        Color.clear
                            .onAppear { insets = value }
                            .onChange(of: value) { _, newValue in insets = newValue }
                    }
                }
            }
    }

    /// Pushes content away from occlusions touching an edge, by the depth they reach into the view.
    static func insets(for occlusions: [CGRect], in size: CGSize) -> EdgeInsets {
        var result = EdgeInsets()
        for rect in occlusions where !rect.isEmpty {
            if rect.minY <= 0 { result.top = max(result.top, rect.maxY) }
            else if rect.maxY >= size.height { result.bottom = max(result.bottom, size.height - rect.minY) }
        }
        return result
    }
}

@available(iOS 27.1, *)
private extension ReservedRegion {
    /// The region plus the system's recommended clearance around it.
    var paddedFrame: CGRect {
        CGRect(x: frame.minX - margins.leading, y: frame.minY - margins.top,
               width: frame.width + margins.leading + margins.trailing,
               height: frame.height + margins.top + margins.bottom)
    }
}
