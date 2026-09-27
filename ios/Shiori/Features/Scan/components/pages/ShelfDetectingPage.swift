import SwiftUI

/// The wait while a shelf photo is read: the reader's own photo, dimmed, with
/// the one thing happening said under it. A single ungrounded call, so there
/// are no phases to walk through as a cover scan has.
struct ShelfDetectingPage: View {
    let photo: UIImage?

    var body: some View {
        VStack(spacing: 24) {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay {
                        ZStack {
                            Color.black.opacity(0.35)
                            ProgressView().tint(.white).controlSize(.large)
                        }
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .padding(.horizontal, 24)
            } else {
                ProgressView().controlSize(.large)
            }
            VStack(spacing: 4) {
                Text("Recherche des livres…")
                    .font(.headline)
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
