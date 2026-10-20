import Foundation

/// One piece of an author's news on Découvrir: a work the web found, an
/// edition of theirs the reader awaits, or a volume of a saga of theirs the
/// Books shelf lists — drawn alike, the soonest to come or the newest out
/// first.
struct AuthorNewsItem: Identifiable {
    let id: String
    let title: String
    /// `YYYY`, `YYYY-MM` or `YYYY-MM-DD`.
    let date: String?
    let coverURL: URL?
    let isComing: Bool
    /// A recording: its cover carries the headphones.
    let isAudio: Bool
    /// What it was drawn from, for its cover to open it.
    let source: Source

    enum Source {
        case work(DiscoveredWork)
        case awaited(AwaitedEdition)
        case volume(DiscoveryVolume)
    }

    /// The same title announced in print and recorded is two items.
    init(work: DiscoveredWork, format: ReleaseFormat) {
        id = "work-\(format.rawValue)-\(work.id)"
        isAudio = format == .audiobook
        title = work.title
        date = work.date
        coverURL = work.coverURL
        isComing = work.date.map { ReleaseDateText.isUpcoming($0) } ?? true
        source = .work(work)
    }

    init(awaited: AwaitedEdition) {
        id = "awaited-\(awaited.id)"
        isAudio = awaited.format == .audiobook
        title = awaited.title
        date = awaited.date
        coverURL = awaited.coverURL
        isComing = awaited.state != .available
        source = .awaited(awaited)
    }

    init(volume: DiscoveryVolume, isComing: Bool) {
        id = "volume-\(volume.id)"
        isAudio = volume.saga.series.isAudio
        title = volume.volume.title
        date = volume.volume.date
        coverURL = volume.volume.coverURL
        self.isComing = isComing
        source = .volume(volume)
    }

    /// The works, editions awaited and saga volumes of one section of the
    /// shelf, in its order: the soonest first while announced, the undated
    /// last; the newest first once out.
    static func ordered(
        works: [(work: DiscoveredWork, format: ReleaseFormat)],
        awaited: [AwaitedEdition],
        volumes: [DiscoveryVolume] = [],
        section: SagaReleasesSummary.Section
    ) -> [AuthorNewsItem] {
        let items = works.map { AuthorNewsItem(work: $0.work, format: $0.format) }
            + awaited.map(AuthorNewsItem.init(awaited:))
            + volumes.map { AuthorNewsItem(volume: $0, isComing: section == .upcoming) }
        let day = { (item: AuthorNewsItem) in item.date.map(ReleaseDateText.lastDay) }
        switch section {
        case .upcoming:
            return items.sorted { lhs, rhs in
                guard let left = day(lhs) else { return false }
                guard let right = day(rhs) else { return true }
                return left < right
            }
        case .recent:
            return items.sorted { (day($0) ?? "") > (day($1) ?? "") }
        }
    }
}
