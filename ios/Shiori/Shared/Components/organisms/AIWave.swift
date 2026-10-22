import SwiftUI

/// The AI at work, as Siri shows it since iOS 27: a band of spectral light
/// rolling across the screen, its colours fringing apart and folding back as
/// it breathes. Shown wherever a reader waits on the model with nothing else
/// to look at — a cover being read, a shelf being searched.
///
/// Drawn by the `aiWave` Metal shader (`AIWave.metal`), a port of an
/// open-source recreation of the Siri animation. The shader fades the wave out
/// towards every edge, so the view can be given any width.
///
/// Respects Reduce Motion by holding one frame. Purely presentational.
struct AIWave: View {
    /// Height in points; the wave takes the width it is offered.
    var height: CGFloat = 220

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time so the wave starts from the same pose on appear.
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            // A still frame where the lines have spread apart and read as a wave.
            let time = reduceMotion ? 2.0 : context.date.timeIntervalSince(start)
            Rectangle()
                .visualEffect { content, proxy in
                    content.colorEffect(
                        ShaderLibrary.aiWave(.float2(proxy.size), .float(time))
                    )
                }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

#Preview("Light") {
    AIWave()
}

#Preview("Dark") {
    AIWave().preferredColorScheme(.dark)
}
