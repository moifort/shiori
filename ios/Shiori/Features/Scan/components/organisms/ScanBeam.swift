import SwiftUI

/// A beam of light reading a photo: a thin bright line sweeping top to bottom
/// and back, trailing a glow over the strip it has just passed. Laid over the
/// photo — a cover, a shelf — it fills whatever frame it is given.
///
/// The line and its trail wear the `AIGlow`: the colours of the bar's "L'IA
/// complète…" label, in motion along the line as the line moves down the page,
/// so a photo being read and a page being written look like one AI at work.
/// One pass takes two cycles of the glow, so the colours complete a loop on
/// each way.
///
/// Respects Reduce Motion by holding one frame, the beam a third of the way
/// down in its resting colours. Purely presentational.
struct ScanBeam: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time so the sweep starts from the top on appear.
    @State private var start = Date()

    private let period: TimeInterval = AIGlow.period * 2

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(paused: reduceMotion)) { context in
                let elapsed = context.date.timeIntervalSince(start)
                let progress = reduceMotion ? 0.34 : sweepProgress(at: elapsed)
                let descending = reduceMotion || isDescending(at: elapsed)
                beam(
                    in: proxy.size,
                    progress: progress,
                    descending: descending,
                    glow: AIGlow.sweep(phase: reduceMotion ? 0 : AIGlow.phase(at: context.date))
                )
            }
        }
        .accessibilityHidden(true)
    }

    /// The trail sits above the line on the way down and below it on the way
    /// up. It fades to nothing away from the line through a mask, so the glow
    /// keeps its colours in the trail.
    private func beam(in size: CGSize, progress: Double, descending: Bool, glow: LinearGradient) -> some View {
        let y = progress * size.height
        let trailHeight = size.height * 0.28
        let trailOffset = descending ? -trailHeight / 2 : trailHeight / 2

        return ZStack {
            Rectangle()
                .fill(glow)
                .mask {
                    LinearGradient(
                        colors: [.black.opacity(descending ? 0 : 0.38), .black.opacity(descending ? 0.38 : 0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(width: size.width, height: trailHeight)
                .position(x: size.width / 2, y: y + trailOffset)

            Capsule()
                .fill(glow)
                .frame(width: size.width, height: 3)
                .blur(radius: 5)
                .opacity(0.9)
                .position(x: size.width / 2, y: y)

            Capsule()
                .fill(.white)
                .frame(width: size.width - 8, height: 2)
                .position(x: size.width / 2, y: y)
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

#Preview {
    Rectangle()
        .fill(.quaternary)
        .frame(width: 240, height: 180)
        .overlay { ScanBeam() }
        .clipShape(.rect(cornerRadius: 12))
}
