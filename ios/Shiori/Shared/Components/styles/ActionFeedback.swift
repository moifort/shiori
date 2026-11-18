import SwiftUI

/// What an action button says once its call settled: the phone taps back on
/// success, and on a refusal the button shakes briefly where it stands (three
/// short swings, 0.3 s) with an error tap, then shows its state from before.
/// Monochrome, no toast: the screen's own error message, if it has one, says
/// the rest. Under "Reduce Motion" it does not shake; the taps remain.
extension View {
    /// Shakes the view and taps an error each time `trigger` changes.
    func refusalShake(trigger: Int) -> some View {
        modifier(RefusalShake(trigger: trigger))
    }
}

private struct RefusalShake: ViewModifier {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { view, offset in
                view.offset(x: reduceMotion ? 0 : offset)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-6, duration: 0.05)
                    LinearKeyframe(6, duration: 0.05)
                    LinearKeyframe(-4, duration: 0.05)
                    LinearKeyframe(4, duration: 0.05)
                    LinearKeyframe(-2, duration: 0.05)
                    LinearKeyframe(0, duration: 0.05)
                }
            }
            .sensoryFeedback(.error, trigger: trigger)
    }
}

/// The outcome of a call an action button waited on.
enum ActionOutcome: Sendable {
    case done
    case refused
}

extension ActionOutcome {
    init(_ accepted: Bool) { self = accepted ? .done : .refused }
}
