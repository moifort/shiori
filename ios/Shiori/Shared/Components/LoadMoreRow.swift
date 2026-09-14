import SwiftUI

/// Pagination sentinel row: it triggers the next page load when it appears, and turns
/// into a retry button when the page failed, otherwise the spinner would keep turning
/// forever without a new attempt.
struct LoadMoreRow: View {
    let failed: Bool
    let loadingLabel: LocalizedStringKey
    let onLoadMore: () async -> Void

    var body: some View {
        HStack {
            Spacer()
            if failed {
                Button {
                    Task { await onLoadMore() }
                } label: {
                    Label("Réessayer", systemImage: "arrow.clockwise")
                }
                .accessibilityIdentifier("load-more-retry")
            } else {
                ProgressView()
                    .accessibilityLabel(loadingLabel)
                    .task { await onLoadMore() }
            }
            Spacer()
        }
        .listRowSeparator(.hidden)
    }
}

#Preview("Loading") {
    List {
        LoadMoreRow(failed: false, loadingLabel: "Chargement de plus de vins", onLoadMore: {})
    }
}

#Preview("Failed") {
    List {
        LoadMoreRow(failed: true, loadingLabel: "Chargement de plus de vins", onLoadMore: {})
    }
}
