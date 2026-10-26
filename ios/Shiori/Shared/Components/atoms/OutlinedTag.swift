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

    var body: some View {
        Text(text.localizedUppercase)
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
    OutlinedTag(text: "Audio")
        .padding()
        .background(.gray)
}
