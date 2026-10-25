import SwiftUI

/// Figures as the App Store sets an app's under its name: each a figure over
/// what it counts in small capitals, parted by hairlines, with nothing else
/// drawn — no mark, no box, no chevron. Columns that fit the width are spread
/// across it; past that, the line scrolls sideways as the App Store's does.
/// The home's year and a saga's page draw their figures with it.
struct FiguresLine: View {
    struct Item {
        let value: String
        let label: String
    }

    let items: [Item]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            columns(spread: true)
            ScrollView(.horizontal) {
                columns(spread: false)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    /// The columns and the hairlines between them: spread across the width
    /// with the free room shared out evenly, the outer columns keeping half a
    /// gap from the edges so the line breathes, the hairline in the middle of
    /// each gap; or each set to its content with a margin when the line
    /// scrolls.
    private func columns(spread: Bool) -> some View {
        HStack(spacing: 0) {
            if spread { Spacer(minLength: 0) }
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    if spread { Spacer(minLength: 6) }
                    Divider().frame(height: 30)
                    if spread { Spacer(minLength: 6) }
                }
                column(item).padding(.horizontal, spread ? 0 : 16)
            }
            if spread { Spacer(minLength: 0) }
        }
    }

    private func column(_ item: Item) -> some View {
        VStack(spacing: 3) {
            Text(item.value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text(item.label)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    /// A figure in thousands past a thousand, its unit against it — "850",
    /// "1,5k", "16k" — closer than the system's compact notation sets it.
    static func compact(_ value: Int) -> String {
        guard value >= 1000 else { return value.formatted() }
        let thousands = Double(value) / 1000
        let figure = thousands < 10
            ? thousands.formatted(.number.precision(.fractionLength(0...1)))
            : thousands.rounded().formatted(.number.precision(.fractionLength(0)))
        return figure + "k"
    }
}

#Preview {
    FiguresLine(items: [
        .init(value: "4", label: "lus"),
        .init(value: "1", label: "à lire"),
        .init(value: "6", label: "tomes"),
        .init(value: "1", label: "annoncé"),
        .init(value: FiguresLine.compact(2900), label: "pages"),
    ])
    .padding()
}
