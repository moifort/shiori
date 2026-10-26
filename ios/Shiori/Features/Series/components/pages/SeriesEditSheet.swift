import SwiftUI

/// Correcting a saga where the AI was wrong or said nothing, laid out as a
/// book's form. The name and the description are the shared catalogue's, so
/// every reader of the edition sees the correction; the format is the reader's
/// own volumes', every one of them at once.
///
/// A saga heard offers no format: a recording is an edition of its own. A
/// saga nobody catalogued offers no description, having no catalogue to hold
/// one.
///
/// The form edits text as the reader sees it and works out the difference only
/// on save, so a field left alone is never sent and one emptied is cleared.
struct SeriesEditSheet: View {
    let name: String
    let format: BookFormat
    let description: String?
    let isAudio: Bool
    /// The edition has a stored catalogue, the only place a description lives.
    let isCatalogued: Bool
    /// Answers nil once saved, or the message to show when the save failed.
    let onSave: (SeriesCorrection) async -> String?
    @Environment(\.dismiss) private var dismiss

    @State private var editedName: String
    @State private var editedFormat: BookFormat
    @State private var editedDescription: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        name: String,
        format: BookFormat,
        description: String?,
        isAudio: Bool,
        isCatalogued: Bool,
        onSave: @escaping (SeriesCorrection) async -> String?
    ) {
        self.name = name
        self.format = format
        self.description = description
        self.isAudio = isAudio
        self.isCatalogued = isCatalogued
        self.onSave = onSave
        _editedName = State(initialValue: name)
        _editedFormat = State(initialValue: format)
        _editedDescription = State(initialValue: description ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledField(title: "Nom", icon: "textformat") {
                        TextField("Nom", text: $editedName, axis: .vertical)
                            .textInputAutocapitalization(.words)
                            .accessibilityIdentifier("series-edit-name")
                    }
                    if !isAudio {
                        MenuPicker(
                            "Format",
                            systemImage: "books.vertical",
                            selection: $editedFormat,
                            options: BookFormat.allCases.filter { $0 != .audiobook },
                            label: { $0.label },
                            image: { Image(systemName: $0.symbol) }
                        )
                        .accessibilityIdentifier("series-edit-format")
                    }
                } footer: {
                    if trimmed(editedName).isEmpty {
                        Text("Une série a besoin d'un nom.").foregroundStyle(.red)
                    }
                }

                if isCatalogued {
                    Section("Résumé") {
                        TextField("Résumé", text: $editedDescription, axis: .vertical)
                            .lineLimit(3...12)
                            .accessibilityIdentifier("series-edit-description")
                    }
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
                        .disabled(trimmed(editedName).isEmpty || correction.isEmpty || isSaving)
                        .accessibilityIdentifier("series-edit-save")
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

    private var correction: SeriesCorrection {
        var correction = SeriesCorrection()
        if !trimmed(editedName).isEmpty, trimmed(editedName) != name { correction.name = trimmed(editedName) }
        if !isAudio, editedFormat != format { correction.format = editedFormat }
        if isCatalogued {
            let text = trimmed(editedDescription)
            if text != (description ?? "") { correction.description = text.isEmpty ? .clear : .set(text) }
        }
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

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview("Catalogued") {
    SeriesEditSheet(
        name: "Naruto (French Edition)",
        format: .book,
        description: "Une saga de pirates.",
        isAudio: false,
        isCatalogued: true,
        onSave: { _ in nil }
    )
}

#Preview("Heard, uncatalogued") {
    SeriesEditSheet(
        name: "La Roue du temps",
        format: .audiobook,
        description: nil,
        isAudio: true,
        isCatalogued: false,
        onSave: { _ in nil }
    )
}
