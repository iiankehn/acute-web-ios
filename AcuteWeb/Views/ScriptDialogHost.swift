import SwiftUI

struct ScriptDialogHost: View {
    @ObservedObject var broker: ScriptDialogBroker
    @State private var input = ""

    var body: some View {
        return Color.clear
            .frame(width: 0, height: 0)
            .onAppear { input = broker.pendingRequest?.defaultText ?? "" }
            .onChange(of: broker.pendingRequest?.id) { _, _ in
                input = broker.pendingRequest?.defaultText ?? ""
            }
            .alert(broker.pendingRequest?.host ?? "Website", isPresented: Binding(
                get: { broker.pendingRequest != nil },
                set: { _ in }
            ), presenting: broker.pendingRequest) { request in
                if request.kind == .prompt {
                    TextField("Response", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Button("OK") { broker.resolve(.accept(input), requestID: request.id) }
                if request.kind != .alert {
                    Button("Cancel", role: .cancel) { broker.resolve(.cancel, requestID: request.id) }
                }
            } message: { request in Text(request.message) }
    }
}
