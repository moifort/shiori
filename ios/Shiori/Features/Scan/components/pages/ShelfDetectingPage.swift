import SwiftUI

/// The wait while a shelf photo is read: the AI at work — Siri's orb on a dark
/// page — with the one thing happening said under it.
struct ShelfDetectingPage: View {
    /// The photo being read. Kept by the caller for the checklist; the orb
    /// does not draw it.
    let photo: UIImage?

    var body: some View {
        VStack(spacing: 22) {
            SiriOrb()
            Text("Analyse de l'étagère")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
