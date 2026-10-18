import SwiftUI

/// Says that the AI is writing part of the page, without covering it: a
/// sparkle and a few words swept by the `AIGlow`, for as long as the work
/// runs. Not a spinner — the page stays readable and usable underneath, and
/// what the AI writes appears in place when it is done. Still under Reduce
/// Motion. `font` is the bar's by default; a page headline passes its own.
struct GeneratingLabel: View {
    let text: LocalizedStringKey
    var font: Font = .subheadline.weight(.semibold)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            Label(text, systemImage: "sparkles")
                .labelStyle(.titleAndIcon)
                .font(font)
                .foregroundStyle(AIGlow.sweep(phase: AIGlow.phase(at: context.date)))
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
