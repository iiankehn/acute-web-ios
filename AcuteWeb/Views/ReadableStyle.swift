import SwiftUI

extension ShapeStyle where Self == Color {
    /// Secondary text that keeps readable contrast on grouped and card backgrounds, where the
    /// system's secondary label color falls short in accessibility audits.
    static var readableSecondary: Color { Color.primary.opacity(0.72) }
}
