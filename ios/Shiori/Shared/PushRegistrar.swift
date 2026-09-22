import UIKit
import UserNotifications

extension Notification.Name {
    /// A release alert was tapped: the app opens on the Découvrir tab.
    static let shioriOpenDiscover = Notification.Name("ShioriOpenDiscover")
}

/// Where the app meets APNs: asking permission, handing the device token to
/// the server, and opening the right tab when an alert is tapped.
///
/// Permission is asked the first time the reader switches an alert on, never at
/// launch: an app that asks before it has said anything worth hearing gets a
/// no it can never take back.
@MainActor
final class PushRegistrar: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PushRegistrar()

    /// The token APNs last handed this device, to forget on sign-out.
    private var currentToken: String?
    private var waitingForToken: CheckedContinuation<Void, Never>?

    /// Whether the reader allows notifications at all.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Ask for permission if it was never asked, and register this device when
    /// it is granted. Answers whether notifications are allowed.
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let status = await authorizationStatus()
        let granted: Bool
        switch status {
        case .notDetermined:
            granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .authorized, .provisional, .ephemeral:
            granted = true
        default:
            granted = false
        }
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        return granted
    }

    /// On every launch with notifications allowed: APNs may have rotated the
    /// token, and the server must hear the new one.
    func refreshRegistration() async {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        default:
            break
        }
    }

    /// Stop pushing to this device, before the reader signs out of it.
    func forgetDevice() async {
        guard let token = currentToken else { return }
        currentToken = nil
        try? await NotificationsAPI.unregisterDevice(token: token)
    }

    func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        currentToken = token
        Task {
            do {
                try await NotificationsAPI.registerDevice(token: token, sandbox: Self.isSandbox)
            } catch {
                _ = reportError(error)
            }
        }
    }

    /// A build run from Xcode is signed for development and gets a sandbox
    /// token; TestFlight and the App Store get production ones.
    private static var isSandbox: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// An alert arriving while the app is open still shows: it is news the
    /// reader asked for.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            NotificationCenter.default.post(name: .shioriOpenDiscover, object: nil)
        }
    }
}

/// The UIKit side of the app, for the one thing SwiftUI does not surface: the
/// device token APNs hands back.
final class ShioriAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = PushRegistrar.shared
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushRegistrar.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // The simulator and a build without the push entitlement land here;
        // alerts simply never arrive, which the settings screen says.
        _ = reportError(error)
    }
}
