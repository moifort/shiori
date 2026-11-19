import SwiftUI

/// "Ajouté": a book the reader holds already, in any format, said in the
/// place of "+ Ajouter" — on a large card of Actualité, and on the
/// page of a friend's book or a prize's winner. A glass capsule with a check,
/// drawn as the "+"'s capsule after a choice. With nothing left to do it
/// takes no tap; given menu items (the editions still to await from a
/// friend's book), it opens them.
struct OwnedCapsule<MenuItems: View>: View {
    var size: AddMenuButton<EmptyView>.Size = .card
    @ViewBuilder var menu: () -> MenuItems

    var body: some View {
        if MenuItems.self == EmptyView.self {
            Button {} label: { label }
                .buttonStyle(style)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Déjà dans votre bibliothèque")
                .accessibilityRemoveTraits(.isButton)
                .accessibilityIdentifier("owned-capsule")
        } else {
            Menu { menu() } label: { label }
                .menuStyle(.button)
                .buttonStyle(style)
                .accessibilityLabel("Déjà dans votre bibliothèque")
                .accessibilityIdentifier("owned-capsule")
        }
    }

    private var style: ActionButtonStyle {
        ActionButtonStyle(fill: .glass, shape: .capsule, height: size == .card ? 28 : 50)
    }

    private var label: some View {
        HStack(spacing: size == .card ? 6 : 8) {
            Image(systemName: "checkmark")
            Text("Ajouté")
        }
        .font(size == .card ? .caption.weight(.semibold) : .headline)
        .lineLimit(1)
        .fixedSize()
    }
}

extension OwnedCapsule where MenuItems == EmptyView {
    init(size: AddMenuButton<EmptyView>.Size = .card) {
        self.init(size: size) { EmptyView() }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        OwnedCapsule()
        OwnedCapsule(size: .page)
        OwnedCapsule(size: .page) { Button("Guetter en audio") {} }
    }
    .padding()
    .background(.black)
    .environment(\.colorScheme, .dark)
}
