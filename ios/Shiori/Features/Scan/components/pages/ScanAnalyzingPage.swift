import SwiftUI

/// Shown while the three model calls run. A cold scan takes the better part of a
/// minute, so this says what is happening rather than showing a bare spinner
/// over an unexplained wait.
struct ScanAnalyzingPage: View {
    @State private var phase = 0

    private static let phases = [
        String(localized: "Lecture de la couverture..."),
        String(localized: "Recherche du livre..."),
        String(localized: "Recherche de la série..."),
    ]

    var body: some View {
        VStack(spacing: 20) {
            PageTurnLoader()
            Text(Self.phases[min(phase, Self.phases.count - 1)])
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
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
