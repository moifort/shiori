import SwiftUI

/// The month's first discoveries one under the other, each with why, a tap on
/// one opening its page; a line closes them off from the strip under them,
/// when there is one. Découvrir and the home page draw them alike.
struct DiscoverySuggestionRows: View {
    let suggestions: [Suggestion]
    /// The strip of the others follows.
    let isClosed: Bool
    let onOpen: (Suggestion) -> Void

    /// How many of the month's discoveries are drawn with their reason.
    static let count = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(suggestions) { suggestion in
                if suggestion.id != suggestions.first?.id { Divider().padding(.leading, 68) }
                Button { onOpen(suggestion) } label: {
                    DiscoverySuggestionRow(suggestion: suggestion)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("discover-suggestion")
            }
            // The rows end on a line across the card's width, over the strip
            // of the others.
            if isClosed { Divider() }
        }
    }
}

#Preview {
    List {
        DiscoverySuggestionRows(
            suggestions: Array(MonthlyDiscoveries.preview.suggestions.prefix(DiscoverySuggestionRows.count)),
            isClosed: true
        ) { _ in }
    }
}
