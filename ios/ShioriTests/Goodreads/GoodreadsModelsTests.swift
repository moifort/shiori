import Foundation
import Testing
@testable import Shiori

private let preview = GoodreadsPreview.preview

@Suite("The Goodreads choices")
struct GoodreadsChoicesTests {
    @Test("tick every new and held row, and leave the uncertain to the reader")
    func ticksNewAndHeld() {
        let choices = GoodreadsChoices(preview: preview)

        #expect(choices.keys.contains("red-rising"))
        #expect(choices.keys.contains("nom-du-vent"))
        #expect(!choices.keys.contains("sorceleur"))
    }

    @Test("count only what the import writes: neither the held nor the same books")
    func countsWhatIsWritten() {
        var choices = GoodreadsChoices(preview: preview)
        let written = preview.newRows.count
        #expect(choices.importedCount(in: preview) == written)

        choices.keys.insert("sorceleur")
        choices.sameBooks.insert("sorceleur")
        #expect(choices.importedCount(in: preview) == written)

        choices.sameBooks.remove("sorceleur")
        #expect(choices.importedCount(in: preview) == written + 1)
    }
}

@Suite("A Goodreads row")
struct GoodreadsRowTests {
    private func row(_ key: String) -> GoodreadsRow {
        preview.rows.first { $0.key == key }!
    }

    @Test("lands on the wishlist or the pile as the reader chose, a given-up book dropped")
    func landsWhereChosen() {
        #expect(row("fondation").status(toRead: .wishlist) == nil)
        #expect(row("fondation").status(toRead: .pile) == .toRead)
        #expect(row("trois-corps").status(toRead: .wishlist) == .dropped)
        #expect(row("morning-star").status(toRead: .wishlist) == .reading)
        #expect(row("fondation").caption(toRead: .wishlist) == String(localized: "Envie"))
    }
}
