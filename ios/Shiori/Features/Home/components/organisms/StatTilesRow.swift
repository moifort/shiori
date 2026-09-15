import SwiftUI

/// The to-read pile and the average rating, side by side. A tile with nothing to
/// say is left out and the other takes the row.
struct StatTilesRow: View {
    let toReadCount: Int
    let monthsToClearPile: Int?
    let averageRating: Double?
    let ratedCount: Int

    var body: some View {
        HStack(spacing: 12) {
            if toReadCount > 0 {
                tile(
                    title: "Pile à lire",
                    value: Text(toReadCount, format: .number),
                    caption: monthsToClearPile.map { String(localized: "≈ \($0) mois au rythme actuel") }
                        ?? String(localized: "\(toReadCount) livres à lire"),
                    color: DashboardPalette.pile
                )
                .accessibilityIdentifier("home-pile")
            }
            if let averageRating {
                tile(
                    title: "Note moyenne",
                    value: Text(averageRating, format: .number.precision(.fractionLength(1))),
                    caption: String(localized: "sur \(ratedCount) livres notés"),
                    color: DashboardPalette.rating
                )
                .accessibilityIdentifier("home-rating")
            }
        }
        // Both tiles take the height of the taller one, as the Fitness app's do.
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tile(title: LocalizedStringKey, value: Text, caption: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.semibold))
            value
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}

#Preview {
    StatTilesRow(toReadCount: 27, monthsToClearPile: 9, averageRating: 4.2, ratedCount: 18)
        .padding()
        .background(Color(.systemGroupedBackground))
}
