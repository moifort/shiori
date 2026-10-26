import SwiftUI

/// The faces a reader may give an author, opened from the "…" menu of their
/// page, as a book's covers are: the one drawn now first, then what Wikipedia,
/// Wikidata and Open Library found, each under its source. An image address
/// pasted below joins them as one more choice. Nothing here calls the AI.
///
/// The face drawn now is picked when the sheet opens, so confirming stays off
/// until the reader picks another. The one chosen goes into the shared
/// catalogue, and no lookup replaces it after.
struct PortraitPickerSheet: View {
    let initials: String
    /// Nil while the faces are sought.
    let choices: [PortraitChoice]?
    /// Why they could not be sought.
    let loadFailed: String?
    /// Answers nil once the author is drawn with it, or the message to show.
    let onChoose: (PortraitChoice) async -> String?
    @Environment(\.dismiss) private var dismiss

    @State private var picked: URL?
    @State private var pasted = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let portraitSize: CGFloat = 92
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14, alignment: .top), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    portraits
                    pasteField
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Portrait")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Annuler", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmingAction) {
                    AsyncToolbarButton(title: "Choisir ce portrait", systemImage: "checkmark") {
                        await choose()
                    }
                    .disabled(chosen == nil || chosen?.isCurrent == true || isSaving)
                    .accessibilityIdentifier("portrait-choose")
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

    // MARK: - Portraits

    @ViewBuilder
    private var portraits: some View {
        if let choices {
            if offered.isEmpty {
                Text("Aucun portrait trouvé pour cet auteur. Collez l'adresse d'une image.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: columns, spacing: 22) {
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
                Text("Recherche des portraits…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        }
    }

    /// The face picked wears the check, as a cover picked does; the one drawn
    /// now says so under itself, and keeps saying it once another is picked.
    private func tile(_ choice: PortraitChoice) -> some View {
        let isPicked = choice.url == selection
        return Button {
            picked = choice.url
        } label: {
            VStack(spacing: 8) {
                AuthorAvatar(initials: initials, portraitURL: choice.url, size: Self.portraitSize)
                    .overlay(alignment: .bottom) {
                        if choice.isCurrent {
                            Text("Actuel")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.7), in: Capsule())
                                .padding(.bottom, 4)
                        }
                    }
                    .padding(4)
                    .overlay {
                        Circle().strokeBorder(isPicked ? Color.accentColor : .clear, lineWidth: 3)
                    }
                    .overlay(alignment: .topTrailing) {
                        if isPicked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.accentColor, in: Circle())
                                .overlay(Circle().strokeBorder(Color(.systemGroupedBackground), lineWidth: 2.5))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.snappy, value: isPicked)
                Text(Self.label(of: choice.source))
                    .font(.caption)
                    .foregroundStyle(isPicked ? .primary : .secondary)
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
                    .accessibilityIdentifier("portrait-url")
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
        // A valid address is picked as soon as it is typed.
        .onChange(of: pastedChoice?.url) { _, url in
            if let url { picked = url }
        }
    }

    /// The address typed, as a choice once it is one the server takes: HTTPS
    /// only, since App Transport Security blocks anything else from drawing.
    private var pastedChoice: PortraitChoice? {
        let typed = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard typed.hasPrefix("https://"), let url = URL(string: typed), url.host() != nil else { return nil }
        if let offered = choices?.first(where: { $0.url == url }) { return offered }
        return PortraitChoice(source: .web, url: url, isCurrent: false)
    }

    private var pastedProblem: Bool {
        !pasted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && pastedChoice == nil
    }

    // MARK: - Choosing

    private var offered: [PortraitChoice] {
        let found = choices ?? []
        guard let pastedChoice, !found.contains(pastedChoice) else { return found }
        return found + [pastedChoice]
    }

    private var selection: URL? {
        picked ?? choices?.first(where: \.isCurrent)?.url
    }

    private var chosen: PortraitChoice? {
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

    static func label(of source: PortraitChoice.Source) -> LocalizedStringKey {
        switch source {
        case .wikipedia: "Wikipédia"
        case .wikidata: "Wikidata"
        case .openLibrary: "Open Library"
        case .web: "Web"
        }
    }
}

#Preview("Found") {
    PortraitPickerSheet(initials: "RH", choices: PortraitChoice.previews, loadFailed: nil) { _ in nil }
}

#Preview("Seeking") {
    PortraitPickerSheet(initials: "RH", choices: nil, loadFailed: nil) { _ in nil }
}

#Preview("None found") {
    PortraitPickerSheet(initials: "RH", choices: [], loadFailed: nil) { _ in nil }
}
