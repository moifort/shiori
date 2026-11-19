import SwiftUI

/// "Chez vous": a book the reader holds already, in any format, said in the
/// place of "Envies" and the "+" on a large card of Actualité. A glass
/// capsule with a check, drawn as the "+"'s capsule after a choice, but
/// with nothing to tap: there is nothing left to take.
struct OwnedCapsule: View {
    var height: CGFloat = 28

    var body: some View {
        Button {} label: {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                Text("Chez vous")
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
        }
        .buttonStyle(ActionButtonStyle(fill: .glass, shape: .capsule, height: height))
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Déjà dans votre bibliothèque")
        .accessibilityRemoveTraits(.isButton)
        .accessibilityIdentifier("owned-capsule")
    }
}

#Preview {
    OwnedCapsule()
        .padding()
        .background(.black)
        .environment(\.colorScheme, .dark)
}
