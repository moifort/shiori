import SwiftUI

/// Shown while the model calls run. A cold scan takes the better part of a
/// minute, so this shows the AI at work — the wave — under one plain line
/// saying what is read, rather than a bare spinner over an unexplained wait.
struct ScanAnalyzingPage: View {
    /// The JPEG that was sent for analysis. Kept so the screen can retry with
    /// it; the wave does not draw it.
    var coverData: Data?

    var body: some View {
        VStack(spacing: 40) {
            AIWave()
            Text("Analyse de la couverture")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    ScanAnalyzingPage()
}
