import Foundation

// The authors' screens' preview and test data.

extension FollowedAuthor {
    static let preview = FollowedAuthor(
        key: "robin hobb",
        name: "Robin Hobb",
        indexLetter: "H",
        bookCount: 4,
        seriesCount: 1,
        favoriteCount: 1,
        averageRating: 4.5,
        shelvedAt: .now.addingTimeInterval(-86400 * 3),
        books: [.preview]
    )

    static let previews: [FollowedAuthor] = [
        .preview,
        FollowedAuthor(
            key: "ursula k le guin",
            name: "Ursula K. Le Guin",
            indexLetter: "L",
            bookCount: 2,
            seriesCount: 0,
            favoriteCount: 0,
            averageRating: nil,
            shelvedAt: .now.addingTimeInterval(-86400 * 40),
            books: []
        ),
    ]
}

extension AuthorPage {
    static let preview = AuthorPage(
        author: .preview,
        readCount: 3,
        nationality: "Américaine",
        birthYear: 1952,
        deathYear: nil,
        biography: "Autrice de fantasy, connue pour les cycles de l'Assassin royal et des Aventuriers de la mer.",
        sagas: [],
        printSagasNotHeld: [
            AuthorSeries(
                id: "les-aventuriers-de-la-mer--robin-hobb",
                name: "Les Aventuriers de la mer",
                author: "Robin Hobb",
                volumeCount: 9,
                firstVolumeTitle: "Le Vaisseau magique",
                coverURL: nil
            ),
        ],
        books: [.preview],
        booksNotHeld: [AuthorWork(title: "Le Prince bâtard", publishedIn: 2013, coverURL: nil)]
    )
}

extension AuthorsClient {
    /// Answers from the fixtures and accepts every write.
    static let preview = AuthorsClient(
        page: { _, _ in .preview },
        catalogue: { _, _ in .preview },
        releases: { _ in [:] },
        refresh: { _ in true },
        stopAwaiting: { _ in },
        addBook: { _, _ in .preview },
        list: { limit, after, _ in
            CursorPage(FollowedAuthor.previews, limit: limit, after: after, cursor: \.id)
        }
    )
}
