import SwiftUI

/// The wait while a shelf photo is read: the AI at work — drops of glass — with the
/// one thing happening said under it.
struct ShelfDetectingPage: View {
    /// The photo being read. Kept by the caller for the checklist; the drops
    /// does not draw it.
    let photo: UIImage?

    var body: some View {
        VStack(spacing: 40) {
            AIGlassDrops()
            Text("Analyse de l'étagère")
                .font(.headline)
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
