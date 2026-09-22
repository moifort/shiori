import SwiftUI

/// Asks how many volumes a saga has, for a saga nobody has catalogued: the
/// reader's own count, from which their screen is drawn until the world
/// describes the saga. A stepper and a field, because a manga runs to a
/// hundred volumes and a stepper alone would take a while to get there.
struct VolumeCountSheet: View {
    let seriesName: String
    @State var count: Int
    /// Saves the count. Answers an error message to show, or nil once saved.
    let onSave: (Int) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let range = 1...200

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Nombre de tomes") {
                        TextField("", value: $count, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("volume-count-field")
                    }
                    Stepper("Tomes", value: $count, in: Self.range)
                        .labelsHidden()
                        .accessibilityIdentifier("volume-count-stepper")
                } footer: {
                    Text("Vos tomes prendront leur place dans la série, et ceux qui vous manquent seront listés par leur numéro. Le catalogue complet remplacera ce décompte dès que Shiori pourra le constituer.")
                }
            }
            .navigationTitle(seriesName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { Task { await save() } }
                        .disabled(isSaving || !Self.range.contains(count))
                        .accessibilityIdentifier("volume-count-save")
                }
            }
            .disabled(isSaving)
            .alert(
                "Enregistrement impossible",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        if let message = await onSave(count) {
            errorMessage = message
        } else {
            dismiss()
        }
    }
}

#Preview {
    VolumeCountSheet(seriesName: "One Piece", count: 3) { _ in nil }
}
