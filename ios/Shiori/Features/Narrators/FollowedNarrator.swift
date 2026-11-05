import Foundation

/// A narrator as the Library's narrators list draws them, as an author's row
/// is drawn: their face and name, then the recordings in their voice.
struct FollowedNarrator: Identifiable, Codable, Sendable, ShelvedPerson {
    let key: String
    var id: String { key }
    /// The spelling most of the reader's recordings use.
    let name: String
    /// The letter of the alphabet index they are filed under, as an author is —
    /// their surname's, Le Ridant under L — or "#". Filed by the server, which
    /// orders the alphabetical list on the same rule.
    let indexLetter: String
    /// Their photograph, once somebody opened their page and found one.
    var portraitURL: URL?
    /// The date their newest recording is shelved on.
    let shelvedAt: Date?
    /// Their recordings, newest shelved first, each with its cover and status.
    let books: [Book]
    /// The reader hearted the narrator themself.
    var favorite = false
    /// Their surname as the name writes it, set in bold in the A to Z list.
    var surname: String?

    /// The first letter of the first and last words, as an author's.
    var initials: String {
        let words = name.split(separator: " ")
        let ends = words.count > 1 ? [words.first, words.last] : [words.first]
        return ends.compactMap { $0?.first }.map(String.init).joined().uppercased()
    }
}

extension FollowedNarrator {
    static let previews: [FollowedNarrator] = [
        FollowedNarrator(key: "bernard-gabay", name: "Bernard Gabay", indexLetter: "G", shelvedAt: .now, books: [.preview], surname: "Gabay"),
        FollowedNarrator(key: "frederic-kneip", name: "Frédéric Kneip", indexLetter: "K", shelvedAt: .now, books: [.preview], surname: "Kneip"),
    ]
}
