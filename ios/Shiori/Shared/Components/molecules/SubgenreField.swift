import SwiftUI

/// The subgenre field of a form: free text, comma-separated, with the reader's
/// own vocabulary proposed underneath as they type. The proposals come from
/// their shelf rather than from a list nobody agreed on, so "dark fantasy"
/// is spelled the way they spelled it last time.
///
/// Tapping a proposal completes the word being typed. The field never
/// invents a subgenre: an empty shelf proposes nothing, and the reader types.
struct SubgenreField: View {
    @Binding var text: String
    /// The vocabulary to propose, most used first. Empty until the caller has
    /// fetched it, and the field is plain text meanwhile.
    let suggestions: [String]

    private static let maximum = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Dark fantasy, Jeunesse", text: $text)
                .accessibilityIdentifier("edit-subgenres")
            if !proposals.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(proposals, id: \.self) { proposal in
                            Button {
                                complete(with: proposal)
                            } label: {
                                Text(proposal)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.quaternary, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("subgenre-suggestion")
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    /// The entries already committed: everything before the last comma.
    private var committed: [String] {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false).map(trim)
        return Array(parts.dropLast()).filter { !$0.isEmpty }
    }

    /// What is being typed: after the last comma.
    private var current: String {
        text.split(separator: ",", omittingEmptySubsequences: false).last.map(trim) ?? ""
    }

    /// The vocabulary narrowed to the word being typed, minus what is already
    /// on the line. With three subgenres in place there is nothing left to add.
    private var proposals: [String] {
        guard committed.count < Self.maximum else { return [] }
        let taken = Set(committed.map { $0.lowercased() })
        let prefix = current.lowercased()
        return suggestions
            .filter { !taken.contains($0.lowercased()) }
            .filter { prefix.isEmpty || $0.lowercased().hasPrefix(prefix) || $0.lowercased().contains(prefix) }
            .filter { $0.lowercased() != prefix }
            .prefix(8)
            .map { $0 }
    }

    private func complete(with proposal: String) {
        let entries = committed + [proposal]
        text = entries.joined(separator: ", ") + (entries.count < Self.maximum ? ", " : "")
    }

    private func trim(_ value: some StringProtocol) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    @Previewable @State var text = "Dark fantasy, "
    Form {
        SubgenreField(text: $text, suggestions: ["Space opera", "Jeunesse", "Aventure", "Dark fantasy"])
    }
}
