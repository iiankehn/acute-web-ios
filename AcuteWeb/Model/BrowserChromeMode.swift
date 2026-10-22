import CoreGraphics
import SwiftUI

/// Where the browser controls go. Chosen from size classes and the system's vertical-bar edge,
/// never from the device model, so iPhone, iPad and iPhone Duo poses share one set of rules.
enum BrowserChromeMode: Equatable {
    /// A single capsule row at the top or bottom of a compact-width window.
    case compactRow(atBottom: Bool)
    /// A capsule row at the top of a regular-width window, with Back and Forward in the row.
    case wideRow
    /// Back, Forward, Tabs and More on a side rail; the capsule row keeps the address and tabs.
    case rail(HorizontalEdge)

    static func resolve(horizontalSizeClass: UserInterfaceSizeClass?, verticalBarEdge: HorizontalEdge?,
                        prefersBottomControls: Bool) -> BrowserChromeMode {
        if let verticalBarEdge { return .rail(verticalBarEdge) }
        if horizontalSizeClass == .regular { return .wideRow }
        return .compactRow(atBottom: prefersBottomControls)
    }

    var controlsAtBottom: Bool {
        if case .compactRow(let atBottom) = self { return atBottom }
        return false
    }

    var railEdge: HorizontalEdge? {
        if case .rail(let edge) = self { return edge }
        return nil
    }
}

/// How an active fold divides the window, from the system's reserved division regions.
enum FoldLayout: Equatable {
    case none
    /// A vertical fold. Controls stay out of `leadingEnd...trailingStart`.
    case book(leadingEnd: CGFloat, trailingStart: CGFloat)
    /// A horizontal fold. The page sits above `topEnd`; controls start below `bottomStart`.
    case tabletop(topEnd: CGFloat, bottomStart: CGFloat)

    /// `divisions` are active division frames, already expanded by their margins, in the window's coordinates.
    static func resolve(divisions: [CGRect], in size: CGSize) -> FoldLayout {
        let bounds = CGRect(origin: .zero, size: size)
        guard let fold = divisions.map({ $0.intersection(bounds) }).filter({ !$0.isNull && !$0.isEmpty })
            .max(by: { $0.width * $0.height < $1.width * $1.height }) else { return .none }
        if fold.height >= fold.width {
            // Only a fold that crosses the middle of the window splits it into usable halves.
            guard fold.minX > 0, fold.maxX < size.width else { return .none }
            return .book(leadingEnd: fold.minX, trailingStart: fold.maxX)
        }
        guard fold.minY > 0, fold.maxY < size.height else { return .none }
        return .tabletop(topEnd: fold.minY, bottomStart: fold.maxY)
    }
}
