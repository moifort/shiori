import LinkPresentation
import SwiftUI
import UIKit

/// Sends an invitation the moment it exists: the system's share sheet, straight
/// over whatever screen asked, with the message and the link and nothing else.
///
/// No screen of Shiori's own comes first. The link carries everything — the
/// friend taps it and the app does the rest — so a code to read out, or a
/// summary of what will be shared, would be a step between the reader and the
/// friend they already had in mind.
@MainActor
enum InvitationShare {
    /// The words that go with the link, and the title the share sheet shows
    /// over its row of people and apps.
    static var message: String { String(localized: "Je t'ouvre ma bibliothèque sur Shiori") }

    static func present(_ invitation: FriendInvitation) {
        guard let presenter = topViewController() else { return }
        let controller = UIActivityViewController(
            activityItems: [InvitationItem(url: invitation.url, message: message)],
            applicationActivities: nil
        )
        // On an iPad or an unfolded Duo the sheet is a popover, and needs
        // somewhere to stand.
        controller.popoverPresentationController?.sourceView = presenter.view
        controller.popoverPresentationController?.sourceRect = CGRect(
            x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0
        )
        controller.popoverPresentationController?.permittedArrowDirections = []
        presenter.present(controller, animated: true)
    }

    /// The screen in front: the share sheet goes over it, whatever sheet the
    /// invitation was asked from.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

/// The link with its words: Messages and Mail get "message + link", the copy
/// gets the link alone, and the sheet's header shows the message beside the
/// app's icon rather than a bare address.
private final class InvitationItem: NSObject, UIActivityItemSource {
    let url: URL
    let message: String

    init(url: URL, message: String) {
        self.url = url
        self.message = message
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any { url }

    func activityViewController(
        _ controller: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        switch activityType {
        case .copyToPasteboard?, .airDrop?: url
        default: "\(message)\n\(url.absoluteString)"
        }
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String { message }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = message
        metadata.originalURL = url
        metadata.url = url
        if let icon = UIImage(named: "launch-icon") {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}

extension View {
    /// Shares the invitation as soon as one is set, and lets it go: the screen
    /// asks for it, the system's sheet sends it.
    func sharesInvitation(_ invitation: Binding<FriendInvitation?>) -> some View {
        onChange(of: invitation.wrappedValue?.code) { _, code in
            guard code != nil, let value = invitation.wrappedValue else { return }
            invitation.wrappedValue = nil
            InvitationShare.present(value)
        }
    }
}
