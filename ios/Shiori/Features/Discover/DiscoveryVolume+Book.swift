import Foundation

/// An announced volume drawn as a book, and what adding it sends.
extension DiscoveryVolume {
    /// Under its cover: the day it comes or came out, or that it is announced.
    var caption: String {
        volume.date.map(ReleaseDateText.short) ?? String(localized: "Annoncé")
    }

    /// Drawn as the Books tab draws a book, the headphones on a recording's
    /// cover: on its tile and on its page alike.
    var cover: Book { book(of: volume.release) }

    /// The volume as its page draws it, until its page described it.
    var book: Book { book(of: volume.release) }

    /// A release of this volume as drawn: the list's, or the server's answer
    /// once its page described it.
    func book(of release: Release) -> Book {
        release.book(id: "release-\(saga.series.id)-\(volume.number)")
    }

    /// What adding it to the pile sends: the page as shown, described or
    /// not, filed in its saga at its number, under the description's genre
    /// else the saga's.
    func draft(from shown: Book) -> BookDraft {
        var draft = BookDraft(title: shown.title, authors: shown.authors)
        draft.format = shown.format
        draft.genre = shown.genre ?? saga.series.genre
        draft.subgenres = shown.subgenres
        draft.synopsis = shown.synopsis
        draft.publisher = shown.publisher
        draft.firstPublishedIn = shown.firstPublishedIn
        draft.pageCount = shown.pageCount
        draft.isbn13 = shown.isbn13
        draft.language = saga.series.language
        draft.series = shown.series
        draft.coverURL = shown.coverURL
        draft.status = .toRead
        return draft
    }
}
