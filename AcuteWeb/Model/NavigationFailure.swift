import Foundation

/// A page-load failure with a plain-language explanation and the recovery actions that make sense for it.
struct NavigationFailure: Equatable {
    let message: String
    let domain: String
    let code: Int

    /// WebKit reports these when a navigation becomes a download or is handed to another app.
    static func isIgnorable(_ error: Error) -> Bool {
        let failure = error as NSError
        if failure.domain == NSURLErrorDomain && failure.code == NSURLErrorCancelled { return true }
        // WebKitErrorFrameLoadInterruptedByPolicyChange and WebKitErrorPlugInWillHandleLoad.
        return failure.domain == "WebKitErrorDomain" && [102, 204].contains(failure.code)
    }

    init(message: String, domain: String = "", code: Int = 0) {
        self.message = message
        self.domain = domain
        self.code = code
    }

    init(_ error: Error) {
        let failure = error as NSError
        self.init(message: Self.explanation(for: failure), domain: failure.domain, code: failure.code)
    }

    var isCertificateProblem: Bool {
        domain == NSURLErrorDomain && [
            NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasBadDate,
            NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorServerCertificateNotYetValid,
            NSURLErrorClientCertificateRejected, NSURLErrorClientCertificateRequired
        ].contains(code)
    }

    /// Plain HTTP is offered only for failures where the site may not support HTTPS, never for certificate problems.
    func offersInsecureRetry(for url: URL?) -> Bool {
        guard url?.scheme?.lowercased() == "https", domain == NSURLErrorDomain else { return false }
        return [NSURLErrorSecureConnectionFailed, NSURLErrorCannotConnectToHost, NSURLErrorTimedOut].contains(code)
    }

    private static func explanation(for error: NSError) -> String {
        guard error.domain == NSURLErrorDomain else { return error.localizedDescription }
        switch error.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed:
            return "Your device isn’t connected to the internet. Check Wi-Fi or cellular data, then try again."
        case NSURLErrorNetworkConnectionLost:
            return "The network connection was lost while the page was loading."
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return "The server for this address couldn’t be found. Check the spelling of the address."
        case NSURLErrorCannotConnectToHost:
            return "The server isn’t accepting connections right now. It may be down or may not support secure connections."
        case NSURLErrorTimedOut:
            return "The server took too long to respond."
        case NSURLErrorSecureConnectionFailed:
            return "A secure connection to this server couldn’t be established."
        case NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasUnknownRoot:
            return "This website’s certificate isn’t trusted. Someone could be impersonating the site, so Acute Web won’t open it."
        case NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateNotYetValid:
            return "This website’s certificate is expired or not yet valid. Check that your device’s date and time are correct."
        case NSURLErrorClientCertificateRequired, NSURLErrorClientCertificateRejected:
            return "This website requires a client certificate. Acute Web doesn’t support client certificates."
        case NSURLErrorUserCancelledAuthentication, NSURLErrorUserAuthenticationRequired:
            return "This website requires a user name and password."
        case NSURLErrorAppTransportSecurityRequiresSecureConnection:
            return "This website can only be opened over a secure connection."
        default:
            return error.localizedDescription
        }
    }
}
