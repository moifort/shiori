#if DEBUG
import FirebaseAuth
import Foundation

/// Signs the app in without Sign in with Apple, so the UI tests can reach the
/// screens behind the login wall. Apple's sheet is a system process XCUITest
/// cannot drive, so an end-to-end run points Firebase Auth at the local
/// emulator instead and creates its own account there.
///
/// Debug-only by construction: the whole file is compiled out of the Release
/// configuration the App Store archive is built with.
///
/// Driven by two launch arguments, both required for anything to happen:
///   -uiTestAuthEmulator 127.0.0.1:9099
///   -uiTestAccount      e2e-<uuid>@shiori.test
///
/// The server URL rides the plain `-serverURL` argument, which `APIClient`
/// already reads through `UserDefaults`.
enum UITestEnvironment {
    /// Any password satisfies the emulator; it verifies nothing.
    private static let password = "e2e-password"

    /// Called from `ShioriApp.init()` right after `FirebaseApp.configure()`,
    /// before anything touches `Auth.auth()`.
    static func bootstrapIfNeeded() {
        guard
            let emulator = value(for: "-uiTestAuthEmulator"),
            let email = value(for: "-uiTestAccount"),
            let (host, port) = split(emulator)
        else { return }

        Auth.auth().useEmulator(withHost: host, port: port)
        // A previous run leaves its session in the simulator's keychain. Signing
        // out first means the app never shows the old account's library while the
        // new sign-in is still in flight.
        try? Auth.auth().signOut()

        Task {
            do {
                // The emulator starts empty on every run, so the account is
                // created here. Falling back to a sign-in covers the app being
                // re-launched inside one test, where the account already exists.
                do {
                    _ = try await Auth.auth().createUser(withEmail: email, password: password)
                } catch {
                    _ = try await Auth.auth().signIn(withEmail: email, password: password)
                }
            } catch {
                // No XCTFail available here: the test fails on its own when the
                // login screen never goes away, and this line says why.
                print("[UITestEnvironment] sign-in failed for \(email): \(error)")
            }
        }
    }

    /// Reads the value following `name` in the launch arguments.
    private static func value(for name: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count
        else { return nil }
        return arguments[index + 1]
    }

    private static func split(_ hostPort: String) -> (String, Int)? {
        let parts = hostPort.split(separator: ":")
        guard parts.count == 2, let port = Int(parts[1]) else { return nil }
        return (String(parts[0]), port)
    }
}
#endif
