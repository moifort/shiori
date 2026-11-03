import Foundation

extension Wish {
    private static func cover(_ isbn: String) -> URL? {
        URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg")
    }

    static let previews: [Wish] = [
        Wish(
            id: "hyperion", title: "Hypérion", authors: ["Dan Simmons"], format: .book, language: .fr,
            seriesName: "Les Cantos d'Hypérion", volume: 1, coverURL: cover("9782266111560"),
            isbn13: "9782266111560", origin: .friend, originLabel: "Camille", friendId: "camille",
            wishedAt: .now.addingTimeInterval(-86400)
        ),
        Wish(
            id: "nom-du-vent", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], format: .book,
            language: .fr, seriesName: nil, volume: nil, coverURL: cover("9780756404741"),
            isbn13: "9782352943259", origin: .friend, originLabel: "Guillaume", friendId: "guillaume",
            wishedAt: .now.addingTimeInterval(-2 * 86400)
        ),
        Wish(
            id: "piranesi", title: "Piranesi", authors: ["Susanna Clarke"], format: .book, language: .en,
            seriesName: nil, volume: nil, coverURL: cover("9781526622426"), isbn13: "9781526622426",
            origin: .discovery, originLabel: nil, friendId: nil, wishedAt: .now.addingTimeInterval(-3 * 86400)
        ),
        Wish(
            id: "buffalo", title: "The Buffalo Hunter Hunter", authors: ["Stephen Graham Jones"],
            format: .book, language: .en, seriesName: nil, volume: nil, coverURL: cover("9781668057834"),
            isbn13: nil, origin: .award, originLabel: "Nebula", friendId: nil,
            wishedAt: .now.addingTimeInterval(-4 * 86400)
        ),
        Wish(
            id: "dune", title: "Dune", authors: ["Frank Herbert"], format: .book, language: .fr,
            seriesName: "Dune", volume: 1, coverURL: cover("9782266320481"), isbn13: nil,
            origin: .scan, originLabel: nil, friendId: nil, wishedAt: .now.addingTimeInterval(-5 * 86400)
        ),
    ]
}

extension Wishlist {
    static let preview = Wishlist(
        wishes: Wish.previews,
        awaited: [
            .preview,
            AwaitedEdition(
                id: "red-god", format: .book, state: .announced, title: "Red God",
                originalTitle: "Red God", originalLanguage: .en, authors: ["Pierce Brown"],
                date: "2026-12-18", coverURL: URL(string: "https://covers.openlibrary.org/b/isbn/9780425285961-L.jpg"),
                storeURL: nil, awaitedAt: .now, bookId: "red-rising", ownerId: "me"
            ),
            AwaitedEdition(
                id: "martian", format: .audiobook, state: .available, title: "Seul sur Mars",
                originalTitle: "The Martian", originalLanguage: .en, authors: ["Andy Weir"],
                date: "2026-10-28", coverURL: URL(string: "https://covers.openlibrary.org/b/isbn/9780553418026-L.jpg"),
                storeURL: nil, awaitedAt: .now, bookId: "martian", ownerId: "me"
            ),
            AwaitedEdition(
                id: "wind-and-truth", format: .book, state: .unannounced, title: "Wind and Truth",
                originalTitle: "Wind and Truth", originalLanguage: .en, authors: ["Brandon Sanderson"],
                date: nil, coverURL: URL(string: "https://covers.openlibrary.org/b/isbn/9781250319180-L.jpg"),
                storeURL: nil, awaitedAt: .now, bookId: "wind", ownerId: "me"
            ),
        ]
    )
}
