import SwiftUI

struct ScriptDialogHost: View {
    @ObservedObject var broker: ScriptDialogBroker
    @State private var input = ""
    @State private var password = ""

    var body: some View {
        return Color.clear
            .frame(width: 0, height: 0)
            .onAppear { reset() }
            .onChange(of: broker.pendingRequest?.id) { _, _ in reset() }
            .alert(broker.pendingRequest?.host ?? "Website", isPresented: Binding(
                get: { broker.pendingRequest != nil },
                set: { _ in }
            ), presenting: broker.pendingRequest) { request in
                switch request.kind {
                case .prompt:
                    TextField("Response", text: $input)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                case .credentials:
                    TextField("User Name", text: $input)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                default:
                    EmptyView()
                }
                Button(acceptTitle(for: request.kind)) {
                    if request.kind == .credentials {
                        broker.resolve(.credentials(user: input, password: password), requestID: request.id)
                    } else {
                        broker.resolve(.accept(input), requestID: request.id)
                    }
                }
                if request.offersSuppression {
                    Button("Block Dialogs from This Page", role: .destructive) { broker.suppress(requestID: request.id) }
                }
                if request.kind != .alert {
                    Button("Cancel", role: .cancel) { broker.resolve(.cancel, requestID: request.id) }
                }
            } message: { request in Text(request.message) }
    }

    private func reset() {
        input = broker.pendingRequest?.defaultText ?? ""
        password = ""
    }

    private func acceptTitle(for kind: ScriptDialogKind) -> String {
        switch kind {
        case .externalLink: return "Open"
        case .download: return "Download"
        case .credentials: return "Sign In"
        default: return "OK"
        }
    }
}
