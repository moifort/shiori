import SwiftUI

/// The one empty state of the app, on the dashboard's model: an icon, a title,
/// one sentence, and one prominent button. An empty list of the reader's own
/// always offers the same one, "Scanner un livre": it is what fills every list.
/// A second, plainer button exists for the rare screen that needs it. Every list draws its emptiness with
/// it, so a reader meets the same shape wherever there is nothing to show yet.
///
/// `failure` is the same shape for a list that could not load: the reason in
/// the sentence, "Réessayer" as the button.
struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: Text
    var primary: Action?
    var secondary: Action?

    /// A button of the empty state. Async so that a retry can show it is
    /// running rather than being tapped again.
    struct Action {
        let title: LocalizedStringKey
        var systemImage: String?
        let run: () async -> Void

        init(_ title: LocalizedStringKey, systemImage: String? = nil, run: @escaping () async -> Void) {
            self.title = title
            self.systemImage = systemImage
            self.run = run
        }
    }

    init(
        systemImage: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        primary: Action? = nil,
        secondary: Action? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = Text(message)
        self.primary = primary
        self.secondary = secondary
    }

    /// For a sentence built at run time — an error, a friend's name.
    init(
        systemImage: String,
        title: LocalizedStringKey,
        verbatim message: String,
        primary: Action? = nil,
        secondary: Action? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = Text(verbatim: message)
        self.primary = primary
        self.secondary = secondary
    }

    /// A list that could not load: what failed, and a retry.
    static func failure(
        _ title: LocalizedStringKey,
        message: String,
        retry: @escaping () async -> Void
    ) -> EmptyStateView {
        EmptyStateView(
            systemImage: "wifi.exclamationmark",
            title: title,
            verbatim: message,
            primary: Action("Réessayer", systemImage: "arrow.clockwise", run: retry)
        )
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            message
        } actions: {
            if let primary {
                AsyncButton {
                    await primary.run()
                } label: {
                    label(of: primary)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("empty-primary")
            }
            if let secondary {
                AsyncButton {
                    await secondary.run()
                } label: {
                    label(of: secondary)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("empty-secondary")
            }
        }
    }

    @ViewBuilder
    private func label(of action: Action) -> some View {
        if let systemImage = action.systemImage {
            Label(action.title, systemImage: systemImage)
        } else {
            Text(action.title)
        }
    }
}

#Preview {
    EmptyStateView(
        systemImage: "books.vertical",
        title: "Votre bibliothèque est vide",
        message: "Scannez la couverture d'un livre pour commencer.",
        primary: .init("Scanner un livre", systemImage: "camera") {},
        secondary: .init("Importer depuis Audible") {}
    )
}
