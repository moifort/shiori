import SwiftUI

/// The to-read pile and the average rating, in tiles, and under them three
/// small boxes: every book read since the start, the favourites and the books
/// dropped. Every tile is always drawn: one with nothing behind it reads a
/// dash, with no caption to explain. Each opens the library on the list it
/// counts: the pile, the favourites — a heart is five stars — the books read,
/// the books hearted, the books put down.
struct StatTilesRow: View {
    let toReadCount: Int
    let monthsToClearPile: Int?
    let averageRating: Double?
    let ratedCount: Int
    var readCount: Int = 0
    var favoriteCount: Int = 0
    var droppedCount: Int = 0
    var onPileTapped: () -> Void = {}
    var onRatingTapped: () -> Void = {}
    var onReadTapped: () -> Void = {}
    var onFavoritesTapped: () -> Void = {}
    var onDroppedTapped: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            mainTiles
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
                    color: .pink,
                    action: onFavoritesTapped
                )
                .accessibilityIdentifier("home-favorites")
                smallTile(
                    title: "Abandonnés",
                    count: droppedCount,
                    systemImage: "hand.thumbsdown.fill",
                    color: ReadingStatus.dropped.tint,
                    action: onDroppedTapped
                )
                .accessibilityIdentifier("home-dropped")
            }
        }
    }

    private var mainTiles: some View {
        HStack(spacing: 12) {
            Button(action: onPileTapped) {
                tile(
                    title: "Pile à lire",
                    value: toReadCount > 0 ? Text(toReadCount, format: .number) : Text("–"),
                    caption: pileCaption,
                    color: DashboardPalette.pile,
                    leadsSomewhere: true
                )
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home-pile")
            Button(action: onRatingTapped) {
                tile(
                    title: "Note moyenne",
                    value: averageRating.map { Text($0, format: .number.precision(.fractionLength(1))) }
                        ?? Text("–"),
                    caption: averageRating == nil ? nil : String(localized: "sur \(ratedCount) livres notés"),
                    color: DashboardPalette.rating,
                    leadsSomewhere: true
                )
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home-rating")
        }
        // Both tiles take the height of the taller one, as the Fitness app's do.
        .fixedSize(horizontal: false, vertical: true)
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

    private var pileCaption: String? {
        if toReadCount == 0 { return nil }
        if let monthsToClearPile { return String(localized: "≈ \(monthsToClearPile) mois au rythme actuel") }
        return String(localized: "\(toReadCount) livres à lire")
    }

    /// A tile that leads somewhere carries the chevron the widget headers do.
    private func tile(
        title: LocalizedStringKey,
        value: Text,
        caption: String?,
        color: Color,
        leadsSomewhere: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                if leadsSomewhere {
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            value
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            if let caption {
                Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}

#Preview {
    VStack {
        StatTilesRow(toReadCount: 27, monthsToClearPile: 9, averageRating: 4.2, ratedCount: 18, favoriteCount: 6, droppedCount: 2)
        StatTilesRow(toReadCount: 0, monthsToClearPile: nil, averageRating: nil, ratedCount: 0)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
