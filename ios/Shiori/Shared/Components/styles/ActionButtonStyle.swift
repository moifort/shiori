import SwiftUI

/// Every round or capsule action button of the app: white for the action that
/// leads a screen, glass beside it, a circle when the icon says it all. One
/// style, so every button answers a touch the same way:
///
/// - pressed, it sinks to 0.92 (0.96 when it spans the screen) and dims a
///   little, following the finger: slid off, it lets go without acting;
/// - let go, it springs back with a slight bounce.
///
/// Monochrome throughout: white, glass and black. What a tap did is said by
/// the fill (glass ↔ white), the symbol (filled or slashed) and the gesture
/// (`AsyncButton`'s outcome, `ActionToggle`), never by a colour. Under "Reduce
/// Motion" the button neither sinks nor bounces; it only dims. Only scale and
/// opacity move: nothing that would cost a frame in a scrolled page.
///
/// The size follows the control size: small 28 pt, regular 36 pt, large
/// 50 pt; a label that sets its own frame keeps it.
struct ActionButtonStyle: ButtonStyle {
    enum Fill {
        /// White, black text: the action still to do.
        case white
        /// Glass, white text: beside the white one, or the action done.
        case glass
    }

    enum Shape {
        case capsule
        case circle
    }

    var fill: Fill
    var shape: Shape = .capsule
    /// Spans the screen's width: it sinks to 0.96 only.
    var spansWidth = false
    /// A height of its own in place of the control size's.
    var height: CGFloat? = nil
    /// The label draws its own padding and height: the style adds only the
    /// fill and the press.
    var isBare = false

    func makeBody(configuration: Configuration) -> some View {
        ActionButtonBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            style: self
        )
    }
}

private struct ActionButtonBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let style: ActionButtonStyle

    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.actionShape) private var shapeOverride

    var body: some View {
        Group {
            switch shapeOverride ?? style.shape {
            case .capsule:
                label
                    .padding(.horizontal, style.isBare ? 0 : horizontalPadding)
                    .frame(minHeight: style.isBare ? nil : side)
                    .contentShape(.capsule)
                    .modifier(ActionFill(fill: style.fill, shape: Capsule()))
            case .circle:
                label
                    .frame(minWidth: style.isBare ? nil : side, minHeight: style.isBare ? nil : side)
                    .contentShape(.circle)
                    .modifier(ActionFill(fill: style.fill, shape: Circle()))
            }
        }
        .foregroundStyle(style.fill == .white ? Color.black : Color.white)
        // A spinner in the button (AsyncButton) in the label's own colour.
        .tint(style.fill == .white ? Color.black : Color.white)
        .opacity(isEnabled ? 1 : 0.45)
        .pressEffect(isPressed: isPressed && isEnabled, depth: style.spansWidth ? 0.96 : 0.92)
    }

    private var side: CGFloat {
        if let height = style.height { return height }
        switch controlSize {
        case .mini: return 24
        case .small: return 28
        case .regular: return 36
        case .large: return 50
        case .extraLarge: return 56
        @unknown default: return 36
        }
    }

    private var horizontalPadding: CGFloat {
        switch side {
        case ..<26: 8
        case ..<32: 10
        case ..<46: 12
        default: 20
        }
    }
}

/// Solid white, or Liquid Glass that does not react to the touch on its own:
/// interactive glass swells under a finger pressing a menu row lying over it,
/// as if it had been tapped. The press is drawn by the style, for a touch the
/// button really takes. The glass holds the label, rather than lying behind
/// it: in a GlassEffectContainer a glass background is drawn over its label.
private struct ActionFill<S: Shape>: ViewModifier {
    let fill: ActionButtonStyle.Fill
    let shape: S

    func body(content: Content) -> some View {
        switch fill {
        case .white: content.background(.white, in: shape)
        case .glass: content.glassEffect(.regular, in: shape)
        }
    }
}

extension EnvironmentValues {
    /// The shape a group of action buttons takes over their style's own.
    @Entry var actionShape: ActionButtonStyle.Shape? = nil
}

extension View {
    /// Round or capsule, over the action style's own shape: a hero whose
    /// buttons lose their words turns them all round at once.
    func actionShape(_ shape: ActionButtonStyle.Shape) -> some View {
        environment(\.actionShape, shape)
    }

    /// The press every action button shares: sunk to `depth` and dimmed while
    /// held, sprung back with a slight bounce once let go. Under "Reduce
    /// Motion", dimmed only.
    func pressEffect(isPressed: Bool, depth: CGFloat = 0.92) -> some View {
        modifier(PressEffect(isPressed: isPressed, depth: depth))
    }
}

private struct PressEffect: ViewModifier {
    let isPressed: Bool
    let depth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? depth : 1)
            .opacity(isPressed ? 0.85 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.15) : .bouncy(duration: 0.3, extraBounce: 0.1), value: isPressed)
    }
}

extension ButtonStyle where Self == ActionButtonStyle {
    /// White capsule, black text: the action that leads the screen.
    static var actionPrimary: ActionButtonStyle { ActionButtonStyle(fill: .white) }
    /// Glass capsule, white text: beside the white one.
    static var actionGlass: ActionButtonStyle { ActionButtonStyle(fill: .glass) }
    /// A round icon button: glass at rest, white once it stands for a state
    /// that is on (the reverse of its rest).
    static func actionRound(isOn: Bool = false) -> ActionButtonStyle {
        ActionButtonStyle(fill: isOn ? .white : .glass, shape: .circle)
    }
    /// White across the screen: a sheet's or an opening step's "Continuer".
    static var actionWide: ActionButtonStyle { ActionButtonStyle(fill: .white, spansWidth: true) }
    /// A capsule white or glass whichever its state says.
    static func action(_ fill: ActionButtonStyle.Fill, height: CGFloat? = nil) -> ActionButtonStyle {
        ActionButtonStyle(fill: fill, height: height)
    }
}
