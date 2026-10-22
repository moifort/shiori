import SwiftUI

/// The wait while a shelf photo is read: the AI at work — the wave — with the
/// one thing happening said under it. A single ungrounded call, so there are
/// no phases to walk through as a cover scan has.
struct ShelfDetectingPage: View {
    /// The photo being read. Kept by the caller for the checklist; the wave
    /// does not draw it.
    let photo: UIImage?

    var body: some View {
        VStack(spacing: 40) {
            AIWave()
            VStack(spacing: 6) {
                Text("Analyse de l'étagère")
                    .font(.headline)
                Text("Cette analyse n'est pas décomptée de vos scans.")
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
