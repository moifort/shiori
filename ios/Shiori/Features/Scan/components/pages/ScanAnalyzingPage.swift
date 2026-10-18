import SwiftUI

/// Shown while the model calls run. A cold scan takes the better part of a
/// minute, so this shows the AI at work — the orb — and says what is
/// happening, rather than a bare spinner over an unexplained wait. The
/// headline wears the glow, as the bar does elsewhere when the AI is writing.
struct ScanAnalyzingPage: View {
    /// The JPEG that was sent for analysis. Kept so the screen can retry with
    /// it; the orb does not draw it.
    var coverData: Data?

    @State private var phase = 0

    private static let phases = [
        String(localized: "Lecture de la couverture..."),
        String(localized: "Recherche du livre..."),
        String(localized: "Recherche de la série..."),
    ]

    var body: some View {
        VStack(spacing: 40) {
            AIOrb()
            VStack(spacing: 6) {
                GeneratingLabel(text: "L'IA lit la couverture", font: .headline)
                Text(Self.phases[min(phase, Self.phases.count - 1)])
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // Paced on the measured shape of a real scan: the cover comes back
            // quickly, the grounded steps do not.
            for delay in [4.0, 20.0] {
                try? await Task.sleep(for: .seconds(delay))
                withAnimation { phase += 1 }
            }
        }
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    ScanAnalyzingPage()
}
