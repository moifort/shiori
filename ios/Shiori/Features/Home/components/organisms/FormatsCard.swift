import SwiftUI

/// How the reader takes their books in — paper, screen, sound, drawn — and the
/// genre each format carries most, so "fantasy, heard" reads off one row.
struct FormatsCard: View {
    let formats: [GenreInsights.FormatShare]

    private var total: Int { formats.map(\.count).reduce(0, +) }

    var body: some View {
        WidgetCard(title: "Formats") {
            // The rows below name every format: the bar needs no legend.
            GeometryReader { proxy in
                let spacing: CGFloat = 2
                let available = proxy.size.width - spacing * CGFloat(max(0, formats.count - 1))
                HStack(spacing: spacing) {
                    ForEach(formats) { share in
                        share.format.chartColor
                            .frame(width: available * CGFloat(share.count) / CGFloat(max(1, total)))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(.capsule)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(formats) { share in
                    row(share)
                }
            }
            .padding(.top, 4)
        }
    }

    private func row(_ share: GenreInsights.FormatShare) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: share.format.symbol)
                .font(.body)
                .foregroundStyle(share.format.chartColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(share.format.label)
                    .font(.subheadline.weight(.semibold))
                if let genre = share.topGenre {
                    Text("Surtout \(genre.label)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(share.count)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text("\(percent(share)) %")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func percent(_ share: GenreInsights.FormatShare) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(share.count) / Double(total) * 100).rounded())
    }
}

extension BookFormat {
    /// The colour a format is charted in. A recording wears Audible's orange,
    /// as everywhere a book is heard.
    var chartColor: Color {
        switch self {
        case .book: .blue
        case .ebook: .teal
        case .audiobook: .audible
        case .bandeDessinee: .purple
        case .comic: .red
        case .manga: .pink
        }
    }
}

#Preview {
    FormatsCard(formats: GenreInsights.preview.formats)
        .padding()
        .background(Color(.systemGroupedBackground))
}
