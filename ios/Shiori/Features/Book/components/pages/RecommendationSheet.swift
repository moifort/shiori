import SwiftUI

/// Who recommended the book, as in Vinarium's "Conseillé par un ami": a name,
/// typed or picked from the contacts, and what they said of it. Opened from the
/// book's menu, or from the recommendation itself once there is one, and then
/// filled with it so the reader corrects rather than retypes.
struct RecommendationSheet: View {
    let current: BookRecommendation?
    /// Answers nil once saved, or the message to show when the save failed.
    /// Nil forgets the recommendation.
    let onSave: (BookRecommendation?) async -> String?
    @Environment(\.dismiss) private var dismiss

    @State private var recommenderName: String
    @State private var comment: String
    @State private var showContactPicker = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(current: BookRecommendation?, onSave: @escaping (BookRecommendation?) async -> String?) {
        self.current = current
        self.onSave = onSave
        _recommenderName = State(initialValue: current?.recommenderName ?? "")
        _comment = State(initialValue: current?.comment ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("Conseillé par", systemImage: "person.badge.star")
                            .foregroundStyle(.secondary)
                        TextField("Nom", text: $recommenderName)
                            .textInputAutocapitalization(.words)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("recommendation-name")
                        Button {
                            showContactPicker = true
                        } label: {
                            Image(systemName: "person.crop.circle")
                                .font(.title2)
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Choisir dans les contacts"))
                        .accessibilityIdentifier("recommendation-contacts")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Pourquoi ce conseil ?", systemImage: "text.quote")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("Ce qu'on vous en a dit…", text: $comment, axis: .vertical)
                            .lineLimit(3...6)
                            .accessibilityIdentifier("recommendation-comment")
                    }
                    .padding(.vertical, 4)
                }

                if current != nil {
                    Section {
                        Button("Retirer le conseil", role: .destructive) {
                            Task { await save(nil) }
                        }
                        .accessibilityIdentifier("recommendation-remove")
                    }
                }
            }
            .navigationTitle("Conseillé par un ami")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AsyncToolbarButton(title: "Enregistrer", systemImage: "checkmark") {
                        await save(edited)
                    }
                    .disabled(edited == current || isSaving)
                    .accessibilityIdentifier("recommendation-save")
                }
            }
            .disabled(isSaving)
            .alert(
                "Une erreur est survenue",
                isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPicker { name in
                    recommenderName = name
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    /// What the form says now. Nil when both halves are empty: a recommendation
    /// that names nobody and says nothing is one taken back.
    private var edited: BookRecommendation? {
        let name = recommenderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty || !words.isEmpty else { return nil }
        return BookRecommendation(
            recommenderName: name.isEmpty ? nil : name,
            comment: words.isEmpty ? nil : words
        )
    }

    private func save(_ recommendation: BookRecommendation?) async {
        isSaving = true
        defer { isSaving = false }
        if let failure = await onSave(recommendation) {
            errorMessage = failure
        } else {
            dismiss()
        }
    }
}

#Preview("New") {
    RecommendationSheet(current: nil) { _ in nil }
}

#Preview("Existing") {
    RecommendationSheet(
        current: BookRecommendation(recommenderName: "Marie Curie", comment: "Lis-le cet été.")
    ) { _ in nil }
}
