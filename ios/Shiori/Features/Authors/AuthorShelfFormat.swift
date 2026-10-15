import SwiftUI

/// The two ways the reader holds a book, as the author's page tells them apart:
/// on paper or a screen, and as a recording. Releases come out on different days
/// in each, and a reader who listens to an author does not own them in print.
enum AuthorShelfFormat: String, CaseIterable, Identifiable {
    case print, audio
    var id: String { rawValue }

    var label: String {
        switch self {
        case .print: String(localized: "Livre")
        case .audio: String(localized: "Audio")
        }
    }

    var symbol: String {
        switch self {
        case .print: "book.closed"
        case .audio: "headphones"
        }
    }

    func holds(_ book: Book) -> Bool {
        (book.format == .audiobook) == (self == .audio)
    }

    /// What a book added from the page is catalogued as.
    var bookFormat: BookFormat { self == .audio ? .audiobook : .book }

    /// The format Découvrir watches the author in.
    var releaseFormat: ReleaseFormat { self == .audio ? .audiobook : .book }
}
