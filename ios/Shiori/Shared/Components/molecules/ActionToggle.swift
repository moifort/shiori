import SwiftUI

/// A round button that stands for a state the reader turns on and off: the
/// alerts of a series or an edition, a book seen or set aside. It shows the
/// state, never the action: on, its symbol in black on white; off, the same
/// symbol slashed, in white on glass. VoiceOver says what a tap does.
///
/// The tap answers at once, before the server: the caller turns the state
/// over as soon as asked (optimistically), the symbol is replaced in place
/// with a bounce, and the phone taps back, firmer on than off. Should the
/// state fall back once the call settled, the server refused: the button
/// shakes with an error tap.
struct ActionToggle: View {
    let isOn: Bool
    /// The symbol on; off, its `.slash` variant unless `offSymbol` says
    /// otherwise.
    let symbol: String
    var offSymbol: String? = nil
    /// Read by VoiceOver: what a tap does in each state.
    let turnOnLabel: LocalizedStringKey
    let turnOffLabel: LocalizedStringKey
    var size: CGFloat = 50
    /// What the symbol does once turned over, as it says it: a bell swings,
    /// an eye blinks. Nil bounces.
    var gesture: IconGesture? = nil
    /// Asked before turning the state off, in a dialog hung on the button,
    /// as "Supprimer" asks: the state only turns over once confirmed. Nil
    /// turns it off at once. Turning it on never asks.
    var turnOffConfirmation: LocalizedStringKey? = nil
    let onToggle: (Bool) async -> Void

    /// The state as last drawn, read once the call settled: the struct's
    /// own `isOn` is the one from the tap.
    @State private var latest: Bool?
    @State private var refusals = 0
    @State private var turns = 0
    @State private var confirmsTurnOff = false

    private var isShownOn: Bool { isOn }

    var body: some View {
        Button {
            if isShownOn, turnOffConfirmation != nil {
                confirmsTurnOff = true
            } else {
                turnOver()
            }
        } label: {
            Image(systemName: isShownOn ? symbol : (offSymbol ?? "\(symbol).slash"))
                .font(size >= 44 ? .title3.weight(.medium) : .subheadline.weight(.semibold))
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
                .modifier(TurnEffect(gesture: gesture, turns: turns))
        }
        .buttonStyle(ActionButtonStyle(fill: isShownOn ? .white : .glass, shape: .circle, height: size))
        .animation(.snappy, value: isShownOn)
        .onChange(of: isOn, initial: true) { _, on in latest = on }
        .refusalShake(trigger: refusals)
        .sensoryFeedback(trigger: isOn) { _, on in on ? .success : .impact(weight: .light) }
        .accessibilityLabel(Text(isShownOn ? turnOffLabel : turnOnLabel))
        .accessibilityAddTraits(isShownOn ? .isSelected : [])
        // Attached to the button: the dialog rises from the one that asked.
        .confirmationDialog(
            turnOffConfirmation ?? "",
            isPresented: $confirmsTurnOff,
            titleVisibility: .visible
        ) {
            Button(turnOffLabel, role: .destructive) { turnOver() }
            Button("Annuler", role: .cancel) {}
        }
    }

    private func turnOver() {
        let wanted = !isShownOn
        turns += 1
        Task {
            await onToggle(wanted)
            // The caller turned the state over at once; back where it
            // was once the call settled, the server said no. A frame's
            // wait lets the view take the settled state in first.
            try? await Task.sleep(for: .milliseconds(50))
            if (latest ?? isOn) != wanted { refusals += 1 }
        }
    }
}

/// The symbol's move once turned over: its own gesture, else a bounce.
private struct TurnEffect: ViewModifier {
    let gesture: IconGesture?
    let turns: Int

    func body(content: Content) -> some View {
        if let gesture {
            content.iconGesture(gesture, trigger: turns)
        } else {
            content.symbolEffect(.bounce, options: .nonRepeating, value: turns)
        }
    }
}

#Preview {
    @Previewable @State var on = false
    HStack(spacing: 16) {
        ActionToggle(isOn: on, symbol: "bell", turnOnLabel: "Suivre", turnOffLabel: "Ne plus suivre", gesture: .swing, turnOffConfirmation: "Ne plus suivre la série ?") {
            on = $0
        }
        ActionToggle(isOn: true, symbol: "eye", turnOnLabel: "Marquer comme vu", turnOffLabel: "Marquer comme non vu") { _ in }
        ActionToggle(isOn: false, symbol: "eye", turnOnLabel: "Marquer comme vu", turnOffLabel: "Marquer comme non vu") { _ in }
    }
    .padding()
    .background(.indigo)
}
