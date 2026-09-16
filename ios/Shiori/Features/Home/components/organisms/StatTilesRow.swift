import SwiftUI

/// The to-read pile and the average rating, side by side. Both tiles are always
/// drawn: one with nothing behind it reads a dash, with no caption to explain.
struct StatTilesRow: View {
    let toReadCount: Int
    let monthsToClearPile: Int?
    let averageRating: Double?
    let ratedCount: Int

    var body: some View {
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
        StatTilesRow(toReadCount: 27, monthsToClearPile: 9, averageRating: 4.2, ratedCount: 18)
        StatTilesRow(toReadCount: 0, monthsToClearPile: nil, averageRating: nil, ratedCount: 0)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
