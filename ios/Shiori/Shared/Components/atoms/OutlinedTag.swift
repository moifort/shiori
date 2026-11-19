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

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(text.localizedUppercase)
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

#Preview {
    HStack {
        OutlinedTag(text: "Audio")
        OutlinedTag(text: "Non partagé", systemImage: "eye.slash")
        OutlinedTag(text: "Guetté", systemImage: "binoculars.fill")
    }
        .padding()
        .background(.gray)
}
