import SwiftUI

/// Three small boxes at the head of the dashboard: every book read since the
/// start, the favourites and the to-read pile. Every box is always drawn: one
/// with nothing behind it reads a dash. Each opens the library on the list it
/// counts: the books read, the books hearted, the pile.
struct StatTilesRow: View {
    var readCount: Int = 0
    var favoriteCount: Int = 0
    var toReadCount: Int = 0
    var onReadTapped: () -> Void = {}
    var onFavoritesTapped: () -> Void = {}
    var onPileTapped: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            smallTile(
                title: "Lus",
                count: readCount,
                systemImage: ReadingStatus.read.symbol,
                color: ReadingStatus.read.tint,
                action: onReadTapped
            )
            .accessibilityIdentifier("home-read")
            smallTile(
                title: "Favoris",
                count: favoriteCount,
                systemImage: "heart.fill",
                color: .red,
                action: onFavoritesTapped
            )
            .accessibilityIdentifier("home-favorites")
            smallTile(
                title: "Pile à lire",
                count: toReadCount,
                systemImage: ReadingStatus.toRead.symbol,
                color: DashboardPalette.pile,
                action: onPileTapped
            )
            .accessibilityIdentifier("home-pile")
        }
    }

    /// A small box: an icon beside a count, and what it counts under them.
    /// Stacked rather than on one line so that three fit side by side on the
    /// narrowest phone.
    private func smallTile(
        title: LocalizedStringKey,
        count: Int,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(color)
                    (count > 0 ? Text(count, format: .number) : Text("–"))
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        StatTilesRow(readCount: 142, favoriteCount: 6, toReadCount: 27)
        StatTilesRow()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
