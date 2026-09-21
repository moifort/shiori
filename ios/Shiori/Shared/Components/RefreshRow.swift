import SwiftUI

/// The row that leads a screen which is already readable while it is being
/// brought up to date — a list or a scrolling page: what is below stays in
/// place and this one spins, the same circle a pull-to-refresh draws, on the
/// screen's own background. What a snapshot shows instead of a loader taking
/// the screen away from what it already has. The list-row modifiers are
/// simply ignored outside a `List`.
///
/// It never starts the work itself: the refresh is already in flight by the
/// time the row appears. It becomes a retry button when that refresh failed —
/// otherwise nothing on screen would say the rows are the ones from last time.
struct RefreshRow: View {
    let failed: Bool
    let loadingLabel: LocalizedStringKey
    let onRetry: () async -> Void

    var body: some View {
        HStack {
            Spacer()
            if failed {
                AsyncButton("Réessayer", systemImage: "arrow.clockwise") { await onRetry() }
                    .accessibilityIdentifier("refresh-retry")
            } else {
                ProgressView()
                    .accessibilityLabel(loadingLabel)
                    .accessibilityIdentifier("refresh-spinner")
            }
            Spacer()
        }
        // The pull-to-refresh circle sits on the list's background, not on a
        // card: a plain row would give this one the height and the fill of a book.
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 6, trailing: 0))
        .listRowSeparator(.hidden)
    }
}
