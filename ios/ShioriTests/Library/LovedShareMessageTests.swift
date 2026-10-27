import Foundation
import Testing
@testable import Shiori

private func book(
    _ title: String,
    by author: String,
    _ genre: BookGenre?,
    _ format: BookFormat = .book,
    series: String? = nil,
    volume: Int? = nil
) -> Book {
    var book = Book(id: title, title: title, authors: [author], status: .read)
    book.genre = genre
    book.format = format
    book.series = series.map { SeriesMembership(id: $0, name: $0, volume: volume, kind: .main) }
    return book
}

struct LovedShareMessageTests {
    @Test func aSagaIsOneLineWhateverTheNumberOfItsVolumesLoved() {
        let text = LovedShareMessage.text(
            books: [
                book("Dune", by: "Frank Herbert", .scienceFiction, series: "Dune", volume: 1),
                book("Le Messie de Dune", by: "Frank Herbert", .scienceFiction, series: "Dune", volume: 2),
            ],
            series: []
        )

        #expect(text == """
        Mes coups de cœur 📚

        *Science-fiction*
        • Dune (série) — Frank Herbert
        """)
    }

    @Test func cutByGenreThenFormatSagasBeforeBooksAlone() {
        let text = LovedShareMessage.text(
            books: [
                book("Le Nom du vent", by: "Patrick Rothfuss", .fantasy),
                book("One Piece 1", by: "Eiichirō Oda", .adventure, .manga, series: "One Piece", volume: 1),
                book("Les Furtifs", by: "Alain Damasio", .scienceFiction),
                book("Projet Dernière Chance", by: "Andy Weir", .scienceFiction, .audiobook),
                book("Carnets", by: "Anonyme", nil),
            ],
            series: [
                FollowedSeries(
                    seriesId: "stormlight", name: "Les Archives de Roshar", author: "Brandon Sanderson",
                    language: .fr, state: .inProgress, genre: .fantasy, ownedCount: 4
                ),
            ]
        )

        #expect(text == """
        Mes coups de cœur 📚

        *Aventure*
        _Manga_
        • One Piece (série) — Eiichirō Oda

        *Fantastique*
        • Les Archives de Roshar (série) — Brandon Sanderson
        • Le Nom du vent — Patrick Rothfuss

        *Science-fiction*
        • Les Furtifs — Alain Damasio
        • Projet Dernière Chance — Andy Weir

        *Autre*
        • Carnets — Anonyme
        """)
    }

    @Test func aHeartedSagaAndItsLovedVolumesAreOneLine() {
        let text = LovedShareMessage.text(
            books: [book("La Voie des rois", by: "Brandon Sanderson", .fantasy, series: "Les Archives de Roshar", volume: 1)],
            series: [
                FollowedSeries(
                    seriesId: "stormlight", name: "Les Archives de Roshar", author: "Brandon Sanderson",
                    language: .fr, state: .inProgress, genre: .fantasy, ownedCount: 4
                ),
            ]
        )

        #expect(text.components(separatedBy: "Roshar").count == 2)
    }

    @Test func aRecordingAndAnEbookSitAmongTheBooks() {
        var ebook = book("Le Nom du vent", by: "Patrick Rothfuss", .fantasy, series: "Chronique du tueur de roi", volume: 1)
        ebook.media = [.digital]
        let text = LovedShareMessage.text(
            books: [
                ebook,
                book("La Peur du sage", by: "Patrick Rothfuss", .fantasy, .audiobook, series: "Chronique du tueur de roi", volume: 2),
                book("Elantris", by: "Brandon Sanderson", .fantasy, .audiobook),
            ],
            series: []
        )

        #expect(text == """
        Mes coups de cœur 📚

        *Fantastique*
        • Chronique du tueur de roi (série) — Patrick Rothfuss
        • Elantris — Brandon Sanderson
        """)
    }
}
