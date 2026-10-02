import SwiftUI

/// Picks the saga a duplicate is folded into. A scan and an import often name
/// one saga twice — "L'Assassin royal" and "L'Assassin royal (French
/// Edition)" — and the reader keeps one of the two: the duplicate's volumes
/// move there at their numbers, and the duplicate leaves the library.
///
/// Only the sagas taken in the same way are offered: a saga heard has a spine
/// of its own, and a printed volume filed under it would read as a recording.
/// The sagas by the same author come first, as the likeliest duplicates.
struct MergeSeriesSheet: View {
    let seriesId: String
    let seriesName: String
    let isAudio: Bool
    let author: String?
    let ownedCount: Int
    /// Folds the duplicate into the saga picked. Answers an error message to
    /// show, or nil once merged.
    let onMerge: (FollowedSeries) async -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [FollowedSeries] = []
    @State private var isLoading = true
    @State private var query = ""
    @State private var picked: FollowedSeries?
    @State private var isMerging = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if shown.isEmpty {
                    ContentUnavailableView(
                        query.isEmpty ? "Aucune autre série" : "Aucun résultat",
                        systemImage: "square.stack.3d.up.slash",
                        description: query.isEmpty
                            ? Text("Votre bibliothèque ne compte aucune autre série dans laquelle fusionner celle-ci.")
                            : nil
                    )
                } else {
                    List {
                        Section {
                            ForEach(shown) { candidate in
                                Button { picked = candidate } label: { row(candidate) }
                                    .tint(.primary)
                                    .accessibilityIdentifier("merge-candidate-\(candidate.seriesId)")
                            }
                        } footer: {
                            Text("Les livres de « \(seriesName) » rejoindront la série choisie, à leur numéro de tome.")
                        }
                    }
                }
            }
            .navigationTitle("Fusionner avec…")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Rechercher une série")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .confirmationDialog(
                "Fusionner dans « \(picked?.name ?? "") » ?",
                isPresented: Binding(
                    get: { picked != nil },
                    set: { if !$0 { picked = nil } }
                ),
                titleVisibility: .visible,
                presenting: picked
            ) { target in
                Button("Fusionner", role: .destructive) { Task { await merge(into: target) } }
                    .accessibilityIdentifier("choice-merge-series")
                Button("Annuler", role: .cancel) {}
            } message: { target in
                Text("Les \(ownedCount) livres de « \(seriesName) » passeront dans « \(target.name) », et « \(seriesName) » sera supprimée avec votre note.")
            }
            .overlay {
                if isMerging {
                    ZStack {
                        Color.black.opacity(0.1).ignoresSafeArea()
                        ProgressView()
                    }
                }
            }
            .disabled(isMerging)
            .alert(
                "Fusion impossible",
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
        .task { await load() }
    }

    /// The candidates the search keeps, the author's own sagas first.
    private var shown: [FollowedSeries] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        let kept = needle.isEmpty
            ? candidates
            : candidates.filter {
                $0.name.localizedStandardContains(needle)
                    || ($0.author?.localizedStandardContains(needle) ?? false)
            }
        guard let author else { return kept }
        let byAuthor = kept.filter { $0.author == author }
        return byAuthor + kept.filter { $0.author != author }
    }

    private func row(_ candidate: FollowedSeries) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                SagaName(name: candidate.name, isAudio: candidate.isAudio)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                if let author = candidate.author {
                    Text(author).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let language = candidate.language, language.isForeign {
                LanguageTag(language: language)
            }
            Text("\(candidate.ownedCount)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text("\(candidate.ownedCount) livres"))
        }
        .contentShape(Rectangle())
    }

    private func load() async {
        defer { isLoading = false }
        do {
            candidates = try await SeriesAPI.mergeCandidates().filter {
                $0.seriesId != seriesId && $0.isAudio == isAudio
            }
        } catch {
            errorMessage = reportError(error)
        }
    }

    private func merge(into target: FollowedSeries) async {
        isMerging = true
        defer { isMerging = false }
        if let message = await onMerge(target) {
            errorMessage = message
        } else {
            dismiss()
        }
    }
}

#Preview {
    MergeSeriesSheet(
        seriesId: "assassin-royal-french-edition--robin-hobb",
        seriesName: "L'Assassin royal (French Edition)",
        isAudio: false,
        author: "Robin Hobb",
        ownedCount: 2
    ) { _ in nil }
}
