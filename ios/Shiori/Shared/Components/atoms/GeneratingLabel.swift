import SwiftUI

/// Says that the AI is writing part of the page, without covering it: a
/// sparkle and a few words swept by the colours of an Apple Intelligence glow,
/// for as long as the work runs. Not a spinner — the page stays readable and
/// usable underneath, and what the AI writes appears in place when it is done.
/// Still under Reduce Motion.
struct GeneratingLabel: View {
    let text: LocalizedStringKey

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One cycle of the glow, repeated so the sweep never shows a seam.
    private static let glow: [Color] = [.blue, .purple, .pink, .orange]
    /// How long the colours take to travel one cycle across the text.
    private static let period: TimeInterval = 2.4

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: Self.period) / Self.period
            Label(text, systemImage: "sparkles")
                .labelStyle(.titleAndIcon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: Self.glow + Self.glow,
                        // Two cycles over twice the width: shifting by one
                        // cycle lands on the same colours.
                        startPoint: UnitPoint(x: -phase, y: 0.5),
                        endPoint: UnitPoint(x: 2 - phase, y: 0.5)
                    )
                )
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Says in the navigation bar, in place of the title, what the AI is writing
    /// for this screen — nil when nothing is. Applied to the screen itself: a
    /// toolbar declared from inside a list row never reaches the bar.
    func generatingInBar(_ text: LocalizedStringKey?) -> some View {
        toolbar {
            if let text {
                ToolbarItem(placement: .principal) {
                    GeneratingLabel(text: text)
                        .accessibilityIdentifier("generating")
                }
            }
        }
    }
}

#Preview {
    GeneratingLabel(text: "L'IA complète la fiche")
}
