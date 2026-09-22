import SwiftUI

/// The saga's name, with the reader's own sagas proposed underneath as they
/// type: picking one files the book with its siblings under the exact name
/// they carry.
struct SeriesNameField: View {
    @Binding var text: String
    let suggestions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Aucune", text: $text)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("edit-series-name")
            if !proposals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(proposals, id: \.self) { proposal in
                            Button {
                                text = proposal
                            } label: {
                                Text(proposal)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.quaternary, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("series-suggestion")
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    /// The reader's sagas narrowed to what is typed, and none once the name
    /// typed is one of them.
    private var proposals: [String] {
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !suggestions.contains(where: { $0.localizedCaseInsensitiveCompare(typed) == .orderedSame }) else {
            return []
        }
        return Array(
            suggestions
                .filter { typed.isEmpty || $0.localizedCaseInsensitiveContains(typed) }
                .prefix(8)
        )
    }
}
