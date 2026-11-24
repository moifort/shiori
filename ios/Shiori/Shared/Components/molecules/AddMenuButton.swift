import SwiftUI

/// What the "+ Ajouter" of a book the reader does not hold made of it, said
/// in its place by a glass capsule: one action at a time — on the pile, read
/// already, on the wish list, an edition awaited — or the book held already.
enum TakenState: Equatable, Sendable {
    case toRead(isAudio: Bool)
    case read(isAudio: Bool)
    case wished
    case awaited(ReleaseFormat)
    /// In the library already, in any format: nothing left to take.
    case owned

    var title: LocalizedStringKey {
        switch self {
        case let .toRead(isAudio): isAudio ? "À écouter" : "À lire"
        case let .read(isAudio): isAudio ? "Écouté" : "Lu"
        case .wished: "Envie"
        case let .awaited(format): format == .audiobook ? "Audio" : "Traduction"
        case .owned: "Ajouté"
        }
    }

    /// The icon of the menu's entry that was chosen.
    var symbol: String {
        switch self {
        case let .toRead(isAudio): isAudio ? "headphones" : "bookmark.fill"
        case .read, .owned: "checkmark"
        case .wished: "bookmark"
        case let .awaited(format): format.awaitedSymbol
        }
    }

    /// What the capsule's icon does as it appears: the bookmark slips into
    /// the book, the check hops, the binoculars sweep the horizon.
    var gesture: IconGesture {
        switch self {
        case .toRead, .wished: .slip
        case .read, .owned: .hop
        case .awaited: .sweep
        }
    }

    /// Asked before the choice is taken back, in a dialog hung on the
    /// capsule: what the tap will undo.
    var undoQuestion: LocalizedStringKey {
        switch self {
        case .wished: "Retirer de la liste d'envies ?"
        case let .toRead(isAudio): isAudio ? "Retirer de la pile à écouter ?" : "Retirer de la pile à lire ?"
        case let .read(isAudio): isAudio ? "Retirer des livres écoutés ?" : "Retirer des livres lus ?"
        case let .awaited(format):
            format == .audiobook ? "Ne plus guetter l'audio ?" : "Ne plus guetter la traduction ?"
        case .owned: ""
        }
    }

    /// The dialog's red button, as short as it can be.
    var undoAction: LocalizedStringKey {
        switch self {
        case .awaited: "Ne plus guetter"
        default: "Retirer"
        }
    }

    /// Said by VoiceOver.
    var accessibilityTitle: String {
        switch self {
        case let .toRead(isAudio): isAudio ? String(localized: "À écouter") : String(localized: "À lire")
        case let .read(isAudio): isAudio ? String(localized: "Écouté") : String(localized: "Lu")
        case .wished: String(localized: "Dans vos envies")
        case let .awaited(format):
            format == .audiobook ? String(localized: "Audio guetté") : String(localized: "Traduction guettée")
        case .owned: String(localized: "Déjà dans votre bibliothèque")
        }
    }
}

/// "+ Ajouter", the one button of a book the reader does not hold, wherever
/// it may be taken: Actualité's large cards, the home's hero, and the pages
/// of a suggestion, a prize's winner, a friend's book, an edition awaited and
/// a volume announced once out. White, it opens the menu of everything the
/// book can become — on the pile or read, in print or as a recording, on the
/// wish list, an edition awaited — and the reader picks one thing.
///
/// Once the choice went through, the button turns to glass and says what was
/// done, with the icon of the entry chosen: "Envie", "À lire", "À écouter",
/// "Lu", "Écouté", "Traduction", "Audio". A second tap asks first, in a
/// dialog hung on the capsule ("Retirer de la liste d'envies ?"), then undoes
/// it and gives "+ Ajouter" back. A book held already says "Ajouté" with a check.
///
/// Turned down (the closed eye beside it), the button greys but stays live:
/// a tap says the book interests the reader after all, and takes the refusal
/// back rather than opening the menu. While the server answers, a spinner
/// holds its place; refused, it shakes. No GlassEffectContainer around it: a
/// menu opened from inside one loses a moving tap on a row over a
/// neighbouring button.
struct AddMenuButton<MenuItems: View>: View {
    enum Size {
        /// A large card's foot: 28 pt, as the "En cours" card's small buttons.
        case card
        /// A book page's hero: 50 pt, beside its other round buttons.
        case page
    }

    var size: Size = .card
    /// Round on glass, the "+" alone: beside a store's white button, which
    /// keeps the white, or on the home's hero beside "Découvrir". Its
    /// capsule keeps its words once a choice was made.
    var isRound = false
    /// What the reader made of the book; nil while nothing was chosen.
    var done: TakenState? = nil
    /// Greyed out and inert: the book cannot be taken from here.
    var isDisabled = false
    /// Turned down from the eye: greyed, and a tap calls `onReconsider`.
    var isTurnedDown = false
    var onReconsider: () -> Void = {}
    /// The server is answering: a spinner in the label's place.
    var isWorking = false
    /// Bumped by the caller when the server refused a choice: it shakes.
    var refusals = 0
    /// A tap on the capsule: the choice taken back. Nil leaves it inert (a
    /// book held already).
    var onUndo: (() -> Void)? = nil
    @ViewBuilder let menu: () -> MenuItems

    /// Bumped as the capsule appears: its icon plays its gesture then.
    @State private var capsuleShown = 0
    /// The capsule was tapped: its dialog asks before undoing.
    @State private var confirmsUndo = false

    var body: some View {
        Group {
            if let done {
                capsule(done)
                    .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
            } else if isTurnedDown {
                Button(action: onReconsider) { addLabel }
                    .buttonStyle(addStyle)
                    .opacity(0.45)
                    .disabled(isWorking)
                    .accessibilityLabel("Ajouter")
                    .accessibilityHint("Le livre vous intéresse finalement")
                    .accessibilityIdentifier("add-menu")
            } else {
                Menu { menu() } label: { addLabel }
                    .menuStyle(.button)
                    .buttonStyle(addStyle)
                    .opacity(isDisabled ? 0.45 : 1)
                    .disabled(isDisabled || isWorking)
                    .accessibilityLabel("Ajouter")
                    .accessibilityIdentifier("add-menu")
            }
        }
        .animation(.bouncy(duration: 0.35), value: done)
        .refusalShake(trigger: refusals)
        .sensoryFeedback(trigger: done) { _, done in
            done != nil ? .success : .impact(weight: .light)
        }
    }

    private var height: CGFloat { size == .card ? 28 : 50 }
    private var font: Font { size == .card ? .caption.weight(.semibold) : .headline }

    private var addStyle: ActionButtonStyle {
        isRound
            ? ActionButtonStyle(fill: .glass, shape: .circle, height: height)
            : ActionButtonStyle(fill: .white, height: height, isRaised: size == .page)
    }

    private var addLabel: some View {
        ZStack {
            Group {
                if isRound {
                    Image(systemName: "plus")
                        .font(size == .card ? .caption.weight(.semibold) : .title3.weight(.medium))
                } else {
                    HStack(spacing: size == .card ? 5 : 8) {
                        Image(systemName: "plus")
                        Text("Ajouter")
                    }
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                }
            }
            .opacity(isWorking ? 0 : 1)
            if isWorking { ProgressView() }
        }
    }

    /// What was done, in words beside its icon, on glass; a second tap asks
    /// before undoing it.
    private func capsule(_ done: TakenState) -> some View {
        Button { confirmsUndo = true } label: {
            ZStack {
                HStack(spacing: size == .card ? 5 : 8) {
                    Image(systemName: done.symbol)
                        .iconGesture(done.gesture, trigger: capsuleShown)
                    Text(done.title)
                }
                .lineLimit(1)
                .fixedSize()
                .opacity(isWorking ? 0 : 1)
                if isWorking { ProgressView() }
            }
            .font(font)
        }
        .buttonStyle(ActionButtonStyle(fill: .glass, shape: .capsule, height: height))
        .disabled(isWorking)
        .allowsHitTesting(onUndo != nil)
        .onAppear { capsuleShown += 1 }
        .accessibilityLabel(Text(done.accessibilityTitle))
        .accessibilityHint(onUndo == nil ? "" : String(localized: "Annule ce choix"))
        .accessibilityIdentifier("add-taken")
        // Attached to the capsule, as "Supprimer" asks: the dialog rises
        // from the button that asked, and nothing changes until confirmed.
        .confirmationDialog(done.undoQuestion, isPresented: $confirmsUndo, titleVisibility: .visible) {
            Button(done.undoAction, role: .destructive) { onUndo?() }
                .accessibilityIdentifier("add-taken-confirm")
            Button("Annuler", role: .cancel) {}
        }
    }
}

/// The barred eye beside "+ Ajouter": one tap turns the book down, its cover
/// going black and white, and the eye opens on white; a second tap on the
/// open eye takes the refusal back. Barred on glass while the book is offered.
struct NotInterestedToggle: View {
    let isOn: Bool
    var size: AddMenuButton<EmptyView>.Size = .card
    let onToggle: (Bool) async -> Void

    var body: some View {
        ActionToggle(
            isOn: isOn,
            // Barred while the book is offered; once turned down, the eye
            // opens again: the tap that brings the book back.
            symbol: "eye",
            offSymbol: "eye.slash",
            turnOnLabel: "Pas intéressé",
            turnOffLabel: "Ça m'intéresse finalement",
            size: size == .card ? 28 : 50,
            gesture: .blink,
            onToggle: onToggle
        )
        .accessibilityIdentifier("discovery-dismiss")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        AddMenuButton { Button("À lire") {} }
        AddMenuButton(done: .wished, onUndo: {}) { Button("À lire") {} }
        AddMenuButton(size: .page) { Button("À lire") {} }
        AddMenuButton(size: .page, done: .toRead(isAudio: true), onUndo: {}) { Button("À lire") {} }
        AddMenuButton(size: .page, done: .awaited(.book), onUndo: {}) { Button("À lire") {} }
        AddMenuButton(size: .page, isTurnedDown: true) { Button("À lire") {} }
        AddMenuButton(done: .owned) { EmptyView() }
    }
    .padding()
    .background(.black)
}
