import SwiftUI

/// The wait while a shelf photo is read: the AI at work — the orb — with the
/// one thing happening said under it. A single ungrounded call, so there are
/// no phases to walk through as a cover scan has.
struct ShelfDetectingPage: View {
    /// The photo being read. Kept by the caller for the checklist; the orb
    /// does not draw it.
    let photo: UIImage?

    var body: some View {
        VStack(spacing: 40) {
            AIOrb()
            VStack(spacing: 6) {
                GeneratingLabel(text: "L'IA cherche les livres", font: .headline)
                Text("Aucun scan n'est décompté pendant la lecture.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden()
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ShelfDetectingPage(photo: ShelfImportFixtures.photo)
    }
}
#endif
