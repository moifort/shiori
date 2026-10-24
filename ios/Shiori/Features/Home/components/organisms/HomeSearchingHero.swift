import SwiftUI

/// The top of a phone's home screen while the month's selection is being
/// made — a shelf just imported, or a month just begun — in the carousel's
/// grammar: where the month's cover would stand, a cover of the same size
/// that is not there yet, an aurora in Apple Intelligence's colours drifting
/// through it under a sparkle that breathes, as Image Playground holds the
/// place of a picture being made; under it the month named, and one line on
/// what the choice rests on, with a pulse that says it is under way. Over the
/// colours of the shelf's first cover, as the carousel sets a page over its
/// own. The carousel takes its place once the selection is ready.
struct HomeSearchingHero: View {
    /// `YYYY-MM`.
    let month: String
    let bookCount: Int
    /// The cover whose colours the hero takes; none draws the neutral ground.
    var backdropCover: URL?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    /// The cover's size, as the carousel draws the month's.
    private static let coverSize = CGSize(width: 140, height: 206)
    /// How tall the fade into the page is: as the carousel's.
    private static let fadeHeight: CGFloat = 240

    var body: some View {
        VStack(spacing: 0) {
            card
                .padding(.top, 26)
            Text("Découverte du mois")
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .glassEffect(.clear, in: .capsule)
                .padding(.top, 18)
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
            CoverBackdrop(url: backdropCover, fadeHeight: Self.fadeHeight)
                // Up under the bars and the status bar, as the carousel's.
                .padding(.top, -400)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home-searching")
    }

    /// The cover to come: the aurora shader over a plain fill, inside the
    /// cover's corners and the thin rim the posters carry, the sparkle over
    /// it. Still, in its first pose, with Reduce Motion.
    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return TimelineView(.animation(paused: reduceMotion)) { context in
            let time = reduceMotion ? 3 : context.date.timeIntervalSince(start)
            Rectangle()
                .fill(.black)
                .colorEffect(
                    ShaderLibrary.aurora(
                        .float2(Self.coverSize.width, Self.coverSize.height),
                        .float(Float(time))
                    )
                )
        }
        .frame(width: Self.coverSize.width, height: Self.coverSize.height)
        .clipShape(shape)
        .overlay { shape.strokeBorder(.white.opacity(0.22), lineWidth: 1) }
        .overlay { sparkle }
        .shadow(color: .black.opacity(0.5), radius: 22, y: 14)
        .accessibilityHidden(true)
    }

    /// Apple Intelligence's mark, breathing in the middle of the card.
    private var sparkle: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 34, weight: .medium))
            .foregroundStyle(.white)
            .shadow(color: .white.opacity(0.6), radius: 10)
            .phaseAnimator([0.92, 1.06], trigger: reduceMotion) { mark, scale in
                mark.scaleEffect(reduceMotion ? 1 : scale)
            } animation: { _ in .easeInOut(duration: 1.6) }
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
        HomeSearchingHero(month: "2026-10", bookCount: 214, backdropCover: Book.preview.coverURL)
    }
    .background(Color(.systemGroupedBackground))
}
