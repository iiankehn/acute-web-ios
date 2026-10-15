import SwiftUI

/// Explicit scalable text avoids the toolbar's fixed-size confirmation label.
struct SheetDoneButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Done")
                .font(.body)
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
