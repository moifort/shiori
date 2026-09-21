import SwiftUI

/// The reading status pinned to a cover's corner. Icon-only, because a 56-point
/// cover leaves no room for a word; the colour carries the state at a glance and
/// the symbol keeps it distinguishable without colour.
struct ReadingStatusBadge: View {
    let status: ReadingStatus

    private var tint: Color {
        switch status {
        case .toRead: .gray
        case .reading: .blue
        case .read: .green
        }
    }

    var body: some View {
        Image(systemName: status.symbol)
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
