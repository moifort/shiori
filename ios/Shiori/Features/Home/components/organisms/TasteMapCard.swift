import Charts
import SwiftUI

/// Each genre placed by how many of its books the reader finished against how
/// they rated them. The two dashed lines cut the map in four: what the reader
/// reads a lot and likes, reads a lot out of habit, should read more of, and
/// keeps being let down by.
struct TasteMapCard: View {
    let tastes: [GenreInsights.Taste]
    let averageRating: Double
    let hiddenGem: BookGenre?

    /// The middle of the genres' counts: left of it, a genre is read little.
    private var medianCount: Double {
        let counts = tastes.map(\.readCount).sorted()
        guard !counts.isEmpty else { return 0 }
        let middle = counts.count / 2
        return counts.count.isMultiple(of: 2)
            ? Double(counts[middle - 1] + counts[middle]) / 2
            : Double(counts[middle])
    }

    private var ratingFloor: Double {
        let lowest = tastes.map(\.averageRating).min() ?? 3
        return min(3, ((lowest - 0.3) * 2).rounded(.down) / 2)
    }

    private var countCeiling: Int {
        (tastes.map(\.readCount).max() ?? 1) + 2
    }

    var body: some View {
        WidgetCard(title: "Ce que vous lisez, ce que vous aimez") {
            chart
                .frame(height: 240)
            if let gem = tastes.first(where: { $0.genre == hiddenGem }) {
                gemRow(gem)
            }
        }
    }

    private var chart: some View {
        Chart {
            RuleMark(x: .value("Livres lus", medianCount))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color(.separator))
            RuleMark(y: .value("Note moyenne", averageRating))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color(.separator))
            ForEach(tastes) { taste in
                PointMark(
                    x: .value("Livres lus", taste.readCount),
                    y: .value("Note moyenne", taste.averageRating)
                )
                .foregroundStyle(taste.genre.tint)
                .symbolSize(taste.genre == hiddenGem ? 260 : 140)
                .annotation(position: labelPosition(taste), spacing: 6) {
                    Text(taste.genre.label)
                        .font(.caption2)
                        .foregroundStyle(taste.genre == hiddenGem ? AnyShapeStyle(taste.genre.tint) : AnyShapeStyle(.secondary))
                }
            }
        }
        .chartXScale(domain: 0...countCeiling)
        .chartYScale(domain: ratingFloor...5.3)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: Array(stride(from: ratingFloor.rounded(.up), through: 5, by: 1))) { value in
                AxisValueLabel {
                    if let rating = value.as(Double.self) {
                        Label("\(Int(rating))", systemImage: "star.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
        }
        .chartXAxisLabel("Livres lus", alignment: .trailing)
        .chartPlotStyle { plot in
            plot
                .overlay(alignment: .topLeading) { quadrant("À creuser") }
                .overlay(alignment: .topTrailing) { quadrant("Valeurs sûres") }
                .overlay(alignment: .bottomLeading) { quadrant("Déceptions") }
                .overlay(alignment: .bottomTrailing) { quadrant("Habitudes") }
        }
    }

    /// Beside the point rather than above it, where neighbours read apart; on
    /// its left near the right edge, where the label would not fit.
    private func labelPosition(_ taste: GenreInsights.Taste) -> AnnotationPosition {
        Double(taste.readCount) > Double(countCeiling) * 0.7 ? .leading : .trailing
    }

    private func quadrant(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color(.tertiaryLabel))
            .padding(4)
            .allowsHitTesting(false)
    }

    private func gemRow(_ gem: GenreInsights.Taste) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(gem.genre.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pépite sous-explorée")
                    .font(.subheadline.weight(.semibold))
                Text("\(gem.genre.label) : \(gem.averageRating.formatted(.number.precision(.fractionLength(1)))) ★ en moyenne, sur \(gem.readCount) livres seulement.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 4)
    }
}

#Preview {
    TasteMapCard(
        tastes: GenreInsights.preview.tastes,
        averageRating: GenreInsights.preview.averageRating ?? 4,
        hiddenGem: GenreInsights.preview.hiddenGem
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
