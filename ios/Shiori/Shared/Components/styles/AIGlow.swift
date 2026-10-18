import SwiftUI

/// The one look of the AI at work, wherever it works: the colours that sweep
/// the bar's "L'IA complète…" label, the beam that reads a cover, the beam
/// that reads a shelf. Drawn from one place so a reader who learns it on one
/// screen recognises it on the next.
enum AIGlow {
    /// One cycle of the glow, in sweep order. Doubled where a sweep must loop
    /// without a seam: shifting by one cycle lands on the same colours.
    static let colors: [Color] = [.blue, .purple, .pink, .orange]

    /// How long the colours take to travel one cycle. Shared by every sweep,
    /// so two of them on one screen — the bar and a beam — move in step.
    static let period: TimeInterval = 2.4

    /// Where in the cycle a moment sits, 0 to 1, from the date a timeline
    /// hands over. A paused timeline hands the same date and so holds still.
    static func phase(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
    }

    /// The glow sweeping left to right across whatever it fills, `phase`
    /// cycles in. Two cycles over twice the width keep the loop seamless.
    static func sweep(phase: Double) -> LinearGradient {
        LinearGradient(
            colors: colors + colors,
            startPoint: UnitPoint(x: -phase, y: 0.5),
            endPoint: UnitPoint(x: 2 - phase, y: 0.5)
        )
    }
}
