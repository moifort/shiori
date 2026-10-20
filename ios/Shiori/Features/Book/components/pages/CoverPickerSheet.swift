import SwiftUI

/// The covers a reader may give a book, opened from its "…" menu: the one
/// drawn now first, then what the record holds and what Amazon and Open Library
/// found, each under its source. An image address pasted below joins them as
/// one more choice. Nothing here calls the AI: the covers are free to seek.
///
/// The cover drawn now is picked when the sheet opens, so confirming stays off
/// until the reader picks another.
struct CoverPickerSheet: View {
    let book: Book
    /// Nil while the covers are sought.
    let choices: [CoverChoice]?
    /// Why they could not be sought.
    let loadFailed: String?
    /// Answers nil once the book is drawn with it, or the message to show.
    let onChoose: (CoverChoice) async -> String?
    @Environment(\.dismiss) private var dismiss

    @State private var picked: URL?
    @State private var pasted = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let coverWidth: CGFloat = 96
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    covers
                    pasteField
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Couverture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    AsyncToolbarButton(title: "Choisir cette couverture", systemImage: "checkmark") {
                        await choose()
                    }
                    .disabled(chosen == nil || chosen?.isCurrent == true || isSaving)
                    .accessibilityIdentifier("cover-choose")
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
        }
    }

    // MARK: - Covers

    @ViewBuilder
    private var covers: some View {
        if let choices {
            if offered.isEmpty {
                Text("Aucune couverture trouvée pour ce livre. Collez l'adresse d'une image.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(offered) { choice in
                        tile(choice)
                    }
                }
                .animation(.smooth, value: choices.count + (pastedChoice == nil ? 0 : 1))
            }
        } else if let loadFailed {
            Text(loadFailed)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else {
            VStack(spacing: 12) {
                ProgressView()
                Text("Recherche des couvertures…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        }
    }

    private func tile(_ choice: CoverChoice) -> some View {
        let isPicked = choice.url == selection
        return Button {
            picked = choice.url
        } label: {
            VStack(spacing: 6) {
                BookCover(book: book(drawnWith: choice.url), width: Self.coverWidth, showsFormatBadge: false)
                    .padding(4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isPicked ? Color.accentColor : .clear, lineWidth: 3)
                    }
                VStack(spacing: 1) {
                    Text(Self.label(of: choice.source))
                        .font(.caption)
                        .foregroundStyle(isPicked ? .primary : .secondary)
                    if choice.isCurrent {
                        Label("Actuelle", systemImage: "checkmark")
                            .font(.caption2)
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.tint)
                    }
                }
                .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    // MARK: - Pasted address

    private var pasteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "link")
                    .foregroundStyle(.tint)
                    .padding(.top, 2)
                TextField("Coller l'adresse d'une image", text: $pasted, axis: .vertical)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("cover-url")
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12))
            if pastedProblem {
                Text("L'URL doit commencer par https://.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
            }
        }
        // A valid address is picked as soon as it is typed: pasting it says
        // which cover the reader wants.
        .onChange(of: pastedChoice?.url) { _, url in
            if let url { picked = url }
        }
    }

    /// The address typed, as a choice once it is one the server takes: HTTPS
    /// only, since App Transport Security blocks anything else from drawing.
    private var pastedChoice: CoverChoice? {
        let typed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.hasPrefix("https://"), let url = URL(string: typed), url.host() != nil else { return nil }
        if let offered = choices?.first(where: { $0.url == url }) { return offered }
        return CoverChoice(source: .web, url: url, isCurrent: false)
    }

    private var pastedProblem: Bool {
        !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pastedChoice == nil
    }

    // MARK: - Choosing

    /// What the grid shows: the covers found, and the address pasted when it
    /// names none of them.
    private var offered: [CoverChoice] {
        let found = choices ?? []
        guard let pastedChoice, !found.contains(pastedChoice) else { return found }
        return found + [pastedChoice]
    }

    /// The cover picked, the one drawn now until the reader picks another.
    private var selection: URL? {
        picked ?? choices?.first(where: \.isCurrent)?.url
    }

    private var chosen: CoverChoice? {
        offered.first { $0.url == selection }
    }

    private func choose() async {
        guard let chosen else { return }
        isSaving = true
        defer { isSaving = false }
        if let failure = await onChoose(chosen) {
            errorMessage = failure
        } else {
            dismiss()
        }
    }

    private func book(drawnWith url: URL) -> Book {
        var drawn = book
        drawn.coverURL = url
        return drawn
    }

    static func label(of source: CoverChoice.Source) -> LocalizedStringKey {
        switch source {
        case .kindle: "Kindle"
        case .photo: "Votre photo"
        case .amazon: "Amazon"
        case .openLibrary: "Open Library"
        case .otherEdition: "Autre édition"
        case .web: "Web"
        }
    }
}

#Preview("Found") {
    CoverPickerSheet(book: .preview, choices: CoverChoice.previews, loadFailed: nil) { _ in nil }
}

#Preview("Seeking") {
    CoverPickerSheet(book: .preview, choices: nil, loadFailed: nil) { _ in nil }
}

#Preview("None found") {
    CoverPickerSheet(book: .preview, choices: [], loadFailed: nil) { _ in nil }
}
