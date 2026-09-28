import SwiftUI

/// The very first look at Découvrir, while everything the reader follows is
/// looked up on the web: up to a minute and a half, so it says so, and makes
/// the wait a small show rather than a spinner.
///
/// A pair of binoculars bobs over a landscape that scrolls past beneath it —
/// mountains, sea, forests, towns, bookshops — faded out at both edges, and a
/// line under the title changes every few seconds to say where the search has
/// got to. Reduce Motion holds the landscape still; the lines still change.
struct DiscoverFirstLookView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time so the landscape starts from its beginning.
    @State private var start = Date()
    @State private var line = 0

    /// Where the search has got to, one after the other, round and round.
    private let lines: [LocalizedStringKey] = [
        "On interroge les libraires",
        "On secoue les éditeurs",
        "On fouille sous les tables de nouveautés",
        "On demande aux sirènes si elles ont lu la suite",
        "On traverse la forêt des manuscrits",
        "On réveille le bibliothécaire",
        "On époussette les couvertures",
    ]

    /// The landscape, left to right; drawn twice so it loops without a seam.
    private let landscape = [
        "mountain.2.fill", "water.waves", "sailboat.fill", "fish.fill", "tree.fill",
        "building.2.fill", "books.vertical.fill", "tent.fill", "water.waves", "building.columns.fill",
    ]

    private let spacing: CGFloat = 26
    private let symbolSize: CGFloat = 30
    /// Points the landscape travels per second.
    private let speed: CGFloat = 38
    /// Seconds each line stays on screen.
    private let lineDuration: Duration = .seconds(3.2)

    var body: some View {
        VStack(spacing: 28) {
            scene
            VStack(spacing: 10) {
                Text("On retourne terre et mer…")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(lines[line])
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .id(line)
                    // The line leaving fades where it stands: pushed up, it
                    // would cross the title.
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            Text("La première visite peut prendre jusqu'à une minute et demie. Les suivantes s'ouvrent aussitôt.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .task { await cycleLines() }
    }

    // MARK: - Scene

    private var scene: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(start)
            ZStack {
                strip(offset: stripOffset(at: elapsed))
                    .frame(width: 260, height: 70)
                    .clipped()
                    .mask(fadedEdges)
                    .offset(y: 28)
                Image(systemName: "binoculars.fill")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .rotationEffect(.degrees(reduceMotion ? 0 : sin(elapsed * 1.6) * 7))
                    .offset(y: reduceMotion ? -26 : -26 + sin(elapsed * 2.4) * 4)
            }
            .frame(width: 260, height: 130)
        }
        .accessibilityHidden(true)
    }

    /// The landscape twice over, slid left by `offset`.
    private func strip(offset: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<(landscape.count * 2), id: \.self) { index in
                Image(systemName: landscape[index % landscape.count])
                    .font(.system(size: symbolSize))
                    .foregroundStyle(.secondary)
                    .frame(width: symbolSize)
            }
        }
        .fixedSize()
        .offset(x: -offset)
        .frame(width: 260, alignment: .leading)
    }

    /// The width of one copy of the landscape, for the seamless loop.
    private var loopWidth: CGFloat { CGFloat(landscape.count) * (symbolSize + spacing) }

    private func stripOffset(at elapsed: TimeInterval) -> CGFloat {
        (CGFloat(elapsed) * speed).truncatingRemainder(dividingBy: loopWidth)
    }

    private var fadedEdges: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.2),
                .init(color: .black, location: 0.8),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Lines

    /// Moves to the next line every few seconds, back to the first after the
    /// last: a slow lookup must not sit on a line that says it is nearly done.
    private func cycleLines() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: lineDuration)
            guard !Task.isCancelled else { return }
            withAnimation(.smooth) { line = (line + 1) % lines.count }
        }
    }
}

#Preview {
    DiscoverFirstLookView()
}

#Preview("Dark") {
    DiscoverFirstLookView().preferredColorScheme(.dark)
}
