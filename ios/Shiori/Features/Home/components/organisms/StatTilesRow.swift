import SwiftUI

/// The to-read pile, the average rating and the favourites, in tiles. Every
/// tile is always drawn: one with nothing behind it reads a dash, with no
/// caption to explain. The favourites tile opens the list of everything
/// hearted, sagas included, which no other screen gathers.
struct StatTilesRow: View {
    let toReadCount: Int
    let monthsToClearPile: Int?
    let averageRating: Double?
    let ratedCount: Int
    var favoriteCount: Int = 0
    var onFavoritesTapped: () -> Void = {}

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                tile(
                    title: "Pile à lire",
                    value: toReadCount > 0 ? Text(toReadCount, format: .number) : Text("–"),
                    caption: pileCaption,
                    color: DashboardPalette.pile
                )
                .accessibilityIdentifier("home-pile")
                tile(
                    title: "Note moyenne",
                    value: averageRating.map { Text($0, format: .number.precision(.fractionLength(1))) }
                        ?? Text("–"),
                    caption: averageRating == nil ? nil : String(localized: "sur \(ratedCount) livres notés"),
                    color: DashboardPalette.rating
                )
                .accessibilityIdentifier("home-rating")
            }
            // Both tiles take the height of the taller one, as the Fitness app's do.
            .fixedSize(horizontal: false, vertical: true)

            Button(action: onFavoritesTapped) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Favoris").font(.subheadline.weight(.semibold))
                        (favoriteCount > 0 ? Text(favoriteCount, format: .number) : Text("–"))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(DashboardPalette.favorites)
                        Text(favoriteCount > 0 ? "livres et séries que vous gardez près de vous" : "Un cœur sur un livre ou une série le range ici.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home-favorites")
        }
    }

    private var pileCaption: String? {
        if toReadCount == 0 { return nil }
        if let monthsToClearPile { return String(localized: "≈ \(monthsToClearPile) mois au rythme actuel") }
        return String(localized: "\(toReadCount) livres à lire")
    }

    private func tile(title: LocalizedStringKey, value: Text, caption: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
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
        StatTilesRow(toReadCount: 27, monthsToClearPile: 9, averageRating: 4.2, ratedCount: 18, favoriteCount: 6)
        StatTilesRow(toReadCount: 0, monthsToClearPile: nil, averageRating: nil, ratedCount: 0)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
