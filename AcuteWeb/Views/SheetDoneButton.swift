import SwiftUI

/// Explicit scalable text avoids the toolbar's fixed-size confirmation label.
struct SheetDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button("Done", systemImage: "checkmark", action: action)
            .labelStyle(.iconOnly)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("sheetDone")
    }
}
