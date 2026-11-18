import SwiftUI

/// What the "+" of a book the reader does not hold made of it, said in its
/// place by a glass capsule: on the pile, read already, or awaited.
enum TakenState: Equatable, Sendable {
    case toRead(isAudio: Bool)
    case read(isAudio: Bool)
    case awaited

    var title: LocalizedStringKey {
        switch self {
        case let .toRead(isAudio): isAudio ? "À écouter" : "À lire"
        case let .read(isAudio): isAudio ? "Écouté" : "Lu"
        case .awaited: "Guetté"
        }
    }

    var symbol: String {
        switch self {
        case .toRead: "bookmark.fill"
        case .read: "checkmark"
        case .awaited: "binoculars.fill"
        }
    }

    /// Taken: on the shelf, so "Envies" has nothing left to do. Awaiting an
    /// edition takes nothing.
    var takesTheBook: Bool { self != .awaited }
}

/// "Envies" and the round "+" beside it, wherever a book the reader does not
/// hold may be taken: Actualité's large cards, and the pages of a suggestion,
/// a prize's winner, a friend's book, an edition awaited and a volume
/// announced once out. One pair everywhere, at the size of its place, in the
/// shared action style (`ActionButtonStyle`).
///
/// "Envies" is a toggle. In white it puts the book on the wish list; once
/// there it turns to glass with a check, the same word at the same width, and
/// a second tap takes the book back off.
///
/// The "+" opens the book page's add menu, never the wish list, which the
/// capsule beside it already holds. Once a choice of it went through, it
/// stretches into a glass capsule that says what was done — "À lire", "Lu",
/// "Guetté" — with the menu's icon, and stays secondary: glass, never white.
/// "Envies" fades then, the book being taken, except for "Guetté". A second
/// tap on the capsule undoes the choice and gives the "+" back. While the
/// server answers, a spinner holds the "+"'s place; refused, the pair shakes.
/// No GlassEffectContainer around the pair: a menu opened from inside one
/// loses a moving tap on a row over a neighbouring button.
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
    /// otherwise outgrow a rail card, or beside a store's white button.
    var isCompact = false
    /// Greyed out: the book was just taken another way, or turned down.
    var isDisabled = false
    /// The "+" left out, when its menu would offer nothing.
    var showsMenu = true
    /// What the "+" made of the book; nil while nothing was chosen.
    var taken: TakenState? = nil
    /// The server is answering the "+": a spinner in its place.
    var isWorking = false
    /// Beside a store's white button, which keeps the white and the room:
    /// "Envies" is round, the bookmark alone, on glass (white with its check
    /// once wished, as a round toggle), and leaves once the book is taken
    /// rather than fading. The "+"'s capsule keeps its words.
    var besideStore = false
    /// Bumped by the caller when the server refused a choice: the pair shakes.
    var refusals = 0
    let onToggle: () -> Void
    var onUndo: () -> Void = {}
    @ViewBuilder let menu: () -> MenuItems

    var body: some View {
        HStack(spacing: size == .card ? 8 : 12) {
            if !(besideStore && taken?.takesTheBook == true) {
                wishButton
                    .transition(.scale.combined(with: .opacity))
            }
            if let taken {
                takenCapsule(taken)
                    .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
            } else if showsMenu {
                addMenu
            }
        }
        .animation(.bouncy(duration: 0.35), value: taken)
        .refusalShake(trigger: refusals)
        .sensoryFeedback(trigger: isWished) { _, wished in
            wished ? .success : .impact(weight: .light)
        }
        .sensoryFeedback(trigger: taken) { _, taken in
            taken != nil ? .success : .impact(weight: .light)
        }
    }

    private var height: CGFloat { size == .card ? 28 : 50 }
    private var font: Font { size == .card ? .caption.weight(.semibold) : .headline }

    private var wishButton: some View {
        Button(action: onToggle) {
            Group {
                if isCompact || besideStore {
                    wishSymbol
                } else {
                    HStack(spacing: size == .card ? 6 : 8) {
                        wishSymbol
                        Text("Envies")
                    }
                    .lineLimit(1)
                    .fixedSize()
                }
            }
            .font(font)
        }
        .buttonStyle(ActionButtonStyle(
            fill: besideStore ? (isWished ? .white : .glass) : (isWished ? .glass : .white),
            shape: isCompact || besideStore ? .circle : .capsule,
            height: height,
            isRaised: size == .page
        ))
        .animation(.bouncy(duration: 0.35), value: isWished)
        .disabled(isDisabled || taken?.takesTheBook == true)
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
            ZStack {
                Image(systemName: "plus")
                    .font(size == .card ? .caption.weight(.semibold) : .title3.weight(.medium))
                    .opacity(isWorking ? 0 : 1)
                if isWorking { ProgressView() }
            }
        }
        .menuStyle(.button)
        .buttonStyle(ActionButtonStyle(fill: .glass, shape: .circle, height: height))
        .disabled(isDisabled || isWorking)
        .accessibilityLabel("Ajouter")
        .accessibilityIdentifier("add-menu")
    }

    /// What the "+" did, in words beside its icon, on glass; a second tap
    /// undoes it. Icon alone where "Envies" lost its words already.
    private func takenCapsule(_ taken: TakenState) -> some View {
        Button(action: onUndo) {
            ZStack {
                HStack(spacing: size == .card ? 6 : 8) {
                    Image(systemName: taken.symbol)
                        .symbolEffect(.bounce, options: .nonRepeating, value: taken)
                    if !isCompact { Text(taken.title) }
                }
                .lineLimit(1)
                .fixedSize()
                .opacity(isWorking ? 0 : 1)
                if isWorking { ProgressView() }
            }
            .font(font)
        }
        .buttonStyle(ActionButtonStyle(fill: .glass, shape: isCompact ? .circle : .capsule, height: height))
        .disabled(isWorking)
        .accessibilityLabel(Text(taken.title))
        .accessibilityHint("Annule ce choix")
        .accessibilityIdentifier("add-taken")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        WishAddButtons(isWished: false, onToggle: {}) { Button("À lire") {} }
        WishAddButtons(isWished: true, onToggle: {}) { Button("À lire") {} }
        WishAddButtons(isWished: false, size: .page, onToggle: {}) { Button("À lire") {} }
        WishAddButtons(isWished: false, size: .page, taken: .toRead(isAudio: false), onToggle: {}) { Button("À lire") {} }
        WishAddButtons(isWished: true, size: .page, taken: .awaited, onToggle: {}) { Button("À lire") {} }
    }
    .padding()
    .background(.black)
}
