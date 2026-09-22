import SwiftUI

/// One suggestion, opened: the book, why it is proposed, what readers make of
/// it, and the three answers the reader can give — take it, say it is already
/// read, or never see it again.
struct SuggestionView: View {
    let suggestion: Suggestion
    /// Called with the suggestion's key once the reader answered, so the tab
    /// drops it.
    let onDone: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                ReadOnlyBookHeader(book: suggestion.book)

                Section {
                    Label {
                        Text(suggestion.reason)
                    } icon: {
                        Image(systemName: "lightbulb").foregroundStyle(.yellow)
                    }
                } header: {
                    Text("Pourquoi pour vous")
                }

                if suggestion.publicRating != nil || suggestion.award != nil || suggestion.releaseDate != nil {
                    Section {
                        if let rating = suggestion.publicRating {
                            LabeledInfoRow(
                                title: "Note des lecteurs",
                                value: ratingLine(rating),
                                icon: "star"
                            )
                        }
                        if let award = suggestion.award {
                            LabeledInfoRow(title: "Prix", value: award, icon: "trophy")
                        }
                        if let date = suggestion.releaseDate {
                            LabeledInfoRow(title: "Sortie", value: date, icon: "calendar")
                        }
                    }
                }

                if let synopsis = suggestion.book.synopsis, !synopsis.isEmpty {
                    ReadOnlySynopsisSection(synopsis: synopsis)
                }

                Section {
                    AsyncButton("Ajouter à ma pile à lire", systemImage: "bookmark.fill") {
                        await add(.toRead)
                    }
                    .accessibilityIdentifier("suggestion-add-pile")
                    AsyncButton("Je l'ai déjà lu", systemImage: "checkmark") {
                        await add(.read)
                    }
                    .accessibilityIdentifier("suggestion-add-read")
                    AsyncButton("Pas pour moi", systemImage: "hand.thumbsdown", role: .destructive) {
                        await notForMe()
                    }
                    .accessibilityIdentifier("suggestion-dismiss")
                } footer: {
                    Text("« Pas pour moi » affine les prochaines suggestions : ce livre ne reviendra pas.")
                }
            }
            .listStyle(.insetGrouped)
            .labelStyle(.row)
            .navigationTitle("Suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) { dismiss() }
                }
            }
            .alert(
                "Une erreur est survenue",
                isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func ratingLine(_ rating: Double) -> String {
        let stars = String(format: "%.1f / 5", rating)
        guard let count = suggestion.ratingCount else { return stars }
        return String(localized: "\(stars) · \(count.formatted(.number.notation(.compactName))) avis")
    }

    private func add(_ status: CopiedStatus) async {
        do {
            try await DiscoverAPI.add(key: suggestion.key, status: status)
            onDone(suggestion.key)
            dismiss()
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func notForMe() async {
        do {
            try await DiscoverAPI.dismiss(key: suggestion.key)
            onDone(suggestion.key)
            dismiss()
        } catch {
            errorMessage = reportError(error)
        }
    }
}
