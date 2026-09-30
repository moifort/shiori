import Foundation
import Sentry

func reportError(_ error: Error) -> String {
    let nsError = error as NSError
    let isIgnored = isCancellation(error) || isConnectivityLoss(nsError)
    if !isIgnored {
        SentrySDK.capture(error: error)
    }
    return error.localizedDescription
}

/// The request was called off rather than refused: its task was cancelled —
/// the reader left the screen that asked — and URLSession says so with its own
/// error rather than a `CancellationError`. Nothing failed.
func isCancellation(_ error: Error) -> Bool {
    let nsError = error as NSError
    return error is CancellationError
        || (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled)
}

/// The device lost its network, not the app its way: a request that timed out,
/// a connection cut when the reader left the app mid-upload, a phone offline.
/// The reader is told; Sentry has nothing to fix.
private func isConnectivityLoss(_ error: NSError) -> Bool {
    error.domain == NSURLErrorDomain && [
        NSURLErrorTimedOut,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorNotConnectedToInternet,
    ].contains(error.code)
}
