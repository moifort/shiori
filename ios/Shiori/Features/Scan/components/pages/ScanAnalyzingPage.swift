import SwiftUI

/// Shown while the three model calls run. A cold scan takes the better part of a
/// minute, so this shows the reader's own cover being swept by the scan and says
/// what is happening, rather than a bare spinner over an unexplained wait.
struct ScanAnalyzingPage: View {
    /// The JPEG that was sent for analysis, decoded once here for the loader.
    var coverData: Data?

    @State private var phase = 0

    private static let phases = [
        String(localized: "Lecture de la couverture..."),
        String(localized: "Recherche du livre..."),
        String(localized: "Recherche de la série..."),
    ]

    private var cover: UIImage? { coverData.flatMap(UIImage.init(data:)) }

    var body: some View {
        VStack(spacing: 32) {
            CoverScanLoader(cover: cover)
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
