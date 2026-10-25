import SwiftUI

/// A friend as the TV app sets the account in its corner: a full disc, no
/// glass around it, in a gradient of the friend's own colour — the same
/// friend always the same colour — their initials in white over it, a thin
/// light rim inside the edge.
struct FriendMonogram: View {
    let name: String
    var size: CGFloat = 44

    var body: some View {
        let (top, bottom) = palette
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: .circle
            )
            .overlay {
                Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
            .accessibilityHidden(true)
    }

    /// One or two letters, as the friend's row takes them: "Camille" is C,
    /// "Marie Curie" MC.
    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }

    /// The friend's two shades, a light one over a deep one, picked from
    /// their name so they keep it from screen to screen and launch to launch:
    /// `hashValue` is seeded per launch, the letters' sum is not.
    private var palette: (Color, Color) {
        let seed = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let pairs: [(Color, Color)] = [
            (Color(red: 0.36, green: 0.85, blue: 0.45), Color(red: 0.07, green: 0.55, blue: 0.24)),
            (Color(red: 0.40, green: 0.72, blue: 1.00), Color(red: 0.10, green: 0.36, blue: 0.86)),
            (Color(red: 1.00, green: 0.62, blue: 0.32), Color(red: 0.90, green: 0.32, blue: 0.10)),
            (Color(red: 0.86, green: 0.52, blue: 1.00), Color(red: 0.52, green: 0.22, blue: 0.86)),
            (Color(red: 1.00, green: 0.48, blue: 0.62), Color(red: 0.86, green: 0.16, blue: 0.38)),
            (Color(red: 0.32, green: 0.86, blue: 0.86), Color(red: 0.05, green: 0.52, blue: 0.62)),
        ]
        return pairs[seed % pairs.count]
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(["Camille", "Marie Curie", "Léo", "Inès", "Hugo", "Zoé"], id: \.self) {
            FriendMonogram(name: $0)
        }
    }
    .padding()
}
