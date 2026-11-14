import SwiftUI

/// Shown while the model calls run — a cover, a shared link or a chosen title
/// being read. A cold scan takes the better part of a minute, so this shows the
/// AI at work — Siri's orb on a dark page, as the shelf search does — under one
/// plain line, rather than a bare spinner over an unexplained wait.
struct ScanAnalyzingPage: View {
    /// The JPEG that was sent for analysis. Kept so the screen can retry with
    /// it; the orb does not draw it.
    var coverData: Data?

    var body: some View {
        VStack(spacing: 22) {
            SiriOrb()
            Text("Analyse de la couverture")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    ScanAnalyzingPage()
}
