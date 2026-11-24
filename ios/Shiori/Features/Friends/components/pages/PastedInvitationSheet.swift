import SwiftUI
import UIKit

/// Everything the pasted-invitation sheet can ask for.
enum PastedInvitationAction {
    /// What the system's Paste button handed over.
    case paste(String)
    case later
}

/// The invitation a new reader brought from the web page: a link opened before
/// Shiori was installed does not survive the App Store, so the page copied it,
/// and this sheet asks for it once, on the first opening.
///
/// The button is the system's own Paste button: pressed, it hands the copied
/// text over without the alert iOS raises when an app reads the pasteboard by
/// itself. The sheet never reads it unasked.
struct PastedInvitationSheet: View {
    let onAction: (PastedInvitationAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 30))
                .frame(width: 76, height: 76)
                .overlay {
                    Circle().strokeBorder(.white.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                }
                .accessibilityHidden(true)
            Text("Une invitation vous attend")
                .font(.title2.weight(.bold))
                .padding(.top, 22)
            Text("Un ami vous a ouvert sa bibliothèque. Collez son lien pour voir ses livres, et qu'il voie les vôtres.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .frame(maxWidth: 300)
            WhitePasteButton { text in onAction(.paste(text)) }
                .frame(width: 150, height: 50)
                .padding(.top, 30)
                .accessibilityIdentifier("paste-invitation")
            Button("Plus tard") { onAction(.later) }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44)
                .padding(.top, 14)
        }
        .padding(.horizontal, 28)
        .padding(.top, 34)
        .frame(maxWidth: .infinity)
        .presentationDetents([.height(430)])
    }
}

/// The system's Paste button, white and black as the sheet's main button:
/// SwiftUI's `PasteButton` takes only a tint, which the sheet's glass greys.
/// Its label stays the system's own — iOS does not let an app rename it.
private struct WhitePasteButton: UIViewRepresentable {
    let onPaste: (String) -> Void

    func makeUIView(context: Context) -> UIPasteControl {
        let configuration = UIPasteControl.Configuration()
        configuration.baseBackgroundColor = .white
        configuration.baseForegroundColor = .black
        configuration.cornerStyle = .capsule
        configuration.displayMode = .iconAndLabel
        let control = UIPasteControl(configuration: configuration)
        control.target = context.coordinator
        return control
    }

    func updateUIView(_ control: UIPasteControl, context: Context) {
        context.coordinator.onPaste = onPaste
    }

    func makeCoordinator() -> Receiver { Receiver(onPaste: onPaste) }

    /// What the control pastes into: it accepts plain text, a link copied by
    /// the web page, and hands it over.
    final class Receiver: UIResponder {
        var onPaste: (String) -> Void

        init(onPaste: @escaping (String) -> Void) {
            self.onPaste = onPaste
            super.init()
            pasteConfiguration = UIPasteConfiguration(forAccepting: NSString.self)
        }

        override func paste(itemProviders: [NSItemProvider]) {
            guard let provider = itemProviders.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return }
            _ = provider.loadObject(ofClass: NSString.self) { [weak self] object, _ in
                guard let text = object as? String else { return }
                Task { @MainActor in self?.onPaste(text) }
            }
        }
    }
}

/// Whether the first opening should offer to paste an invitation: only for a
/// reader who has just been through onboarding — a new install — and only when
/// the pasteboard holds something like a link, which iOS tells without showing
/// its content or alerting the reader.
enum PastedInvitation {
    /// Set as onboarding completes, cleared once asked.
    static let pendingKey = "pastedInvitationPending"

    static func pasteboardHoldsALink() async -> Bool {
        await withCheckedContinuation { continuation in
            UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { result in
                continuation.resume(returning: (try? result.get())?.contains(.probableWebURL) ?? false)
            }
        }
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        PastedInvitationSheet { _ in }
    }
    .preferredColorScheme(.dark)
}
