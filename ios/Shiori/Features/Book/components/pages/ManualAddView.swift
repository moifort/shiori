import SwiftUI

/// Adding a book without a photo: a book heard about, borrowed, or not yet
/// bought. Costs no scan, which is why the form exists at all rather than
/// pushing every entry through the camera.
///
/// Only the title is required. A book remembered from a conversation is still a
/// book, and demanding an author would send the reader back to a notes app.
struct ManualAddView: View {
    var onAdded: (Book) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var format: BookFormat = .book
    @State private var status: ReadingStatus = .toRead
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedAuthor: String { author.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titre", text: $title)
                        .focused($titleFocused)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("manual-title")
                    TextField("Auteur (facultatif)", text: $author)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("manual-author")
                    Picker("Format", selection: $format) {
                        ForEach(BookFormat.allCases) { Text($0.label).tag($0) }
                    }
                    .accessibilityIdentifier("manual-format")
                }
                Section("Lecture") {
                    ReadingStatusPicker(status: $status)
                }
                Section {
                    Text("Le résumé, la série et les autres informations ne sont renseignés que par un scan.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajouter un livre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { Task { await add() } }
                        .disabled(trimmedTitle.isEmpty || isSaving)
                        .accessibilityIdentifier("manual-save")
                }
            }
            .disabled(isSaving)
            .overlay { if isSaving { ProgressView() } }
            .alert(
                "Impossible d'ajouter ce livre",
                isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear { titleFocused = true }
        }
    }

    private func add() async {
        isSaving = true
        defer { isSaving = false }
        do {
            let book = try await BookAPI.add(
                BookDraft(
                    title: trimmedTitle,
                    authors: trimmedAuthor.isEmpty ? [] : [trimmedAuthor],
                    format: format,
                    status: status
                )
            )
            track(.bookAdded(source: .manual))
            onAdded(book)
            dismiss()
        } catch {
            errorMessage = reportError(error)
        }
    }
}

#Preview {
    ManualAddView(onAdded: { _ in })
}
