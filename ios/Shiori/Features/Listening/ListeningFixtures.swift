import Foundation

extension ListeningTitle {
    static let preview = ListeningTitle(
        asin: "B077PLB5KD",
        title: "Endymion",
        subtitle: "Les Cantos d'Hypérion · Tome 3",
        coverURL: URL(string: "https://m.media-amazon.com/images/I/514Pw3mZUQL._SL500_.jpg")
    )
}

extension Playback {
    /// Endymion, 21 h 49 long, 40 chapters, the reader 18:42 into the twelfth:
    /// 11 h 47 left, 46 % heard — the figures the board draws.
    static let preview: Playback = {
        let opening = (0..<11).map { ListeningChapter(title: "Chapitre \($0 + 1)", start: TimeInterval($0) * 3183, length: 3183) }
        let twelfth = ListeningChapter(title: "Chapitre 12", start: 35013, length: 1678)
        let closing = (0..<28).map {
            ListeningChapter(title: "Chapitre \($0 + 13)", start: 36691 + TimeInterval($0) * 1494.96, length: 1494.96)
        }
        return Playback(
            asin: "B077PLB5KD",
            contentReference: "preview",
            streamURL: URL(string: "https://example.com/preview.m3u8")!,
            certificate: Data(),
            duration: 78550,
            chapters: opening + [twelfth] + closing,
            resumeAt: 36135
        )
    }()
}

extension ListeningProgress {
    static let preview = ListeningProgress(
        elapsed: Playback.preview.resumeAt ?? 0,
        duration: Playback.preview.duration,
        chapters: Playback.preview.chapters
    )
}

extension ListeningQueueEntry {
    /// What follows Endymion on the board: one recording under way, then the pile.
    static let previews: [ListeningQueueEntry] = [
        entry("seul-sur-mars", "Seul sur Mars", "Andy Weir", isbn: "9780553418026", heard: 32),
        entry("eveil-endymion", "L'Éveil d'Endymion", "Les Cantos d'Hypérion · Tome 4", isbn: "9780553572988"),
        entry("projet-derniere-chance", "Projet Dernière Chance", "Andy Weir", isbn: "9780593135204"),
        entry("nom-du-vent", "Le Nom du vent", "Chronique du tueur de roi · Tome 1", isbn: "9780756404741"),
        entry("assasynth", "Journal d'un AssaSynth", "Martha Wells", isbn: "9780765397539"),
        entry("trois-corps", "Le Problème à trois corps", "Le Problème à trois corps · Tome 1", isbn: "9780765382030"),
    ]

    private static func entry(
        _ asin: String, _ title: String, _ subtitle: String, isbn: String, heard: Int? = nil
    ) -> ListeningQueueEntry {
        ListeningQueueEntry(
            title: ListeningTitle(
                asin: asin,
                title: title,
                subtitle: subtitle,
                coverURL: URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-L.jpg")
            ),
            heard: heard
        )
    }
}
