import SwiftUI

/// The saga of a book the reader does not hold — an edition awaited, an award
/// winner, a suggestion, a wish — as its page draws it under the summary, the
/// way a book's page draws its own: the saga's row, this book ringed in its
/// place, the volumes held opening their page, the ones lacking their
/// announced page, the name the saga's screen.
///
/// The saga is the one the server names on the release, in the edition shown,
/// or the one of the reader's copy when the page has one. The row reads a
/// catalogue already built and never builds one: for a saga nobody catalogued
/// it draws this book alone, and the saga's screen, asked with the saga's name
/// and author, builds the catalogue on first sight — the one model call, paid
/// once for every reader.
@MainActor
@Observable
final class ReleaseSaga {
    init(sagaVolumes: @escaping @Sendable (String, BookLanguage?) async throws -> [SeriesStripItem]) {
        self.sagaVolumes = sagaVolumes
    }

    private let sagaVolumes: @Sendable (String, BookLanguage?) async throws -> [SeriesStripItem]

    /// The saga drawn, nil until read and for a book on its own.
    private(set) var series: SeriesMembership?
    /// Its volumes in order, this book in its own place.
    private(set) var volumes: [SeriesStripItem] = []
    /// The cover ringed: this book, or the reader's own copy of it.
    private(set) var currentId = ""
    /// The book the saga is read from, for the page of a volume it lacks.
    private var holder: Book?
    /// This book, when drawn in the row though the reader does not hold it.
    private var placedId: String?

    var name: String? { series?.name }

    /// The saga's screen, asked with the saga's name and author: what builds
    /// its catalogue when nobody has yet.
    var destination: SeriesDestination? {
        guard let series else { return nil }
        let proposal = holder?.authors.first.map { SeriesProposal(name: series.name, author: $0) }
        return SeriesDestination(seriesId: series.id, proposal: proposal)
    }

    /// The saga, as the page of a volume of it the reader lacks reads it.
    var discovery: SagaDiscovery? {
        guard let holder, let series else { return nil }
        let owned = volumes.count { if case let .owned(book) = $0 { book.id != placedId } else { false } }
        return SagaDiscovery(holding: holder, in: series, ownedCount: owned)
    }

    /// The saga of `shown`, or of `copy` — the reader's own book it is an
    /// edition of — when there is one. Read again only when the saga changes,
    /// as a description names it. Nothing when the saga cannot be read: the
    /// page stands whole without it.
    func load(shown: Book, copy: Book? = nil) async {
        let held = copy?.series != nil ? copy : nil
        guard let series = held?.series ?? shown.series, series.id != self.series?.id else { return }
        let edition = held?.language ?? series.editionLanguage ?? shown.language
        guard let read = try? await sagaVolumes(series.id, edition) else { return }
        var holder = held ?? shown
        holder.language = edition
        let row = held.map { (volumes: read, currentId: $0.id) } ?? Self.row(read, placing: shown)
        withAnimation(.snappy) {
            self.series = series
            self.holder = holder
            volumes = row.volumes
            currentId = row.currentId
            placedId = held == nil ? shown.id : nil
        }
    }

    /// The row with `book` drawn in its own place, its cover bright and
    /// ringed, rather than as the volume it lacks; the reader's own copy of
    /// that volume ringed instead when they hold one; slipped in at its number
    /// when the catalogue does not list it. Alone in the row when no catalogue
    /// lists the saga yet.
    static func row(_ read: [SeriesStripItem], placing book: Book) -> (volumes: [SeriesStripItem], currentId: String) {
        guard !read.isEmpty else { return ([.owned(book)], book.id) }
        guard let number = book.series?.volume else { return (read, book.id) }
        for item in read {
            if case let .owned(held) = item, held.series?.volume == number { return (read, held.id) }
        }
        let numberOf: (SeriesStripItem) -> Int? = { item in
            switch item {
            case let .owned(held): held.series?.volume
            case let .missing(_, itemNumber, _, _, _, _): itemNumber
            }
        }
        var placed = read
        if let at = placed.firstIndex(where: { numberOf($0) == number }) {
            placed[at] = .owned(book)
        } else {
            // A volume the catalogue does not list yet still has its place.
            let at = placed.firstIndex { (numberOf($0) ?? .max) > number } ?? placed.endIndex
            placed.insert(.owned(book), at: at)
        }
        return (placed, book.id)
    }
}

extension SeriesMembership {
    /// The edition's language, as the server writes it at the end of the id:
    /// `{saga}~{language}`.
    var editionLanguage: BookLanguage? {
        guard let at = id.lastIndex(of: "~") else { return nil }
        return BookLanguage(rawValue: String(id[id.index(after: at)...]))
    }
}

/// Where a release's saga row leads.
enum ReleaseSagaDestination: Hashable, Identifiable {
    /// A volume the reader holds: its own page.
    case volume(Book)
    /// A volume the reader lacks: its announced page.
    case lacking(DiscoveredVolume)
    /// The saga's screen.
    case saga(SeriesDestination)

    var id: Self { self }
}

extension View {
    /// The pages a release's saga row opens, pushed over the release's page.
    func releaseSagaDestinations(_ item: Binding<ReleaseSagaDestination?>, saga: ReleaseSaga) -> some View {
        navigationDestination(item: item) { destination in
            switch destination {
            case let .volume(book):
                BookScreen(bookId: book.id)
                    .closesAsPushed()
            case let .lacking(volume):
                if let discovery = saga.discovery {
                    AnnouncedVolumeScreen(saga: discovery, volume: volume)
                        .closesAsPushed()
                }
            case let .saga(destination):
                SeriesScreen(seriesId: destination.seriesId, proposal: destination.proposal)
                    .closesAsPushed()
            }
        }
    }
}
