import SwiftUI

/// The wait while a shelf photo is read: the reader's own photo swept by the
/// `ScanBeam`, as a cover is, with the one thing happening said under it. A
/// single ungrounded call, so there are no phases to walk through as a cover
/// scan has.
struct ShelfDetectingPage: View {
    let photo: UIImage?

    var body: some View {
        VStack(spacing: 24) {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .overlay { ScanBeam() }
                    .clipShape(.rect(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                    .padding(.horizontal, 24)
            } else {
                CoverScanLoader()
            }
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
