import SwiftUI

/// The to-read pile and the average rating, in tiles. Every tile is always
/// drawn: one with nothing behind it reads a dash, with no caption to explain.
/// The rating tile opens the library on the books hearted — the best of what
/// was rated, one tap from its average.
struct StatTilesRow: View {
    let toReadCount: Int
    let monthsToClearPile: Int?
    let averageRating: Double?
    let ratedCount: Int
    var onRatingTapped: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            tile(
                title: "Pile à lire",
                value: toReadCount > 0 ? Text(toReadCount, format: .number) : Text("–"),
                caption: pileCaption,
                color: DashboardPalette.pile
            )
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
        StatTilesRow(toReadCount: 27, monthsToClearPile: 9, averageRating: 4.2, ratedCount: 18)
        StatTilesRow(toReadCount: 0, monthsToClearPile: nil, averageRating: nil, ratedCount: 0)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
