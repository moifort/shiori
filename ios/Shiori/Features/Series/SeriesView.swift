import SwiftUI

/// One saga's full catalogue. The volumes the reader owns, the ones they are
/// missing, and the ones not out yet — the only screen where the catalogue is
/// shown whole.
///
/// Everything unowned here is a proposal. Nothing enters the library until the
/// reader adds it, which is what keeps their list theirs.
struct SeriesView: View {
    let seriesId: String

    @State private var series: BookSeries?
    @State private var ownedByNumber: [Int: Book] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addingTitle: String?

    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView()
            } else if let series {
                catalogue(series)
            } else {
                ContentUnavailableView {
                    Label("Série non cataloguée", systemImage: "square.stack.3d.up.slash")
                } description: {
                    Text(errorMessage ?? "Cette série n'a pas encore de catalogue. Il est constitué au premier scan d'un de ses tomes.")
                }
            }
        }
        .navigationTitle(series?.name ?? "Série")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func catalogue(_ series: BookSeries) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(series.author).font(.subheadline).foregroundStyle(.secondary)
                    if let description = series.description {
                        Text(description).font(.callout)
                    }
                    stateBadge
                }
                .padding(.vertical, 4)
            }

            Section("Tomes") {
                ForEach(series.spine) { volume in row(volume, author: series.author) }
            }

            if !series.relatedWorks.isEmpty {
                Section {
                    ForEach(series.relatedWorks) { volume in row(volume, author: series.author) }
                } header: {
                    Text("Récits annexes")
                } footer: {
                    Text("Préquelles, nouvelles et hors-séries, en dehors de la numérotation.")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// In progress, or complete once every published volume has been read.
    /// Derived here from what is owned, exactly as the server derives it for the
    /// series tab — no counter, which is noise on a list whose point is the
    /// catalogue itself.
    private var stateBadge: some View {
        let published = (series?.spine ?? []).filter { !$0.isForthcoming(asOf: currentYear) }
        let allRead = !published.isEmpty && published.allSatisfy { volume in
            guard let number = volume.number else { return false }
            return ownedByNumber[number]?.status == .read
        }
        return Label(
            allRead ? "Terminée" : "En cours",
            systemImage: allRead ? "checkmark.circle.fill" : "book"
        )
        .font(.caption.weight(.medium))
        .foregroundStyle(allRead ? Color.green : .secondary)
    }

    private func row(_ volume: Volume, author: String) -> some View {
        let owned = volume.number.flatMap { ownedByNumber[$0] }
        let forthcoming = volume.isForthcoming(asOf: currentYear)

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(volume.title)
                    .font(.body.weight(owned != nil ? .medium : .regular))
                    .foregroundStyle(owned != nil ? .primary : .secondary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(volume.number.map { "\(volume.kind.label) \($0)" } ?? volume.kind.label)
                    if forthcoming, let year = volume.publishedIn {
                        Text("· à paraître en \(String(year))")
                    } else if let year = volume.publishedIn {
                        Text("· \(String(year))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let owned {
                    HStack(spacing: 8) {
                        Label(owned.status.label, systemImage: owned.status.symbol)
                            .font(.caption2)
                            .foregroundStyle(owned.status == .read ? Color.green : .secondary)
                        if let rating = owned.rating { StarRatingView(rating: rating) }
                    }
                }
            }
            Spacer(minLength: 0)

            if owned != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel(Text("Dans votre bibliothèque"))
            } else if forthcoming {
                // Nothing to add: the volume does not exist yet. Batch 4 will
                // attach an alert here rather than an action.
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Pas encore paru"))
            } else if addingTitle == volume.title {
                ProgressView()
            } else {
                Button { Task { await add(volume, author: author) } } label: {
                    Image(systemName: "plus.circle").font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel(Text("Ajouter « \(volume.title) » à ma liste à lire"))
            }
        }
        .padding(.vertical, 2)
    }

    private func load() async {
        isLoading = true
        do {
            series = try await SeriesAPI.series(id: seriesId)
            let mine = try await LibraryAPI.library()
            ownedByNumber = Dictionary(
                mine.filter { $0.seriesId == seriesId }
                    .flatMap(\.books)
                    .compactMap { book in book.series?.volume.map { ($0, book) } },
                uniquingKeysWith: { first, _ in first }
            )
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    private func add(_ volume: Volume, author: String) async {
        addingTitle = volume.title
        defer { addingTitle = nil }
        do {
            _ = try await BookAPI.add(BookDraft(title: volume.title, authors: [author]))
            track(.bookAdded(source: .series))
            await load()
        } catch {
            errorMessage = reportError(error)
        }
    }
}
