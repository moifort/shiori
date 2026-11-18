import SwiftUI

/// The gesture an action button's icon makes once its state changed: it does
/// what it says, once, in 0.3 to 0.4 s, never in a loop, beside the symbol
/// replaced in place. Only buttons that change a state have one; a button
/// that opens a screen or a menu keeps the press alone. Under "Reduce Motion"
/// none plays: the symbol is replaced alone, in a fade.
enum IconGesture {
    /// A bell rung: it swings left, then right, from its top.
    case swing
    /// An eye closing: the lid comes down, then lifts.
    case blink
    /// A bookmark slipped into the book: it slides down, then back.
    case slip
    /// Binoculars scanning the horizon: one sweep, left to right.
    case sweep
    /// A star or a check that has just been given: a small hop up.
    case hop
    /// A heart: two beats.
    case beat
    /// A moon falling asleep: a slow rock.
    case rock
}

extension View {
    /// Plays `gesture` each time `trigger` changes.
    func iconGesture(_ gesture: IconGesture, trigger: some Equatable) -> some View {
        modifier(IconGestureModifier(gesture: gesture, trigger: trigger))
    }
}

private struct IconGestureModifier<Trigger: Equatable>: ViewModifier {
    let gesture: IconGesture
    let trigger: Trigger

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: Pose(), trigger: trigger) { view, pose in
            view
                .rotationEffect(.degrees(reduceMotion ? 0 : pose.angle), anchor: gesture == .swing ? .top : .center)
                .scaleEffect(
                    x: reduceMotion ? 1 : pose.scale,
                    y: reduceMotion ? 1 : pose.scale * pose.lid,
                    anchor: .center
                )
                .offset(x: reduceMotion ? 0 : pose.x, y: reduceMotion ? 0 : pose.y)
        } keyframes: { _ in
            KeyframeTrack(\.angle) {
                switch gesture {
                case .swing:
                    CubicKeyframe(-16, duration: 0.1)
                    CubicKeyframe(16, duration: 0.12)
                    CubicKeyframe(-6, duration: 0.08)
                    CubicKeyframe(0, duration: 0.08)
                case .rock:
                    CubicKeyframe(-14, duration: 0.18)
                    CubicKeyframe(8, duration: 0.14)
                    CubicKeyframe(0, duration: 0.1)
                case .sweep:
                    CubicKeyframe(-8, duration: 0.12)
                    CubicKeyframe(8, duration: 0.16)
                    CubicKeyframe(0, duration: 0.1)
                default:
                    CubicKeyframe(0, duration: 0.01)
                }
            }
            KeyframeTrack(\.lid) {
                if gesture == .blink {
                    CubicKeyframe(0.1, duration: 0.12)
                    CubicKeyframe(0.1, duration: 0.06)
                    CubicKeyframe(1, duration: 0.14)
                } else {
                    CubicKeyframe(1, duration: 0.01)
                }
            }
            KeyframeTrack(\.scale) {
                if gesture == .beat {
                    CubicKeyframe(1.22, duration: 0.1)
                    CubicKeyframe(1, duration: 0.1)
                    CubicKeyframe(1.16, duration: 0.1)
                    CubicKeyframe(1, duration: 0.1)
                } else {
                    CubicKeyframe(1, duration: 0.01)
                }
            }
            KeyframeTrack(\.x) {
                if gesture == .sweep {
                    CubicKeyframe(-4, duration: 0.12)
                    CubicKeyframe(4, duration: 0.16)
                    CubicKeyframe(0, duration: 0.1)
                } else {
                    CubicKeyframe(0, duration: 0.01)
                }
            }
            KeyframeTrack(\.y) {
                switch gesture {
                case .slip:
                    CubicKeyframe(5, duration: 0.14)
                    SpringKeyframe(0, duration: 0.22, spring: .bouncy)
                case .hop:
                    CubicKeyframe(-6, duration: 0.14)
                    SpringKeyframe(0, duration: 0.22, spring: .bouncy)
                default:
                    CubicKeyframe(0, duration: 0.01)
                }
            }
        }
    }
}

/// Where the icon stands in its gesture.
private struct Pose {
    var angle: Double = 0
    var lid: CGFloat = 1
    var scale: CGFloat = 1
    var x: CGFloat = 0
    var y: CGFloat = 0
}

extension AnyTransition {
    /// The "+" turning a quarter as it gives way to its capsule.
    static var quarterTurn: AnyTransition {
        .modifier(active: Turned(angle: 90), identity: Turned(angle: 0)).combined(with: .opacity)
    }
}

private struct Turned: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View { content.rotationEffect(.degrees(angle)) }
}
