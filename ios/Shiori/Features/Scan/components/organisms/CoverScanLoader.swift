import SwiftUI

/// The captured cover being read: the photo framed like a book, four viewfinder
/// corners around it, and a beam of light sweeping the page top to bottom and
/// back, trailing a glow over the strip it has just passed.
///
/// Showing the reader's own shot is the point. A scan is a long wait, and a
/// picture of *their* cover under the beam says what is being worked on far
/// better than an abstract spinner would. Without a photo (previews, a decode
/// failure) a closed-book placeholder takes the beam instead.
///
/// Respects Reduce Motion by holding one frame, the beam a third of the way
/// down. Purely presentational.
struct CoverScanLoader: View {
    var cover: UIImage?
    /// Width of the cover in points; the height follows a paperback's proportions.
    var width: CGFloat = 168

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time so the sweep starts from the top on appear.
    @State private var start = Date()

    /// Seconds for one full pass, down and back up.
    private let period: TimeInterval = 2.8
    private let cornerRadius: CGFloat = 12
    /// How far the corners sit outside the cover.
    private let bracketInset: CGFloat = 12

    private var height: CGFloat { width * 1.45 }

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let progress = reduceMotion
                ? 0.34
                : sweepProgress(at: context.date.timeIntervalSince(start))
            let descending = reduceMotion || isDescending(at: context.date.timeIntervalSince(start))

            ZStack {
                coverFace
                beam(progress: progress, descending: descending)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
            .padding(bracketInset)
            .overlay {
                ViewfinderCorners(length: 22)
                    .stroke(
                        Color.primary.opacity(0.75),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Cover

    @ViewBuilder
    private var coverFace: some View {
        if let cover {
            Image(uiImage: cover)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .overlay(spineShade)
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "book.closed")
                        .font(.system(size: width * 0.38, weight: .light))
                        .foregroundStyle(.secondary)
                }
                .overlay(spineShade)
        }
    }

    /// A shadow down the left edge, where a cover bends into its spine. It is
    /// what turns a rectangle of pixels into a book.
    private var spineShade: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.28), location: 0),
                .init(color: .black.opacity(0.06), location: 0.035),
                .init(color: .clear, location: 0.09),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Beam

    /// The light itself: a thin bright line with a soft halo, and behind it a
    /// fading trail over the strip just read. The trail sits above the line on
    /// the way down and below it on the way up.
    private func beam(progress: Double, descending: Bool) -> some View {
        let y = progress * height
        let trailHeight = height * 0.28
        let trailOffset = descending ? -trailHeight / 2 : trailHeight / 2

        return ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(descending ? 0 : 0.38),
                    Color.accentColor.opacity(descending ? 0.38 : 0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: width, height: trailHeight)
            .position(x: width / 2, y: y + trailOffset)

            Capsule()
                .fill(Color.accentColor)
                .frame(width: width, height: 3)
                .blur(radius: 5)
                .opacity(0.9)
                .position(x: width / 2, y: y)

            Capsule()
                .fill(.white)
                .frame(width: width - 8, height: 2)
                .position(x: width / 2, y: y)
        }
        .blendMode(.plusLighter)
    }

    /// 0 at the top, 1 at the bottom. A triangle wave over the period, eased at
    /// both ends so the beam settles before it turns around.
    private func sweepProgress(at time: TimeInterval) -> Double {
        let cycle = time.truncatingRemainder(dividingBy: period) / period
        let linear = cycle < 0.5 ? cycle * 2 : 2 - cycle * 2
        return linear * linear * (3 - 2 * linear)
    }

    private func isDescending(at time: TimeInterval) -> Bool {
        time.truncatingRemainder(dividingBy: period) / period < 0.5
    }
}

/// Four L-shaped strokes in the corners of a rect, the way a camera marks
/// what it is focusing on.
private struct ViewfinderCorners: Shape {
    var length: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
        ]
        for (corner, dx, dy) in corners {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * length))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * length, y: corner.y))
        }
        return path
    }
}

#Preview("Placeholder") {
    CoverScanLoader()
}

#Preview("Dark") {
    CoverScanLoader().preferredColorScheme(.dark)
}
