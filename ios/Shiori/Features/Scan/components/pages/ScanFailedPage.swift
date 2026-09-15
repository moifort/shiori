import SwiftUI

/// The analysis did not come back: a timeout, a dropped connection, a model
/// error. Unlike a cover nobody recognized, the photo was never the problem, so
/// the first offer is to run it again rather than to take another one.
///
/// Retrying is safe to promise: a scan that fails is not counted, and one that
/// finished server-side after the app gave up is served from the cache.
struct ScanFailedPage: View {
    /// What went wrong, as the error described it. Secondary on purpose: the
    /// reader needs the way out more than the diagnosis.
    let reason: String?
    let onRetry: () -> Void
    let onRetake: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("L'analyse n'a pas abouti", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: 8) {
                Text("L'analyse peut prendre jusqu'à une minute. Vous pouvez la relancer avec la même photo, sans dépenser de scan supplémentaire.")
                if let reason, !reason.isEmpty {
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        } actions: {
            Button("Relancer l'analyse", action: onRetry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("scan-retry")
            Button("Reprendre une photo", action: onRetake)
        }
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    ScanFailedPage(reason: "La requête a expiré.", onRetry: {}, onRetake: {})
}
