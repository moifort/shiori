import SwiftUI

/// "+" that puts a friend's book — or the first volume of their saga — on the
/// reader's pile: a spinner while it goes, greyed out on one they already own.
/// Disabled alone would leave the plus in the accent colour, so it is greyed
/// throughout and reads as inert at a glance.
///
/// It asks how the reader takes the story in, since that need not be how the
/// friend did: a reader who never listens takes a friend's recording as a book.
struct TakeButton: View {
    let owned: Bool
    let isAdding: Bool
    /// The friend's own format, which the printed choice keeps when it is one
    /// (a manga stays a manga).
    let format: BookFormat
    var addLabel: LocalizedStringKey = "Ajouter à ma pile"
    var ownedLabel: LocalizedStringKey = "Déjà dans votre bibliothèque"
    let action: (BookFormat) async -> Void

    var body: some View {
        if isAdding {
            ProgressView().frame(width: 32)
        } else {
            Menu {
                ForEach(format.takenAs, id: \.self) { taken in
                    Button(taken.label, systemImage: taken.symbol) {
                        Task { await action(taken) }
                    }
                    .accessibilityIdentifier("friend-take-\(taken.rawValue)")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
            }
            .menuStyle(.button)
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            .foregroundStyle(owned ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
            .disabled(owned)
            .accessibilityLabel(Text(owned ? ownedLabel : addLabel))
            .accessibilityIdentifier(owned ? "friend-take-owned" : "friend-take-add")
        }
    }
}

extension BookFormat {
    /// The two ways a friend's book can be taken: in print — this format, or a
    /// plain book when this one is a recording — and as a recording.
    var takenAs: [BookFormat] {
        [self == .audiobook ? .book : self, .audiobook]
    }
}

extension FriendSaga {
    /// What its first volume is, which is the one a "+" takes.
    var takenFormat: BookFormat {
        volumes.first?.format ?? (isAudio ? .audiobook : .book)
    }
}
