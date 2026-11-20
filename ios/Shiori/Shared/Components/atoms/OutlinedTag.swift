import SwiftUI

/// A short word in a thin white outline, as the TV app tags a film "4K" or
/// "CC": a recording's "Audio" on a card or a cover. The cover is blurred
/// behind it, so the print under the word never fights it. Always in capitals,
/// as the TV app sets them.
struct OutlinedTag: View {
    let text: String
    /// Frosted glass behind the word, for a cover whose print would fight it.
    /// Off on a ground already smooth: the book hero's colours.
    var isFrosted = true
    /// A symbol before the word, where the tag says what the reader decided
    /// of the book rather than what it is: "Non partagé", "Guetté".
    var systemImage: String? = nil
    /// A symbol after the word, the one a smaller tag shows alone: the
    /// download arrow after "Téléchargé", so the home card's arrow reads.
    var trailingSystemImage: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(text.localizedUppercase)
            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
        }
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background {
                if isFrosted {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                }
            }
            .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.75), lineWidth: 1) }
            .fixedSize()
    }
}

/// A recording kept on the iPhone, as a symbol in the same outline, after
/// its "Audio": the home's card has no room for the word.
struct DownloadedTag: View {
    /// A capital's height in the tag's font, unaccented: the arrow keeps the
    /// room around it that the letters of "Audio" have.
    @ScaledMetric(relativeTo: .caption2) private var arrowHeight: CGFloat = 8

    var body: some View {
        // A hidden letter sets the line, so the tag stands exactly as tall as
        // "Audio" beside it; the arrow sits in it at a capital's height.
        Text(verbatim: "A")
            .font(.caption2.weight(.bold))
            .hidden()
            .overlay {
                Image(systemName: "arrow.down")
                    .resizable()
                    .fontWeight(.bold)
                    .scaledToFit()
                    .frame(height: arrowHeight)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            // The same frosted ground as the "Audio" beside it.
            .background {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
            .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.75), lineWidth: 1) }
            .fixedSize()
            .accessibilityLabel(Text("Téléchargé"))
    }
}

#Preview {
    HStack {
        OutlinedTag(text: "Audio")
        OutlinedTag(text: "Non partagé", systemImage: "eye.slash")
        OutlinedTag(text: "Guetté", systemImage: "binoculars.fill")
        DownloadedTag()
    }
        .padding()
        .background(.gray)
}
