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
