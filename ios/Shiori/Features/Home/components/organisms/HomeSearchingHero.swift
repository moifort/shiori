import SwiftUI

/// The top of a phone's home screen while the month's selection is being
/// made — a shelf just imported, or a month just begun — in the carousel's
/// grammar: where the month's cover would stand, the reader's own covers turn
/// in a ring around the AI's glass drops, nearer and brighter in front,
/// smaller and dimmer behind, as if the model were reading them again; under
/// it the month named, and one line on what the choice rests on, with a
/// pulse that says it is under way. Over the colours of the first cover, as
/// the carousel sets a page over its own. The carousel takes its place once
/// the selection is ready.
struct HomeSearchingHero: View {
    /// `YYYY-MM`.
    let month: String
    let bookCount: Int
    /// The covers that turn: a handful, blanks standing in when there are
    /// fewer than the ring wants.
    let covers: [URL]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    /// How many covers the ring holds.
    private static let slots = 8
    private static let coverWidth: CGFloat = 46
    /// The ring's half-width and half-height: a wide ellipse seen from a
    /// little above.
    private static let radiusX: CGFloat = 128
    private static let radiusY: CGFloat = 30
    /// One turn, in seconds.
    private static let turn: Double = 14
    /// How tall the fade into the page is: as the carousel's.
    private static let fadeHeight: CGFloat = 240

    var body: some View {
        VStack(spacing: 0) {
            ring
                .padding(.top, 18)
            Text("Découverte du mois")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .glassEffect(.clear, in: .capsule)
                .padding(.top, 14)
            Text(MonthlyDiscoveries.arrivingTitle(month: month))
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.top, 10)
            HStack(spacing: 8) {
                pulse
                Text("D’après vos \(bookCount) livres")
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
            .padding(.top, 6)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.bottom, 44)
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
        .background {
            CoverBackdrop(url: covers.first, fadeHeight: Self.fadeHeight)
                // Up under the bars and the status bar, as the carousel's.
                .padding(.top, -400)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home-searching")
    }

    /// The covers around the drops. Each stands at an angle on the ellipse;
    /// the ones in front, lower on the screen, are drawn larger, brighter and
    /// over the drops, the ones behind smaller, dimmer and under them.
    private var ring: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSince(start)
            ZStack {
                AIGlassDrops(size: 150)
                ForEach(0..<Self.slots, id: \.self) { slot in
                    let angle = Double(slot) / Double(Self.slots) * 2 * .pi + time * 2 * .pi / Self.turn
                    // -1 behind, +1 in front.
                    let depth = sin(angle)
                    cover(at: slot)
                        .scaleEffect(0.78 + 0.22 * (depth + 1) / 2)
                        .opacity(0.45 + 0.55 * (depth + 1) / 2)
                        .offset(x: cos(angle) * Self.radiusX, y: depth * Self.radiusY)
                        .zIndex(depth)
                }
            }
            .frame(width: 2 * Self.radiusX + Self.coverWidth, height: 190)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private func cover(at slot: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        Group {
            if slot < covers.count {
                Color.clear.overlay {
                    CoverImage(url: covers[slot]) { blank } fallback: { blank }
                }
                .clipShape(shape)
            } else {
                blank.clipShape(shape)
            }
        }
        .frame(width: Self.coverWidth, height: Self.coverWidth * 1.48)
        .overlay { shape.strokeBorder(.white.opacity(0.3), lineWidth: 1) }
        .shadow(color: .black.opacity(0.45), radius: 7, y: 6)
        .environment(\.coverMaxPixelSize, 160)
    }

    private var blank: some View {
        LinearGradient(
            colors: [.white.opacity(0.22), .white.opacity(0.08)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A dot that breathes in front of the line: the search is under way.
    private var pulse: some View {
        Circle()
            .fill(.white)
            .frame(width: 6, height: 6)
            .phaseAnimator([1, 0.25]) { dot, opacity in
                dot.opacity(opacity)
            } animation: { _ in .easeInOut(duration: 0.6) }
    }
}

#Preview {
    ScrollView {
        HomeSearchingHero(month: "2026-10", bookCount: 214, covers: Dashboard.preview.coverURLsForOrbit)
    }
    .background(Color(.systemGroupedBackground))
}
