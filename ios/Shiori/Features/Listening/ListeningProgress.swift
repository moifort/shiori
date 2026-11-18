import Foundation

/// Where the listener stands in a recording, read against its chapters: the
/// numbers every view of the player draws, worked out once and tested apart
/// from any view.
struct ListeningProgress: Hashable, Sendable {
    let elapsed: TimeInterval
    let duration: TimeInterval
    let chapters: [ListeningChapter]

    /// The chapter playing, by its place in the list. Nil before the licence
    /// is in, or on a recording Audible gave no chapters.
    var chapterIndex: Int? {
        guard !chapters.isEmpty else { return nil }
        return chapters.lastIndex(where: { $0.start <= elapsed + 0.5 }) ?? 0
    }

    var chapter: ListeningChapter? { chapterIndex.map { chapters[$0] } }

    /// "Chapitre 12": the chapters are numbered by their place, as "sur 40"
    /// counts them, whatever Audible titles them.
    var chapterNumber: Int? { chapterIndex.map { $0 + 1 } }

    var chapterElapsed: TimeInterval {
        guard let chapter else { return elapsed }
        return min(max(0, elapsed - chapter.start), chapter.length)
    }

    var chapterRemaining: TimeInterval {
        guard let chapter else { return max(0, duration - elapsed) }
        return max(0, chapter.end - max(elapsed, chapter.start))
    }

    /// How far into the chapter, from 0 to 1: the bar of the full-screen player.
    var chapterFraction: Double {
        guard let chapter, chapter.length > 0 else {
            return duration > 0 ? min(1, elapsed / duration) : 0
        }
        return min(1, chapterElapsed / chapter.length)
    }

    var remaining: TimeInterval { max(0, duration - elapsed) }

    /// Whole percent of the recording heard.
    var percent: Int {
        guard duration > 0 else { return 0 }
        return min(100, Int((elapsed / duration * 100).rounded(.down)))
    }

    /// Where "previous chapter" goes: the start of this one, unless the
    /// listener is within its first seconds, as every player does.
    var previousChapterStart: TimeInterval {
        guard let index = chapterIndex else { return 0 }
        if chapterElapsed > 3 || index == 0 { return chapters[index].start }
        return chapters[index - 1].start
    }

    /// Where "next chapter" goes, or nil in the last one.
    var nextChapterStart: TimeInterval? {
        guard let index = chapterIndex, index + 1 < chapters.count else { return nil }
        return chapters[index + 1].start
    }
}

/// The player's time phrases, in the app's language.
enum ListeningText {
    /// "18:42", "1:02:05": a clock position, as the bar's labels draw it.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds).rounded(.down))
        let (hours, minutes, secs) = (total / 3600, total % 3600 / 60, total % 60)
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    /// "11h47 restantes", "47 min restantes".
    static func remaining(_ seconds: TimeInterval) -> String {
        let minutes = Int((max(0, seconds) / 60).rounded(.up))
        if minutes >= 60 {
            let hours = minutes / 60
            let rest = String(format: "%02d", minutes % 60)
            return String(localized: "\(hours)h\(rest) restantes")
        }
        return String(localized: "\(minutes) min restantes")
    }

    /// "Chapitre 12 · 11h47 restantes", the accessory's second line.
    static func accessoryLine(_ progress: ListeningProgress) -> String {
        let remaining = remaining(progress.remaining)
        guard let number = progress.chapterNumber else { return remaining }
        return String(localized: "Chapitre \(number) · \(remaining)")
    }

    /// "Chap. 12 · 11h47", the folded bar's second line: the time left with
    /// no word, which the bar has no room for.
    static func shortLine(_ progress: ListeningProgress) -> String {
        let minutes = Int((max(0, progress.remaining) / 60).rounded(.up))
        let left = minutes >= 60
            ? "\(minutes / 60)h\(String(format: "%02d", minutes % 60))"
            : String(localized: "\(minutes) min")
        guard let number = progress.chapterNumber else { return left }
        return String(localized: "Chap. \(number) · \(left)")
    }

    /// "Chapitre 12 sur 40".
    static func chapterOfCount(_ progress: ListeningProgress) -> String? {
        progress.chapterNumber.map {
            String(localized: "Chapitre \($0) sur \(progress.chapters.count)")
        }
    }

    /// "11h47 restantes · 46%".
    static func summary(_ progress: ListeningProgress) -> String {
        "\(remaining(progress.remaining)) · \(progress.percent)%"
    }
}
