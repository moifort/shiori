import SwiftUI

/// An audiobook's square cover, as the player draws it, or a neutral square
/// with headphones while it loads or when there is none.
struct PlayerArtwork: View {
    let url: URL?
    let size: CGFloat
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let url {
                CoverImage(url: url) { placeholder } fallback: { placeholder }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: "headphones")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.secondary)
            }
    }
}

#Preview("Cover and empty") {
    HStack {
        PlayerArtwork(url: ListeningTitle.preview.coverURL, size: 120, cornerRadius: 12)
        PlayerArtwork(url: nil, size: 120, cornerRadius: 12)
    }
}
