import SwiftUI

/// The pill pinned to a recording's cover: a headphones glyph on a neutral
/// disc, monochrome so it sits beside a cover of any colour without competing
/// with it.
struct AudiobookBadge: View {
    var size: CGFloat = 18

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(systemName: "headphones")
            .font(.system(size: size * 0.52, weight: .bold))
            .foregroundStyle(Color(.systemBackground))
            .frame(width: size, height: size)
            .background(background, in: Circle())
            .accessibilityLabel(Text("Livre audio"))
    }

    /// Near-black cut too hard against a light page: a grey there. The dark
    /// appearance keeps its light pastille.
    private var background: Color {
        colorScheme == .dark ? Color.primary.opacity(0.85) : Color(.systemGray)
    }
}

#Preview {
    HStack(spacing: 16) {
        AudiobookBadge()
        AudiobookBadge(size: 26)
    }
    .padding()
}
