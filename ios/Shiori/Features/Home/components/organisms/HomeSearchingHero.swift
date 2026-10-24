import SwiftUI

/// The top of a phone's home screen while the month's selection is being
/// made — a shelf just imported, or a month just begun — in the carousel's
/// grammar: where the month's cover would stand, in the room it will take,
/// a spinner of vapour — an arc in Apple Intelligence's colours, blurred
/// into a wisp of smoke, a thin bright edge over it — and nothing around
/// it; under it the month named, and one line on what the choice rests on. Over the colours
/// of the shelf's first cover, as the carousel sets a page over its own. The
/// carousel takes its place once the selection is ready.
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
            spinner
                // The cover's room, so the carousel takes its place without
                // the page moving.
                .frame(width: Self.coverSize.width, height: Self.coverSize.height)
                .padding(.top, 26)
                .accessibilityLabel(Text("Recherche de vos découvertes…"))
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
            Text("D’après vos \(bookCount) livres")
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

    /// The vapour: an arc of the spectrum turning once a second and a half,
    /// its wide blurred body under its thin bright edge, as steam curls over
    /// a cup. Still, with Reduce Motion.
    private var spinner: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSince(start)
            let angle = Angle.degrees(time * 240)
            ZStack {
                arc(lineWidth: 14, blur: 12, opacity: 0.85)
                arc(lineWidth: 6, blur: 4, opacity: 0.9)
                arc(lineWidth: 2.5, blur: 0, opacity: 1)
            }
            .rotationEffect(angle)
        }
        .frame(width: 64, height: 64)
    }

    /// One turn of the arc: three quarters of a circle fading in from
    /// nothing to its full colour, so the wisp has a tail.
    private func arc(lineWidth: CGFloat, blur: CGFloat, opacity: Double) -> some View {
        Circle()
            .trim(from: 0.08, to: 0.78)
            .stroke(
                AngularGradient(
                    stops: [
                        .init(color: .clear, location: 0.08),
                        .init(color: Color(red: 0.6, green: 0.42, blue: 1.0).opacity(0.5), location: 0.25),
                        .init(color: Color(red: 0.32, green: 0.68, blue: 1.0), location: 0.45),
                        .init(color: Color(red: 1.0, green: 0.42, blue: 0.68), location: 0.62),
                        .init(color: Color(red: 1.0, green: 0.62, blue: 0.30), location: 0.78),
                    ],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .blur(radius: blur)
            .opacity(opacity)
    }
}

#Preview {
    ScrollView {
        HomeSearchingHero(month: "2026-10", bookCount: 214, backdropCover: Book.preview.coverURL)
    }
    .background(Color(.systemGroupedBackground))
}
