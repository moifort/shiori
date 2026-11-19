import SwiftUI

/// What the reader decided of a page's subject, said in words in its hero —
/// "Pas intéressé" — while the button under it says what a tap
/// does. White on glass, as every pill over a cover.
struct StatusPill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.18), in: .capsule)
            .overlay { Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1) }
            .fixedSize()
    }
}

/// A status a hero names, as `StatusPill` draws it.
struct HeroStatus: Equatable {
    let text: String
    let systemImage: String

    /// A discovery the reader turned down.
    static var notInterested: HeroStatus {
        HeroStatus(text: String(localized: "Pas intéressé"), systemImage: "eye.slash")
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusPill(text: HeroStatus.notInterested.text, systemImage: HeroStatus.notInterested.systemImage)
    }
    .padding()
    .background(.green.gradient)
}

extension Animation {
    /// How a page fades to black and white once the reader turns its book
    /// down or stops following its saga: slow enough to watch the colour go.
    static var setAside: Animation { .easeInOut(duration: 1.2) }
}
