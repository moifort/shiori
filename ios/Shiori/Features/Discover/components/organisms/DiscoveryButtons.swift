import SwiftUI

/// What a discovery's buttons decide on: a suggestion, an award winner.
protocol Discovery: Identifiable, Sendable where ID == String {
    /// The formats "Guetter" is offered in.
    var awaitableFormats: [ReleaseFormat] { get }
}

extension Suggestion: Discovery {}

/// What the reader decides about a discovery from its "+" and closed eye.
enum DiscoveryChoice {
    case add
    case await(ReleaseFormat)
    case alreadyRead
    /// The check pressed again on a book said read: it leaves the shelf.
    case undoAlreadyRead
    case notInterested
    /// The red thumb pressed again: the reader changed their mind.
    case reconsider
}

/// What a discovery's buttons say of the reader's choice.
enum DiscoveryMark {
    /// Added or awaited from the "+".
    case added
    /// Read already, from the eye.
    case read
    /// Turned down from the eye.
    case notInterested
}

/// The two buttons of a discovery that open a menu and ask the server.
enum DiscoveryButton {
    case add
    case eye
}

/// What the reader decided about each discovery, held apart from the views so
/// the home's hero and the page it opens say the same thing.
@MainActor
@Observable
final class DiscoveryChoices {
    private(set) var marks: [String: DiscoveryMark] = [:]
    /// The button whose choice the server is answering, with its spinner.
    private(set) var working: [String: DiscoveryButton] = [:]

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
                if accepted { marks[item.id] = mark }
            }
        }
    }
}

/// A discovery's "+" and closed eye, side by side in whatever row holds them,
/// on the home's hero and on a suggestion's or a winner's page alike. No
/// GlassEffectContainer around them: a menu opened from inside one loses a
/// moving tap on a row over a neighbouring button.
struct DiscoveryButtons<Item: Discovery>: View {
    let item: Item
    let choices: DiscoveryChoices
    /// Asks the server, and says whether it took the choice: the buttons
    /// change only then.
    let onChoice: (Item, DiscoveryChoice) async -> Bool
    /// "+ Ajouter" white, as the hero's call to action, rather than a round
    /// "+": on the page, where nothing else leads.
    var addsInFull = false

    /// The eye's button once a discovery is turned down.
    private var turnedDownRed: Color { Color(red: 0.78, green: 0.2, blue: 0.2) }

    private var mark: DiscoveryMark? { choices.marks[item.id] }
    private var working: DiscoveryButton? { choices.working[item.id] }
    private var isWorking: Bool { working != nil }

    var body: some View {
        addMenu
            .disabled(addIsOff)
            .sensoryFeedback(.success, trigger: mark == .added)
            .accessibilityIdentifier("discovery-menu")
        // The closed eye opens a choice, and gives way to the one made: turned
        // down, a filled thumb pressing down as the button turns red; read, a
        // check on white. Pressed again, it takes the choice back. Never
        // disabled once done: dimmed, the colour went unseen.
        switch mark {
        case .notInterested:
            Button {
                choose(.reconsider, from: .eye, leaving: nil)
            } label: {
                eyeLabel(turnedDown: true)
                    .modifier(WorkingLabel(isWorking: working == .eye))
            }
            .buttonStyle(.glass(.regular.tint(turnedDownRed)))
            .buttonBorderShape(.circle)
            .disabled(isWorking)
            .sensoryFeedback(.impact(weight: .medium), trigger: mark == .notInterested)
            .accessibilityIdentifier("discovery-dismiss")
        case .read:
            Button {
                choose(.undoAlreadyRead, from: .eye, leaving: nil)
            } label: {
                Label("Déjà lu", systemImage: "checkmark")
                    .labelStyle(.iconOnly)
                    .font(.headline)
                    .foregroundStyle(.black)
                    .contentTransition(.symbolEffect(.replace))
                    .modifier(WorkingLabel(isWorking: working == .eye))
            }
            .buttonStyle(.glass(.regular.tint(.white)))
            .buttonBorderShape(.circle)
            .disabled(isWorking)
            .sensoryFeedback(.success, trigger: mark == .read)
            .accessibilityIdentifier("discovery-dismiss")
        case .added, nil:
            Menu {
                Button("Pas intéressé", systemImage: "hand.thumbsdown", role: .destructive) {
                    choose(.notInterested, from: .eye, leaving: .notInterested)
                }
                .accessibilityIdentifier("discovery-not-interested")
                Button("Déjà lu", systemImage: "checkmark.circle") {
                    choose(.alreadyRead, from: .eye, leaving: .read)
                }
                .accessibilityIdentifier("discovery-already-read")
            } label: {
                eyeLabel(turnedDown: false)
                    .modifier(WorkingLabel(isWorking: working == .eye))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(isWorking || mark == .added)
            .accessibilityIdentifier("discovery-dismiss")
        }
    }

    private var addIsOff: Bool { isWorking || mark == .read || mark == .notInterested }

    @ViewBuilder private var addMenu: some View {
        if addsInFull {
            Menu {
                addActions
            } label: {
                addLabel
                    .labelStyle(.titleAndIcon)
                    .modifier(WorkingLabel(isWorking: working == .add))
            }
            .menuStyle(.button)
            // Not .glassProminent: see HeroProminentButtonStyle.
            .buttonStyle(.heroProminent)
            .opacity(addIsOff ? 0.45 : 1)
        } else {
            Menu {
                addActions
            } label: {
                addLabel
                    .labelStyle(.iconOnly)
                    .modifier(WorkingLabel(isWorking: working == .add))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        }
    }

    private var addActions: some View {
        DiscoveryAddActions(
            item: item,
            onAdd: { choose(.add, from: .add, leaving: .added) },
            onAwait: { choose(.await($0), from: .add, leaving: .added) }
        )
    }

    private var addLabel: some View {
        Label(
            mark == .added ? "Ajouté" : "Ajouter",
            systemImage: mark == .added ? "checkmark" : "plus"
        )
        .font(.headline)
        .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
    }

    private func choose(_ choice: DiscoveryChoice, from button: DiscoveryButton, leaving mark: DiscoveryMark?) {
        choices.choose(choice, for: item, from: button, leaving: mark, ask: onChoice)
    }

    private func eyeLabel(turnedDown: Bool) -> some View {
        Label(
            turnedDown ? "Écarté" : "Pas intéressé",
            systemImage: turnedDown ? "hand.thumbsdown.fill" : "eye.slash"
        )
        .labelStyle(.iconOnly)
        .font(.headline)
        .foregroundStyle(.white)
        .contentTransition(.symbolEffect(.replace))
        // Down when turned down, back up when taken back.
        .symbolEffect(turnedDown ? .bounce.down.byLayer : .bounce.up.byLayer, value: turnedDown)
    }
}

/// A round button's spinner, in its label's room, while the server answers.
private struct WorkingLabel: ViewModifier {
    let isWorking: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isWorking ? 0 : 1)
            .overlay { if isWorking { ProgressView().controlSize(.regular) } }
    }
}
