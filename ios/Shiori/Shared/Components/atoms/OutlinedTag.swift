import SwiftUI

/// A short word in a thin white outline, as the TV app tags a film "4K" or
/// "CC": a recording's "Audio" on a card or a cover. A light shade behind it
/// keeps it readable on a pale cover.
struct OutlinedTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 3))
            .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.75), lineWidth: 1) }
            .fixedSize()
    }
}

#Preview {
    OutlinedTag(text: "Audio")
        .padding()
        .background(.gray)
}
