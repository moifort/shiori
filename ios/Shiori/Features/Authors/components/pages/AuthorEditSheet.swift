import SwiftUI

/// Correcting what the world knows of an author, laid out as a book's form:
/// where they come from, when they lived, who they are. Written into the
/// shared catalogue, so every reader sees the correction, and never written
/// over by the AI after it. The name is the books' and is corrected there.
///
/// The form edits text as the reader sees it and works out the difference only
/// on save, so a field left alone is never sent and one emptied is cleared.
struct AuthorEditSheet: View {
    let page: AuthorPage
    /// Answers nil once saved, or the message to show when the save failed.
    let onSave: (AuthorCorrection) async -> String?
    @Environment(\.dismiss) private var dismiss

    @State private var nationality: String
    @State private var birthYear: String
    @State private var deathYear: String
    @State private var biography: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(page: AuthorPage, onSave: @escaping (AuthorCorrection) async -> String?) {
        self.page = page
        self.onSave = onSave
        _nationality = State(initialValue: page.nationality ?? "")
        _birthYear = State(initialValue: page.birthYear.map(String.init) ?? "")
        _deathYear = State(initialValue: page.deathYear.map(String.init) ?? "")
        _biography = State(initialValue: page.biography ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledField(title: "Nationalité", icon: "globe") {
                        TextField("Nationalité", text: $nationality)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("author-edit-nationality")
                    }
                    LabeledField(title: "Naissance", icon: "calendar") {
                        TextField("Année", text: $birthYear)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("author-edit-birth")
                    }
                    LabeledField(title: "Décès", icon: "calendar.badge.minus") {
                        TextField("Année", text: $deathYear)
                            .keyboardType(.numberPad)
                            .accessibilityIdentifier("author-edit-death")
                    }
                } footer: {
                    if let problem = yearProblem {
                        Text(problem).foregroundStyle(.red)
                    }
                }

                Section("Biographie") {
                    TextField("Biographie", text: $biography, axis: .vertical)
                        .lineLimit(3...12)
                        .accessibilityIdentifier("author-edit-biography")
                }
            }
            .navigationTitle("Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmingAction) {
                    ToolbarIconButton(title: "Enregistrer", systemImage: "checkmark") { Task { await save() } }
                        .disabled(yearProblem != nil || correction.isEmpty || isSaving)
                        .accessibilityIdentifier("author-edit-save")
                }
            }
            .disabled(isSaving)
            .overlay { if isSaving { ProgressView() } }
            .alert(
                "Impossible d'enregistrer",
                isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(!correction.isEmpty)
    }

    /// A year the server would refuse, said in the form rather than after a
    /// round trip.
    private var yearProblem: String? {
        for text in [birthYear, deathYear] where !trimmed(text).isEmpty {
            // The server's bounds: printing, and a few years ahead.
            let latest = Calendar.current.component(.year, from: .now) + 10
            guard let year = Int(trimmed(text)), (1450...latest).contains(year) else {
                return String(localized: "L'année doit être un nombre à partir de 1450.")
            }
        }
        if let born = Int(trimmed(birthYear)), let died = Int(trimmed(deathYear)), died < born {
            return String(localized: "L'année de décès précède celle de naissance.")
        }
        return nil
    }

    private var correction: AuthorCorrection {
        var correction = AuthorCorrection()
        correction.nationality = change(from: page.nationality, to: optional(nationality))
        correction.birthYear = change(from: page.birthYear, to: Int(trimmed(birthYear)))
        correction.deathYear = change(from: page.deathYear, to: Int(trimmed(deathYear)))
        correction.biography = change(from: page.biography, to: optional(biography))
        return correction
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        if let failure = await onSave(correction) {
            errorMessage = failure
        } else {
            dismiss()
        }
    }

    private func change<Value: Equatable & Sendable>(from old: Value?, to new: Value?) -> BookCorrection.Change<Value>? {
        guard old != new else { return nil }
        return new.map { .set($0) } ?? .clear
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func optional(_ text: String) -> String? {
        trimmed(text).isEmpty ? nil : trimmed(text)
    }
}

#Preview {
    AuthorEditSheet(page: .preview) { _ in nil }
}
