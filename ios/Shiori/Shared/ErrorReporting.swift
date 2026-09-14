import Foundation
import Sentry

func reportError(_ error: Error) -> String {
    let nsError = error as NSError
    let isIgnored = error is CancellationError
        || (nsError.domain == NSURLErrorDomain && (
            nsError.code == NSURLErrorCancelled
            || nsError.code == NSURLErrorTimedOut
        ))
    if !isIgnored {
        SentrySDK.capture(error: error)
    }
    return error.localizedDescription
}
