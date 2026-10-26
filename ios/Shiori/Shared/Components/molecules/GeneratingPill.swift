import SwiftUI

/// Says that the AI is preparing the page, without covering it: a small pill
/// floating above the tab bar, filled with Siri's kind of light — two colour
/// fields crossing as they turn — with one line of white text glowing on it,
/// its glow breathing. It swells into place out of a blur and dissolves the
/// same way. No "done": what the AI wrote appearing in the page says it.
/// Never takes a touch.
struct GeneratingPill: View {
    /// Where the pill is in its life, from nothing to open and back.
    enum Stage: CaseIterable {
        /// Not there yet: small and out of focus.
        case gone
        /// Open on its words.
        case open
        /// Dissolved: a touch smaller, out of focus.
        case vanished
    }

    let stage: Stage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let field = LightField(
                turn: .degrees(time.truncatingRemainder(dividingBy: 3.4) / 3.4 * 360),
                turnBack: .degrees(-time.truncatingRemainder(dividingBy: 5.3) / 5.3 * 360)
            )
            let breath = reduceMotion ? 0.5 : (sin(time / 2 * 2 * .pi) + 1) / 2

            Text("L'IA prépare la fiche")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize()
                .shadow(color: .white.opacity(0.7 + 0.3 * breath), radius: 2.5 + 1.5 * breath)
                .shadow(color: .white.opacity(0.35 + 0.35 * breath), radius: 6 + 4 * breath)
                .shadow(color: .black.opacity(0.18), radius: 0.5, y: 1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background {
                    field
                        .padding(.horizontal, -24)
                        .padding(.vertical, -20)
                        .blur(radius: 6)
                        .saturation(1.5)
                        .brightness(-0.2)
                        .clipShape(Capsule())
                }
                .background {
                    field.additive()
                        .clipShape(Capsule())
                        .padding(-6)
                        .blur(radius: 14)
                        .opacity(0.6)
                }
        }
        .scaleEffect(scale)
        .opacity(stage == .open ? 1 : 0)
        .blur(radius: stage == .open ? 0 : 6)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("L'IA prépare la fiche"))
        .accessibilityIdentifier("generating")
        .accessibilityHidden(stage != .open)
    }

    private var scale: CGFloat {
        switch stage {
        case .gone: 0.6
        case .open: 1
        case .vanished: 0.9
        }
    }
}

/// Two angular gradients in the `AIGlow` colours, the warm one gapped so the
/// cool one shows through. Laid over each other they make the pill's body;
/// added together as light is, they make its halo.
private struct LightField: View {
    let turn: Angle
    let turnBack: Angle
    var isAdditive = false

    func additive() -> LightField {
        LightField(turn: turn, turnBack: turnBack, isAdditive: true)
    }

    var body: some View {
        ZStack {
            AngularGradient(
                stops: [
                    .init(color: .cyan, location: 0),
                    .init(color: .blue, location: 0.3),
                    .init(color: .purple, location: 0.55),
                    .init(color: .pink, location: 0.8),
                    .init(color: .cyan, location: 1),
                ],
                center: .center, angle: turnBack
            )
            AngularGradient(
                stops: [
                    .init(color: .orange, location: 0),
                    .init(color: .pink, location: 0.25),
                    .init(color: .clear, location: 0.45),
                    .init(color: .clear, location: 0.55),
                    .init(color: .purple, location: 0.75),
                    .init(color: .orange, location: 1),
                ],
                center: .center, angle: turn
            )
            .blendMode(isAdditive ? .screen : .normal)
        }
        .compositingGroup()
    }
}

extension View {
    /// Floats the `GeneratingPill` above the bottom of the screen for as long
    /// as `isGenerating` holds. Applied to the screen itself, so it sits over
    /// the page whatever scrolls; the page stays readable and usable under it.
    func generatingPill(_ isGenerating: Bool) -> some View {
        modifier(GeneratingPillHost(isGenerating: isGenerating))
    }
}

/// `generatingPill`, as a modifier so the pill can dissolve before it is
/// reset for its next arrival.
private struct GeneratingPillHost: ViewModifier {
    let isGenerating: Bool

    @State private var stage: GeneratingPill.Stage = .gone
    @State private var sequence: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                GeneratingPill(stage: stage)
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
            }
            .onChange(of: isGenerating, initial: true) { _, isOn in
                sequence?.cancel()
                sequence = Task { isOn ? arrive() : await leave() }
            }
    }

    private func arrive() {
        guard stage != .open else { return }
        if stage == .vanished { stage = .gone }
        withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .spring(duration: 0.5, bounce: 0.3)) {
            stage = .open
        }
    }

    private func leave() async {
        guard stage == .open else { return }
        withAnimation(.easeIn(duration: reduceMotion ? 0.3 : 0.45)) { stage = .vanished }
        try? await Task.sleep(for: .seconds(0.45))
        guard !Task.isCancelled else { return }
        stage = .gone
    }
}

#Preview("Stages") {
    VStack(spacing: 28) {
        ForEach(GeneratingPill.Stage.allCases, id: \.self) { stage in
            GeneratingPill(stage: stage)
        }
        GeneratingPill(stage: .open).scaleEffect(1.6).padding(.top, 20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
}

#Preview("Live") {
    @Previewable @State var isGenerating = false
    VStack {
        Toggle(isOn: $isGenerating) { Text(verbatim: "Generating") }.padding()
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
    .generatingPill(isGenerating)
}
