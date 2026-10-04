import SwiftUI

/// The month's bill so far, where it is heading, and how that compares with
/// last month — the first thing the admin screen answers. A rise reads red and
/// a fall green: it is a cost.
struct AdminMonthCostCard: View {
    let costs: AdminMetrics.Costs?
    /// The month's name, for "vs sept." — the month before the one shown.
    let previousMonth: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Coût du mois", systemImage: "eurosign.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
            Text(costs.map { AdminFormat.euro($0.totalEur) } ?? String(localized: "Indisponible"))
                .font(.largeTitle.weight(.semibold))
                .monospacedDigit()
            if let costs {
                HStack(spacing: 8) {
                    if let projected = costs.projectedEur {
                        Text("≈ \(AdminFormat.euro(projected)) fin de mois")
                            .foregroundStyle(.secondary)
                    }
                    if let change = costs.changeVsPreviousMonth {
                        Text(changeText(change))
                            .fontWeight(.semibold)
                            .foregroundStyle(change > 0 ? .red : .green)
                    }
                }
                .font(.subheadline)
                .monospacedDigit()
                if let billedThrough = costs.billedThrough {
                    Text("Facturé jusqu'au \(billedThrough.formatted(AdminFormat.dayMonth))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func changeText(_ change: Double) -> String {
        let percent = change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()))
        let month = previousMonth.formatted(AdminFormat.shortMonth)
        return String(localized: "\(percent) vs \(month)")
    }
}

#Preview("With last month") {
    AdminMonthCostCard(costs: AdminMetrics.preview.costs, previousMonth: .now).padding()
}

#Preview("First month") {
    AdminMonthCostCard(costs: AdminMetrics.previewFirstMonth.costs, previousMonth: .now).padding()
}
