import Foundation

/// A volume of the scanned book's saga the reader lacks and may add at once:
/// out already in the edition reviewed, at its number on the spine.
struct LackingVolume: Equatable, Sendable {
    let number: Int
    let title: String
    let coverURL: URL?
}

extension [SeriesStripItem] {
    /// What "Ajouter la série" adds beside the scanned volume: every volume of
    /// the spine that is out already, once each, in order. Nothing once the
    /// reader holds a volume of the saga: it is in their library already, and
    /// its page is where it is completed. An announced one is left to the
    /// release watch, which says when it comes out; an unnumbered work is not
    /// a volume of the cycle.
    func volumesToComplete(besides scanned: Int?) -> [LackingVolume] {
        guard !contains(where: { if case .owned = $0 { true } else { false } }) else { return [] }
        var seen = Set<Int>()
        return compactMap { item -> LackingVolume? in
            guard case let .missing(_, number?, title, forthcoming, _, coverURL) = item,
                  !forthcoming, number != scanned, seen.insert(number).inserted
            else { return nil }
            return LackingVolume(number: number, title: title, coverURL: coverURL)
        }
        .sorted { $0.number < $1.number }
    }
}

extension BookDraft {
    /// A lacking volume as the scanned book's sibling: its author, format,
    /// medium and edition, filed under the same saga at its number, with the
    /// catalogue's title and cover. Added bare, never looked up: the
    /// catalogue already knows it, and a lookup per volume would spend a scan.
    func sibling(_ volume: LackingVolume) -> BookDraft? {
        guard let series else { return nil }
        var draft = BookDraft(title: volume.title, authors: authors, format: format, media: media)
        draft.language = language
        draft.coverURL = volume.coverURL
        draft.series = SeriesMembership(id: series.id, name: series.name, volume: volume.number, kind: .main)
        draft.status = .toRead
        draft.origin = origin
        return draft
    }
}
