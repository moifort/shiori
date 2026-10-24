import SwiftUI

/// The rows a phone's home screen shows before the first book, in place of
/// the shelves to come: each a card on colours of its own, as the book read
/// now is drawn over its cover's, that says what the row will hold and offers
/// the one gesture that fills it.

/// "Importer vos livres": Audible and Kindle side by side, a line each on
/// what comes over, and the way to connect.
struct ImportSourcesRow: View {
    let onConnect: (ImportSource) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(ImportSource.allCases) { source in
                StartCard(
                    mark: .appIcon(source.appIcon),
                    title: source.label,
                    text: Self.line(source),
                    tint: Self.tint(source)
                ) {
                    Button { onConnect(source) } label: {
                        Label("Connecter", systemImage: "link")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    .accessibilityIdentifier("home-connect-\(source.rawValue)")
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private static func line(_ source: ImportSource) -> String {
        switch source {
        case .audible: String(localized: "Vos livres audio, avec leur avancement.")
        case .kindle: String(localized: "Vos livres lus et en cours, marqués comme tels.")
        }
    }

    /// Each source's own colour, as its store wears it.
    private static func tint(_ source: ImportSource) -> Color {
        switch source {
        case .audible: Color(red: 0.97, green: 0.6, blue: 0.11)
        case .kindle: Color(red: 0.34, green: 0.71, blue: 0.91)
        }
    }
}

/// "Lire avec des amis": what sharing opens, and the two ways in, both on
/// the Partagé tab.
struct FriendsInviteCard: View {
    let onInvite: () -> Void
    let onEnterInvitation: () -> Void

    var body: some View {
        StartCard(
            mark: .symbol("person.2.fill"),
            title: String(localized: "Invitez un ami"),
            text: String(localized: "Vous verrez sa bibliothèque et il verra la vôtre. Ses coups de cœur arriveront ici, dans « Nouveautés »."),
            tint: Color(red: 0.3, green: 0.6, blue: 0.35)
        ) {
            // Both labelled where they fit, stacked in a narrow column: a
            // label never breaks over lines.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { inviteButtons }
                VStack(alignment: .leading, spacing: 8) { inviteButtons }
            }
        }
    }

    @ViewBuilder private var inviteButtons: some View {
        Button(action: onInvite) {
            Label("Inviter un ami", systemImage: "person.badge.plus")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
        }
        .buttonStyle(.glassProminent)
        .tint(.white)
        .foregroundStyle(.black)
        .accessibilityIdentifier("home-invite")
        Button(action: onEnterInvitation) {
            Label("J'ai reçu une invitation", systemImage: "arrow.down.circle")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
        }
        .buttonStyle(.glass)
        .accessibilityIdentifier("home-enter-invitation")
    }
}

/// A card of the start rows: a mark — the service's own app icon, or a symbol
/// in a glass square — a title, a line, and the buttons — small, captioned,
/// with their icon, as the card of the book read now draws its own — over a
/// dark ground
/// tinted at its leading corner with the card's own colour, inside the thin
/// rim the posters carry.
private struct StartCard<Buttons: View>: View {
    enum Mark {
        case symbol(String)
        case appIcon(String)
    }

    let mark: Mark
    let title: String
    let text: String
    let tint: Color
    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            markView
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .padding(.top, 12)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            GlassEffectContainer(spacing: 8) {
                buttons()
            }
            .controlSize(.small)
            .padding(.top, 14)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [tint.opacity(0.28), Color(white: 0.11)],
                startPoint: .topLeading,
                endPoint: UnitPoint(x: 0.7, y: 1)
            )
            .background(Color(white: 0.11))
        }
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var markView: some View {
        switch mark {
        case let .appIcon(name):
            // The home screen's own rounding: about a fifth of the side.
            Image(name)
                .resizable()
                .clipShape(.rect(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        case let .symbol(name):
            Image(systemName: name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(0.1), in: .rect(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
        }
    }
}

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: 30) {
            ImportSourcesRow { _ in }
            FriendsInviteCard(onInvite: {}, onEnterInvitation: {})
        }
        .padding(20)
    }
    .background(Color(.systemGroupedBackground))
}
