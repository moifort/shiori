import Foundation
import Sentry

func reportError(_ error: Error) -> String {
    let nsError = error as NSError
    let isIgnored = isCancellation(error)
        || (nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut)
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
