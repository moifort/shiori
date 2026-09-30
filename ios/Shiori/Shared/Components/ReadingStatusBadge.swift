import SwiftUI

/// The reading status pinned to a cover's corner. Icon-only, because a 56-point
/// cover leaves no room for a word; the colour carries the state at a glance and
/// the symbol keeps it distinguishable without colour.
struct ReadingStatusBadge: View {
    let status: ReadingStatus

    var body: some View {
        CoverBadge(systemImage: status.symbol, tint: status.tint)
    }
}

/// A disc pinned to a cover's corner: the reading status on a volume held, and
/// on a volume the reader lacks, whether it can be added now or comes out
/// later — one shape, so the eye reads every corner of a strip the same way.
struct CoverBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.white)
            // Wider than the glyph needs, so the symbol sits in the disc with
            // air around it rather than filling it to the rim.
            .frame(width: 18, height: 18)
            .background(tint, in: Circle())
            // A ring in the row's own background lifts the badge off whatever
            // colour the cover happens to be under it.
            .overlay(Circle().strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

extension ReadingStatus {
    /// The colour a status is drawn in — the badge on a cover, the tag on a
    /// library row — so the eye learns one hue per state.
    var tint: Color {
        switch self {
        case .toRead: .orange
        case .reading: .blue
        case .read: .green
        case .dropped: .red
        }
    }

    /// The status as a shelf of the library names it — the filter, a row's
    /// tag — in the picker's own words, so a book said "Lu" on its page is
    /// found under "Lu".
    var shelfTitle: String {
        switch self {
        case .toRead: String(localized: "À lire")
        case .reading: String(localized: "En cours")
        case .read: String(localized: "Lu")
        case .dropped: String(localized: "Abandonné")
        }
    }
}
