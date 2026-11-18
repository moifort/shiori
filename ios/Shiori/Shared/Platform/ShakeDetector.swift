import UIKit

extension Notification.Name {
    /// The iPhone was shaken while the app was in front.
    static let deviceDidShake = Notification.Name("ShioriDeviceDidShake")
}

extension UIWindow {
    /// Every window hears a shake first: it is told to whoever listens, the
    /// Audible player's sleep timer above all.
    override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
