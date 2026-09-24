import SwiftUI

/// "+" that puts a friend's book — or the first volume of their saga — on the
/// reader's pile: a spinner while it goes, greyed out on one they already own.
/// Disabled alone would leave the plus in the accent colour, so it is greyed
/// throughout and reads as inert at a glance.
struct TakeButton: View {
    let owned: Bool
    let isAdding: Bool
    var addLabel: LocalizedStringKey = "Ajouter à ma pile"
    var ownedLabel: LocalizedStringKey = "Déjà dans votre bibliothèque"
    let action: () async -> Void

    var body: some View {
        if isAdding {
            ProgressView().frame(width: 32)
        } else {
            Button {
                Task { await action() }
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
            }
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
