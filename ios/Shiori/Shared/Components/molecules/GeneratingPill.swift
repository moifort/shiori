import SwiftUI

/// Says that the AI is preparing the page, without covering it: a small pill
/// floating above the tab bar, the `AIOrb` beside one line of text, lit by
/// Siri's kind of light — a fine rim, a halo and a wide wash, whose colours
/// cross as they turn. It is born as the orb, wraps a shell round it and
/// stretches to the words; at the end the words fold back into the orb, the
/// shell lets go, and the orb spins up and vanishes. No "done": what the AI
/// wrote appearing in the page says it. Never takes a touch.
struct GeneratingPill: View {
    /// Where the pill is in its life, from nothing to open and back.
    enum Stage: CaseIterable {
        /// Not there: the orb is a point, turned back, out of focus.
        case gone
        /// The orb alone.
        case orb
        /// The shell round the orb, the words still folded.
        case shell
        /// Open on its words.
        case open
        /// The orb grown and spun, the shell gone: the last beat.
        case burst
        /// Spun down to nothing.
        case vanished
    }

    let stage: Stage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            AIOrb(size: 24)
                .scaleEffect(orbScale)
                .rotationEffect(.degrees(orbTurn))
            if stage == .open {
                Text("L'IA prépare la fiche")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.leading, 8)
                    .padding(.trailing, 10)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeOut(duration: 0.3).delay(0.25)),
                        removal: .opacity.animation(.easeIn(duration: 0.15))
                    ))
            }
        }
        .padding(4)
        .background {
            GeneratingPillShell(paused: reduceMotion)
                .opacity(hasShell ? 1 : 0)
                .scaleEffect(hasShell ? 1 : 0.4)
        }
        .opacity(stage == .vanished ? 0 : 1)
        .blur(radius: stage == .gone ? 3 : stage == .vanished ? 4 : 0)
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("L'IA prépare la fiche"))
        .accessibilityIdentifier("generating")
        .accessibilityHidden(stage == .gone || stage == .vanished)
    }

    private var hasShell: Bool { stage == .shell || stage == .open }

    private var orbScale: CGFloat {
        switch stage {
        case .gone, .vanished: 0
        case .burst: 1.35
        default: 1
        }
    }

    private var orbTurn: Double {
        switch stage {
        case .gone: -120
        case .burst: 200
        case .vanished: 540
        default: 0
        }
    }
}

/// The pill's body and its light. The light is two colour fields turning
/// against each other at different speeds, laid three times: a wide wash, a
/// halo, and a one-point rim.
private struct GeneratingPillShell: View {
    let paused: Bool

    var body: some View {
        TimelineView(.animation(paused: paused)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let field = LightField(
                turn: .degrees(time.truncatingRemainder(dividingBy: 3.4) / 3.4 * 360),
                turnBack: .degrees(-time.truncatingRemainder(dividingBy: 5.3) / 5.3 * 360)
            )
            ZStack {
                field
                    .clipShape(Capsule())
                    .padding(.horizontal, -22)
                    .padding(.vertical, -14)
                    .blur(radius: 30)
                    .opacity(0.28)
                field
                    .clipShape(Capsule())
                    .padding(-4)
                    .blur(radius: 12)
                    .opacity(0.7)
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(Color(white: 0.14).opacity(0.85)))
                field
                    .mask(Capsule().strokeBorder(lineWidth: 1))
            }
        }
    }
}

/// Two angular gradients in the `AIGlow` colours, the warm one gapped so the
/// cool one shows through, added together as light is.
private struct LightField: View {
    let turn: Angle
    let turnBack: Angle

    var body: some View {
        ZStack {
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
            .blendMode(.screen)
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

/// `generatingPill`, as a modifier so the pill can play its arrival and its
/// departure as sequences. Work that ends while the pill is still arriving
/// leaves from wherever it got to.
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
                sequence = Task { isOn ? await arrive() : await leave() }
            }
    }

    private func arrive() async {
        guard stage != .open else { return }
        if reduceMotion {
            stage = .shell
            withAnimation(.easeOut(duration: 0.3)) { stage = .open }
            return
        }
        if stage != .gone, stage != .orb, stage != .shell { stage = .gone }
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) { stage = .orb }
        guard await pause(0.2) else { return }
        withAnimation(.spring(duration: 0.45, bounce: 0.25)) { stage = .shell }
        guard await pause(0.35) else { return }
        withAnimation(.spring(duration: 0.6, bounce: 0.2)) { stage = .open }
    }

    private func leave() async {
        guard stage != .gone else { return }
        if reduceMotion {
            withAnimation(.easeIn(duration: 0.3)) { stage = .vanished }
            guard await pause(0.3) else { return }
            stage = .gone
            return
        }
        withAnimation(.easeInOut(duration: 0.4)) { stage = .shell }
        guard await pause(0.35) else { return }
        withAnimation(.easeOut(duration: 0.4)) { stage = .burst }
        guard await pause(0.4) else { return }
        withAnimation(.easeIn(duration: 0.6)) { stage = .vanished }
        guard await pause(0.6) else { return }
        stage = .gone
    }

    /// Waits between two beats; false when the sequence was replaced meanwhile.
    private func pause(_ seconds: Double) async -> Bool {
        try? await Task.sleep(for: .seconds(seconds))
        return !Task.isCancelled
    }
}

#Preview("Stages") {
    VStack(spacing: 28) {
        ForEach(GeneratingPill.Stage.allCases, id: \.self) { stage in
            GeneratingPill(stage: stage)
        }
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
