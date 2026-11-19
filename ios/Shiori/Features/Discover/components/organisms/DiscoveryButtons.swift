import SwiftUI

/// What a discovery's buttons decide on: a suggestion, an award winner.
protocol Discovery: Identifiable, Sendable where ID == String {
    /// The format it is listed in.
    var format: ReleaseFormat { get }
    /// The formats its edition may be awaited in.
    var awaitableFormats: [ReleaseFormat] { get }
    /// The edition the reader awaits already in `format`, when they do.
    var awaitedEditionId: String? { get }
}

extension Discovery {
    /// What the server says the reader made of it already: an edition awaited.
    var serverMark: DiscoveryMark? { awaitedEditionId == nil ? nil : .awaited(format) }

    /// The formats it may be taken in: the book and its recording, whatever
    /// the format it is listed in.
    var takenFormats: [BookFormat] { [.book, .audiobook] }
}

extension Suggestion: Discovery {}

extension BookDraft {
    /// The book as it goes onto the shelf in the format chosen: a recording
    /// holds no medium, a printed book the paper one unless it says another.
    func taken(as format: BookFormat, _ status: ReadingStatus) -> BookDraft {
        var draft = self
        draft.format = format
        if format == .audiobook {
            draft.media = []
        } else if draft.media.isEmpty {
            draft.media = [.print]
        }
        draft.status = status
        return draft
    }
}

/// What the reader decides about a discovery from its "+ Ajouter" and its
/// closed eye: one action at a time, which the same button takes back.
enum DiscoveryChoice {
    /// On the pile, in the format chosen.
    case add(BookFormat)
    /// Among the books read, in the format chosen.
    case alreadyRead(BookFormat)
    /// Onto the reader's wishlist.
    case wish
    /// The "Envie" capsule pressed: off the wishlist.
    case unwish
    /// The "Lu" capsule pressed: the book leaves the shelf.
    case undoAlreadyRead
    /// The "À lire" capsule pressed: the book leaves the pile.
    case undoAdd
    case await(ReleaseFormat)
    /// An edition awaited given up, from its capsule.
    case unawait(ReleaseFormat)
    case notInterested
    /// The eye pressed again, or the greyed "Ajouter": the book interests the
    /// reader after all.
    case reconsider
}

/// What a discovery's buttons say of the reader's choice.
enum DiscoveryMark: Equatable {
    case added(BookFormat)
    case read(BookFormat)
    case wished
    case awaited(ReleaseFormat)
    /// Turned down from the eye: the book goes black and white.
    case notInterested

    /// Said in the "+ Ajouter"'s capsule.
    var taken: TakenState? {
        switch self {
        case let .added(format): .toRead(isAudio: format == .audiobook)
        case let .read(format): .read(isAudio: format == .audiobook)
        case .wished: .wished
        case let .awaited(format): .awaited(format)
        case .notInterested: nil
        }
    }

    /// What a tap on the capsule sends: the choice taken back.
    var undo: DiscoveryChoice? {
        switch self {
        case .added: .undoAdd
        case .read: .undoAlreadyRead
        case .wished: .unwish
        case let .awaited(format): .unawait(format)
        case .notInterested: nil
        }
    }
}

/// The two buttons of a discovery that ask the server.
enum DiscoveryButton {
    case add
    case eye
}

/// What the reader decided about each discovery, held apart from the views so
/// the home's hero and the page it opens say the same thing.
@MainActor
@Observable
final class DiscoveryChoices {
    /// The choices made here; a nil value is one taken back, over what the
    /// server listed.
    private var marks: [String: DiscoveryMark?] = [:]
    /// The button whose choice the server is answering, with its spinner.
    private(set) var working: [String: DiscoveryButton] = [:]
    /// Bumped each time the server refused a choice: the buttons shake.
    private(set) var refusals: [String: Int] = [:]

    /// What the reader made of the discovery: here, else as the server listed it.
    func mark<Item: Discovery>(of item: Item) -> DiscoveryMark? {
        if let local = marks[item.id] { return local }
        return item.serverMark
    }

    /// Turned down here: drawn black and white.
    func isTurnedDown<Item: Discovery>(_ item: Item) -> Bool { mark(of: item) == .notInterested }

    /// Sends a choice and sets the mark it leaves once the server took it, and
    /// not before the menu has closed: drawn while it folds back into the
    /// button, the mark went unseen.
    func choose<Item: Discovery>(
        _ choice: DiscoveryChoice,
        for item: Item,
        from button: DiscoveryButton,
        leaving mark: DiscoveryMark?,
        ask: @escaping (Item, DiscoveryChoice) async -> Bool
    ) {
        guard working[item.id] == nil else { return }
        working[item.id] = button
        Task {
            async let folded: Void? = try? await Task.sleep(for: .milliseconds(450))
            let accepted = await ask(item, choice)
            _ = await folded
            withAnimation(.snappy) {
                working[item.id] = nil
                if accepted {
                    marks[item.id] = .some(mark)
                } else {
                    refusals[item.id, default: 0] += 1
                }
            }
        }
    }
}

/// A discovery's buttons, side by side in whatever row holds them: on its
/// page the white "+ Ajouter" and the closed eye; on the home's hero, which
/// leads with "Découvrir", the round "+" and the eye. The "+" opens every way
/// to take the book — on the pile or read, in print or as a recording, on the
/// wish list, an edition awaited — and says the one chosen. The eye turns the
/// book down in one tap, black and white, and a second tap, or one on the
/// greyed "+", takes it back. No GlassEffectContainer around them: a menu
/// opened from inside one loses a moving tap on a row over a neighbouring
/// button.
struct DiscoveryButtons<Item: Discovery>: View {
    let item: Item
    let choices: DiscoveryChoices
    /// Asks the server, and says whether it took the choice: the buttons
    /// change only then.
    let onChoice: (Item, DiscoveryChoice) async -> Bool
    /// "+ Ajouter" white, as the page's call to action, rather than a round
    /// "+": on the page, where nothing else leads.
    var addsInFull = false

    private var mark: DiscoveryMark? { choices.mark(of: item) }
    private var working: DiscoveryButton? { choices.working[item.id] }
    private var isTurnedDown: Bool { mark == .notInterested }

    var body: some View {
        AddMenuButton(
            size: .page,
            isRound: !addsInFull,
            done: mark?.taken,
            isTurnedDown: isTurnedDown,
            onReconsider: { choose(.reconsider, from: .add, leaving: nil) },
            isWorking: working == .add,
            refusals: choices.refusals[item.id] ?? 0,
            onUndo: {
                if let undo = mark?.undo { choose(undo, from: .add, leaving: nil) }
            }
        ) {
            DiscoveryAddActions(item: item) { choose($0, from: .add, leaving: $1) }
        }
        .accessibilityIdentifier("discovery-menu")
        // Offered while nothing else was chosen: a book taken is not turned
        // down.
        NotInterestedToggle(isOn: isTurnedDown, size: .page) { turnDown in
            choose(turnDown ? .notInterested : .reconsider, from: .eye, leaving: turnDown ? .notInterested : nil)
        }
        .disabled(working != nil || (mark != nil && !isTurnedDown))
        .opacity(mark != nil && !isTurnedDown ? 0.45 : 1)
    }

    private func choose(_ choice: DiscoveryChoice, from button: DiscoveryButton, leaving mark: DiscoveryMark?) {
        choices.choose(choice, for: item, from: button, leaving: mark, ask: onChoice)
    }
}

/// What a discovery's "+ Ajouter" offers, on its page and on the home's hero
/// — the menu a friend's book and a large card offer too: on the pile or
/// read, in print and as a recording, then the wish list, then each edition
/// still to await. Each choice names the mark it leaves on the button.
struct DiscoveryAddActions<Item: Discovery>: View {
    let item: Item
    let onChoose: (DiscoveryChoice, DiscoveryMark) -> Void

    var body: some View {
        ForEach(item.takenFormats, id: \.self) { format in
            Section(format.label) {
                Button(format == .audiobook ? "À écouter" : "À lire", systemImage: "bookmark.fill") {
                    onChoose(.add(format), .added(format))
                }
                .accessibilityIdentifier("suggestion-add-\(format.rawValue)")
                Button(format == .audiobook ? "Déjà écouté" : "Déjà lu", systemImage: "checkmark") {
                    onChoose(.alreadyRead(format), .read(format))
                }
                .accessibilityIdentifier("suggestion-read-\(format.rawValue)")
            }
        }
        Section {
            Button("Ajouter à la liste d'envies", systemImage: "bookmark") { onChoose(.wish, .wished) }
                .accessibilityIdentifier("suggestion-wish")
        }
        if !item.awaitableFormats.isEmpty {
            Section {
                ForEach(item.awaitableFormats) { format in
                    Button(format.awaitLabel, systemImage: format == .audiobook ? "headphones" : "binoculars") {
                        onChoose(.await(format), .awaited(format))
                    }
                    .accessibilityIdentifier("suggestion-await-\(format.rawValue)")
                }
            }
        }
    }
}

#Preview("Boutons d'une découverte") {
    VStack(alignment: .leading, spacing: 24) {
        // The home's hero: the round "+" and the eye.
        HStack(spacing: 10) {
            DiscoveryButtons(item: Suggestion.preview, choices: DiscoveryChoices()) { _, _ in true }
        }
        // The page: "+ Ajouter" in full, then the eye.
        HStack(spacing: 10) {
            DiscoveryButtons(item: Suggestion.preview, choices: DiscoveryChoices(), onChoice: { _, _ in true }, addsInFull: true)
        }
    }
    .padding()
    .background(.black)
    .preferredColorScheme(.dark)
}
