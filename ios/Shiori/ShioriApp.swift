import FirebaseCore
import Sentry
import SwiftUI

@main
struct ShioriApp: App {
    @UIApplicationDelegateAdaptor(ShioriAppDelegate.self) private var appDelegate

    init() {
        FirebaseApp.configure()
        #if DEBUG
        // Points Auth at the local emulator and signs in, but only when the UI
        // test launch arguments are there. A normal Debug run is untouched.
        UITestEnvironment.bootstrapIfNeeded()
        #endif
        startAnalytics()
        startSentry()
    }

    var body: some Scene {
        WindowGroup {
            AuthRoot()
        }
    }

    private func startSentry() {
        #if DEBUG
        // Dev builds (Debug config = Xcode run / simulator) never start Sentry, so
        // their noise — e.g. simulator App Hangs — stays out of the production
        // project. Distribution builds (App Store / TestFlight, archived in Release)
        // compile the branch below and keep reporting.
        #else
        let dsn = Secrets.sentryDsn
        if dsn.isEmpty { return }

        SentrySDK.start { options in
            options.dsn = dsn
            // Errors are never sampled, only performance traces are. A tenth is
            // enough to watch latency without paying for a transaction per tap.
            options.tracesSampleRate = 0.1
            options.enableAutoSessionTracking = true
            options.enableTimeToFullDisplayTracing = true
            // A watchdog termination is only inferred on the next launch, with
            // no stack: the one on September 27th 2026 came with nothing to
            // act on. MetricKit hands over the system's own diagnostics — the
            // hangs, and the kills with the stack they happened on.
            options.enableMetricKit = true
            // Attaches the trace headers to our GraphQL calls, and only to those,
            // so an error here and the backend error that caused it land in one
            // trace instead of two unrelated issues. Sampling does not affect it:
            // the trace id travels with every request.
            options.tracePropagationTargets = [APIClient.shared.baseURL.absoluteString]
        }
        #endif
    }
}
