import Foundation

/// The form both sides of the search agree on: lowercase, accents gone,
/// punctuation turned to spaces. "L'Assassin royal" and "l assassin royal"
/// meet, as "Ève" and "eve" do. The rule is Vinarium's `normalizedForSearch`.
enum SearchText {
    static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let spaced = folded.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(spaced).split(separator: " ").joined(separator: " ")
    }

    /// The words of a text, normalized, as the matcher compares them.
    static func words(_ text: String) -> [SearchWord] {
        normalized(text).split(separator: " ").map { SearchWord(String($0)) }
    }
}

/// One normalized word, kept as scalars too: the matcher compares thousands of
/// them per keystroke, and indexing a `String` by character is what is slow.
struct SearchWord: Hashable, Sendable {
    let text: String
    let scalars: [Unicode.Scalar]

    init(_ text: String) {
        self.text = text
        scalars = Array(text.unicodeScalars)
    }
}

/// A book as the search reads it, its words normalized once when the index
/// loads rather than at every keystroke.
struct SearchEntry: Identifiable, Sendable {
    let book: Book
    let titleWords: [SearchWord]
    /// Its authors' and its saga's words: what finds it when the title does not.
    let otherWords: [SearchWord]
    /// What finds its saga: the saga's name and the authors.
    let seriesWords: [SearchWord]

    var id: String { book.id }

    init(book: Book) {
        self.book = book
        titleWords = SearchText.words(book.title)
        let authorWords = book.authors.flatMap(SearchText.words)
        let sagaWords = book.series.map { SearchText.words($0.name) } ?? []
        otherWords = authorWords + sagaWords
        seriesWords = sagaWords + authorWords
    }
}

/// What the chips under the field keep: the favourites, one status, or both.
struct SearchFilter: Hashable, Sendable {
    var favorites = false
    /// En cours, À lire or Lus; never the dropped books, which the search leaves
    /// to the Library tab's own filter.
    var status: ReadingStatus?

    static let statuses: [ReadingStatus] = [.reading, .toRead, .read]

    var isActive: Bool { favorites || status != nil }

    func keeps(_ book: Book) -> Bool {
        (!favorites || book.favorite) && (status == nil || book.status == status)
    }
}

/// A saga found by its name or its authors, with the volumes the reader holds.
struct SeriesHit: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let authors: [String]
    /// The volumes held that the filter keeps, in tome order.
    let books: [Book]
}

/// What the screen draws for a query.
struct SearchResults: Equatable, Sendable {
    var series: [SeriesHit] = []
    var books: [Book] = []
    /// Books matching the query that the filter hides: what the empty state
    /// offers to show by clearing it.
    var hiddenByFilter = 0

    static let empty = SearchResults()
}

enum LibrarySearchMatcher {
    /// Sagas shown above the books, at most.
    static let maxSeries = 3
    /// Below this length a word must be typed right: one letter off in a
    /// three-letter word matches far too much.
    static let shortestForgiven = 4

    static func results(for query: String, in entries: [SearchEntry], filter: SearchFilter) -> SearchResults {
        let words = SearchText.words(query)
        guard !words.isEmpty else {
            guard filter.isActive else { return .empty }
            let kept = entries.map(\.book).filter(filter.keeps)
            return SearchResults(books: kept.sorted(by: newestOnShelfFirst))
        }

        var matches: [(entry: SearchEntry, score: Score)] = []
        var hidden = 0
        var memo = Memo(count: words.count)
        for entry in entries {
            guard let score = score(of: entry, for: words, memo: &memo) else { continue }
            if filter.keeps(entry.book) { matches.append((entry, score)) } else { hidden += 1 }
        }
        matches.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score < rhs.score }
            return inSagaOrder(lhs.entry.book, rhs.entry.book)
        }
        return SearchResults(
            series: seriesHits(for: words, in: entries, filter: filter, memo: &memo),
            books: matches.map(\.entry.book),
            hiddenByFilter: hidden
        )
    }

    /// Whether a word of the book's title matches one of the query's: what the
    /// row highlights.
    static func highlights(_ titleWord: String, for query: String) -> Bool {
        let candidate = SearchWord(SearchText.normalized(titleWord))
        guard !candidate.text.isEmpty else { return false }
        return SearchText.words(query).contains { quality(of: $0, against: candidate) != nil }
    }

    // MARK: - Scoring

    /// Lower is better: fewer forgiven letters first, then a book found by its
    /// title before one found only by its author or saga.
    struct Score: Comparable {
        let edits: Int
        let outsideTitle: Int

        static func < (lhs: Score, rhs: Score) -> Bool {
            (lhs.edits, lhs.outsideTitle) < (rhs.edits, rhs.outsideTitle)
        }
    }

    /// What each query word made of each library word already met: a library
    /// says the same words over and over — its authors, its sagas, "le", "tome" —
    /// and the edit distance is the costly part.
    struct Memo {
        private var known: [[String: Int]]

        init(count: Int) {
            known = Array(repeating: [:], count: count)
        }

        /// -1 records a miss.
        mutating func quality(_ position: Int, _ word: SearchWord, _ candidate: SearchWord) -> Int? {
            if let seen = known[position][candidate.text] { return seen < 0 ? nil : seen }
            let found = LibrarySearchMatcher.quality(of: word, against: candidate)
            known[position][candidate.text] = found ?? -1
            return found
        }
    }

    private static func score(of entry: SearchEntry, for words: [SearchWord], memo: inout Memo) -> Score? {
        var edits = 0
        var outsideTitle = 0
        for (position, word) in words.enumerated() {
            if let edit = best(position, word, in: entry.titleWords, memo: &memo) {
                edits += edit
            } else if let edit = best(position, word, in: entry.otherWords, memo: &memo) {
                edits += edit
                outsideTitle += 1
            } else if let volume = Int(word.text), entry.book.series?.volume == volume {
                outsideTitle += 1
            } else {
                return nil
            }
        }
        return Score(edits: edits, outsideTitle: outsideTitle)
    }

    private static func best(_ position: Int, _ word: SearchWord, in candidates: [SearchWord], memo: inout Memo) -> Int? {
        var best: Int?
        for candidate in candidates {
            guard let edit = memo.quality(position, word, candidate) else { continue }
            if edit == 0 { return 0 }
            best = edit
        }
        return best
    }

    /// 0 when the book's word starts with the query's, 1 when one letter is off,
    /// nil when they do not meet.
    fileprivate static func quality(of word: SearchWord, against candidate: SearchWord) -> Int? {
        let typed = word.scalars
        let held = candidate.scalars
        if held.count >= typed.count, held[..<typed.count].elementsEqual(typed) { return 0 }
        guard typed.count >= shortestForgiven else { return nil }
        if isOneEditAway(typed[...], held[...]) { return 1 }
        // Still being typed: "crawlr" against the start of "crawler".
        if held.count > typed.count, isOneEditAway(typed[...], held[..<typed.count]) { return 1 }
        return nil
    }

    /// One insertion, deletion or substitution apart, and not equal.
    private static func isOneEditAway(_ lhs: ArraySlice<Unicode.Scalar>, _ rhs: ArraySlice<Unicode.Scalar>) -> Bool {
        let (short, long) = lhs.count <= rhs.count ? (lhs, rhs) : (rhs, lhs)
        guard long.count - short.count <= 1 else { return false }
        var shortIndex = short.startIndex
        var longIndex = long.startIndex
        var edited = false
        while shortIndex < short.endIndex, longIndex < long.endIndex {
            if short[shortIndex] == long[longIndex] {
                shortIndex += 1
                longIndex += 1
                continue
            }
            if edited { return false }
            edited = true
            if short.count == long.count { shortIndex += 1 }
            longIndex += 1
        }
        return edited || long.count != short.count
    }

    // MARK: - Sagas

    private static func seriesHits(
        for words: [SearchWord], in entries: [SearchEntry], filter: SearchFilter, memo: inout Memo
    ) -> [SeriesHit] {
        var bySaga: [String: [SearchEntry]] = [:]
        for entry in entries {
            guard let series = entry.book.series else { continue }
            bySaga[series.id, default: []].append(entry)
        }
        var hits: [(hit: SeriesHit, edits: Int)] = []
        for (id, volumes) in bySaga {
            guard let first = volumes.first, let name = first.book.series?.name else { continue }
            let total = words.enumerated().map { best($0.offset, $0.element, in: first.seriesWords, memo: &memo) }
            guard total.allSatisfy({ $0 != nil }) else { continue }
            let kept = volumes.map(\.book).filter(filter.keeps).sorted(by: inSagaOrder)
            guard !kept.isEmpty else { continue }
            let hit = SeriesHit(id: id, name: name, authors: first.book.authors, books: kept)
            hits.append((hit, total.compactMap { $0 }.reduce(0, +)))
        }
        return hits
            .sorted { $0.edits != $1.edits ? $0.edits < $1.edits : $0.hit.name < $1.hit.name }
            .prefix(maxSeries)
            .map(\.hit)
    }

    // MARK: - Orders

    private static func inSagaOrder(_ lhs: Book, _ rhs: Book) -> Bool {
        let left = (lhs.series?.name ?? "", lhs.series?.volume ?? .max, lhs.title)
        let right = (rhs.series?.name ?? "", rhs.series?.volume ?? .max, rhs.title)
        return left < right
    }

    private static func newestOnShelfFirst(_ lhs: Book, _ rhs: Book) -> Bool {
        (lhs.shelvedAt ?? .distantPast) > (rhs.shelvedAt ?? .distantPast)
    }
}
