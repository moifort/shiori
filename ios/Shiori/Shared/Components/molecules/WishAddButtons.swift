import SwiftUI

/// "Envies" and the round "+" beside it, wherever a book the reader does not
/// hold may be taken: Actualité's large cards, and the pages of a suggestion,
/// a prize's winner and a friend's book. One pair everywhere, at the size of
/// its place.
///
/// "Envies" is a toggle. In white it puts the book on the wish list; once
/// there it turns to glass with a check, the same word at the same width, and
/// a second tap takes the book back off. The tap answers at once: the capsule
/// sinks under the finger, the bookmark bounces into the check, and the phone
/// taps back. Nothing else pops up.
///
/// The "+" opens the book page's add menu, never the wish list, which the
/// capsule beside it already holds. No GlassEffectContainer around the pair:
/// a menu opened from inside one loses a moving tap on a row over a
/// neighbouring button.
struct WishAddButtons<MenuItems: View>: View {
    enum Size {
        /// A large card's foot: a 28 pt capsule and circle, as the "En cours"
        /// card's small buttons.
        case card
        /// A book page's hero: 50 pt, beside its other round buttons.
        case page
    }

    let isWished: Bool
    var size: Size = .card
    /// The wish's words left out, the bookmark alone: where the row would
    /// otherwise outgrow a rail card.
    var isCompact = false
    /// Greyed out: the book was just taken another way, or turned down.
    var isDisabled = false
    /// The "+" left out, when its menu would offer nothing.
    var showsMenu = true
    let onToggle: () -> Void
    @ViewBuilder let menu: () -> MenuItems

    var body: some View {
        HStack(spacing: size == .card ? 8 : 12) {
            wishButton
            if showsMenu { addMenu }
        }
        .sensoryFeedback(trigger: isWished) { _, wished in
            wished ? .success : .impact(weight: .light)
        }
    }

    private var height: CGFloat { size == .card ? 28 : 50 }

    private var wishButton: some View {
        Button(action: onToggle) {
            Group {
                if isCompact {
                    wishSymbol
                        .frame(width: height, height: height)
                } else {
                    HStack(spacing: size == .card ? 6 : 8) {
                        wishSymbol
                        Text("Envies")
                    }
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, size == .card ? 11 : 22)
                    .frame(height: height)
                }
            }
            .font(size == .card ? .caption.weight(.semibold) : .headline)
            .foregroundStyle(isWished ? .white : .black)
            .background {
                if isWished {
                    Capsule().fill(.white.opacity(0.16))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 1))
                } else {
                    Capsule().fill(.white)
                        .shadow(color: .black.opacity(size == .page ? 0.45 : 0), radius: 11, y: 8)
                }
            }
            .contentShape(.capsule)
            .animation(.bouncy(duration: 0.35), value: isWished)
        }
        .buttonStyle(WishPressStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
        .accessibilityLabel(isWished ? "Dans vos envies" : "Envies")
        .accessibilityHint(isWished ? "Retire le livre de vos envies" : "Ajoute le livre à vos envies")
        .accessibilityIdentifier("wish-button")
    }

    /// The bookmark, then the check: one symbol replaced in place, with a
    /// bounce on each change.
    private var wishSymbol: some View {
        Image(systemName: isWished ? "checkmark" : "bookmark")
            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
            .symbolEffect(.bounce, options: .nonRepeating, value: isWished)
    }

    private var addMenu: some View {
        Menu {
            menu()
        } label: {
            Image(systemName: "plus")
                .font(size == .card ? .caption.weight(.semibold) : .title3.weight(.medium))
                .foregroundStyle(.white)
                .frame(width: height, height: height)
                .glassEffect(.regular.interactive(), in: .circle)
                .contentShape(.circle)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("Ajouter")
        .accessibilityIdentifier("add-menu")
    }
}

/// The wish capsule pressed: it sinks a little under the finger and springs
/// back, so the tap is felt before the server answers.
private struct WishPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.bouncy(duration: 0.3), value: configuration.isPressed)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        WishAddButtons(isWished: false, onToggle: {}) { Button("À lire") {} }
        WishAddButtons(isWished: true, onToggle: {}) { Button("À lire") {} }
        WishAddButtons(isWished: false, size: .page, onToggle: {}) { Button("À lire") {} }
        WishAddButtons(isWished: true, size: .page, onToggle: {}) { Button("À lire") {} }
    }
    .padding()
    .background(.black)
}
