import SwiftUI

/// The books read this year against the same span of last year, with the Fitness
/// app's arrows. Without last year there is no arrow, only this year's figure.
struct TrendsWidget: View {
    let booksRead: Dashboard.Trend

    var body: some View {
        WidgetCard(title: "Tendances") {
            Text("vs \(String(Calendar.current.component(.year, from: .now) - 1))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } content: {
            if let books = booksRead.current {
                row(
                    label: "Livres lus",
                    value: Self.booksLabel(books),
                    previous: booksRead.previous.map(Self.booksLabel),
                    direction: booksRead.direction,
                    color: DashboardPalette.books
                )
            } else {
                WidgetEmptyMessage(text: "Terminez un livre cette année pour voir vos tendances.", placeholder: .rows)
            }
        }
        .accessibilityIdentifier("home-trends")
    }

    private func row(
        label: LocalizedStringKey,
        value: String,
        previous: String?,
        direction: Dashboard.Trend.Direction?,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.18))
                Image(systemName: symbol(for: direction))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                    if let previous {
                        Text(previous).font(.footnote).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private static func booksLabel(_ count: Int) -> String {
        count == 1 ? String(localized: "1 livre") : String(localized: "\(count) livres")
    }

    private func symbol(for direction: Dashboard.Trend.Direction?) -> String {
        switch direction {
        case .up: "arrow.up"
        case .down: "arrow.down"
        case nil: "equal"
        }
    }
}

#Preview {
    TrendsWidget(booksRead: .init(current: 18, previous: 14))
    .padding()
    .background(Color(.systemGroupedBackground))
}
