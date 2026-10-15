import SwiftUI

/// The friends' reading challenge: the reader and everyone they share with,
/// ranked on the books each finished since January 1st, and one line that says
/// where the reader stands — ahead by how much, level with whom, or how many
/// books from overtaking the friend just above.
///
/// Ties share a rank, and the reader is listed first among those they tie with:
/// it is their race being told.
struct ReadingChallenge {
    struct Entry: Identifiable {
        let id: String
        let name: String
        let count: Int
        let isMe: Bool
        /// One plus the number of readers strictly ahead.
        let rank: Int
    }

    /// How many rows the card draws, the reader's own added when further down.
    static let shown = 5

    let entries: [Entry]

    init(me: Friend, friends: [Friend]) {
        let everyone = [(me, true)] + friends.map { ($0, false) }
        let sorted = everyone.sorted { left, right in
            if left.0.readThisYear != right.0.readThisYear {
                return left.0.readThisYear > right.0.readThisYear
            }
            if left.1 != right.1 { return left.1 }
            return left.0.displayName.localizedCompare(right.0.displayName) == .orderedAscending
        }
        entries = sorted.map { friend, isMe in
            Entry(
                id: friend.userId,
                name: isMe ? String(localized: "Vous") : friend.displayName,
                count: friend.readThisYear,
                isMe: isMe,
                rank: 1 + sorted.filter { $0.0.readThisYear > friend.readThisYear }.count
            )
        }
    }

    var me: Entry? { entries.first(where: \.isMe) }

    /// The top of the ranking, and the reader's own row after it when they
    /// are further down.
    var visible: [Entry] {
        let top = Array(entries.prefix(Self.shown))
        guard let me, !top.contains(where: \.isMe) else { return top }
        return top + [me]
    }

    var best: Int { entries.map(\.count).max() ?? 0 }

    /// Where the reader stands, in one line, and the symbol that goes with it.
    var verdict: (text: String, symbol: String) {
        guard let me, best > 0 else {
            return (
                String(localized: "La course est ouverte : le premier livre terminé prend la tête."),
                "flag.checkered"
            )
        }
        let others = entries.filter { !$0.isMe }
        if me.rank == 1 {
            let level = others.filter { $0.count == me.count }
            if let first = level.first {
                return level.count == 1
                    ? (String(localized: "Coude à coude avec \(first.name) pour la première place !"), "equal.circle.fill")
                    : (String(localized: "Égalité en tête : \(level.count + 1) lecteurs se disputent la première place !"), "equal.circle.fill")
            }
            guard let second = others.first else {
                return (String(localized: "Seul en piste : invitez un ami à vous défier !"), "trophy.fill")
            }
            let lead = me.count - second.count
            return lead == 1
                ? (String(localized: "Vous menez la course, un livre devant \(second.name). Ne relâchez rien !"), "trophy.fill")
                : (String(localized: "Vous menez la course avec \(lead) livres d'avance sur \(second.name) !"), "trophy.fill")
        }
        // The friend just above: the smallest count still ahead of the reader.
        guard let ahead = others.filter({ $0.count > me.count }).min(by: { $0.count < $1.count }) else {
            return ("", "figure.run")
        }
        let needed = ahead.count - me.count + 1
        return needed == 1
            ? (String(localized: "Encore un livre et vous doublez \(ahead.name) !"), "figure.run")
            : (String(localized: "Encore \(needed) livres pour doubler \(ahead.name). À vos pages !"), "figure.run")
    }
}
