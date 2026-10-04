import SwiftUI

/// One key figure of the admin screen: what it counts, the figure itself, and
/// a line of context under it (this month's newcomers, the gross before Apple's
/// commission). The icon sits at the top, beside the label.
struct AdminKpiTile: View {
    let title: LocalizedStringKey
    let value: String
    var detail: String?
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(tint)
                .labelStyle(.titleAndIcon)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HStack {
        AdminKpiTile(
            title: "Utilisateurs", value: "128", detail: "+23 ce mois",
            icon: "person.2.fill", tint: .blue
        )
        AdminKpiTile(title: "Premium", value: "14", icon: "crown.fill", tint: .orange)
    }
    .padding()
}
