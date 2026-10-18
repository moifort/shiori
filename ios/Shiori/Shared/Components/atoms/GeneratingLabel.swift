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
    /// toolbar declared from inside a list row never reaches the bar. The label
    /// fades in and out rather than popping, so a short piece of work does not
    /// make the bar blink.
    func generatingInBar(_ text: LocalizedStringKey?) -> some View {
        modifier(GeneratingInBar(text: text))
    }
}

/// `generatingInBar`, as a modifier so the label can own its fades. A toolbar
/// item cannot be transitioned, so the item stays in the bar while the label
/// fades out, and is taken away once it is gone — the title comes back then.
private struct GeneratingInBar: ViewModifier {
    let text: LocalizedStringKey?
    /// The last text shown, kept while it fades out.
    @State private var shown: LocalizedStringKey?

    func body(content: Content) -> some View {
        content
            .toolbar {
                if let shown {
                    ToolbarItem(placement: .principal) {
                        FadingLabel(text: shown, isOn: text != nil) {
                            // Faded out and not asked for again meanwhile.
                            if text == nil { self.shown = nil }
                        }
                    }
                }
            }
            .onChange(of: text != nil, initial: true) { _, isOn in
                if isOn { shown = text }
            }
    }
}

/// The label in the bar, fading in from nothing when it arrives — it is
/// drawn once at zero before rising, so the fade has somewhere to start —
/// and out when the work ends, then telling its owner it is gone.
private struct FadingLabel: View {
    let text: LocalizedStringKey
    let isOn: Bool
    let onFadedOut: () -> Void

    @State private var opacity = 0.0

    var body: some View {
        GeneratingLabel(text: text)
            .opacity(opacity)
            .accessibilityIdentifier("generating")
            .accessibilityHidden(opacity == 0)
            .onAppear { fade(to: isOn) }
            .onChange(of: isOn) { _, isOn in fade(to: isOn) }
    }

    private func fade(to isOn: Bool) {
        if isOn {
            withAnimation(.easeOut(duration: 0.35)) { opacity = 1 }
        } else {
            withAnimation(.easeIn(duration: 0.45)) { opacity = 0 } completion: { onFadedOut() }
        }
    }
}

#Preview {
    GeneratingLabel(text: "L'IA complète la fiche")
}
