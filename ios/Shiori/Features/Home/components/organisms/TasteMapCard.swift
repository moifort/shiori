import Charts
import SwiftUI

/// Each genre placed by how many of its books the reader finished against how
/// they rated them. The median count and the reader's average rating cut the
/// map in four, each quarter washed in its own colour: what the reader reads a
/// lot and likes, reads a lot out of habit, should read more of, and keeps
/// being let down by. A genre is a bubble as large as its shelf.
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

    private let ratingCeiling = 5.4

    private var countCeiling: Double {
        Double((tastes.map(\.readCount).max() ?? 1) + 2)
    }

    var body: some View {
        WidgetCard(title: "Ce que vous lisez, ce que vous aimez") {
            VStack(alignment: .trailing, spacing: 2) {
                chart
                    .frame(height: 260)
                // Below the chart rather than as its axis label, which the
                // quarter washes leave undrawn.
                Text("Livres lus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let gem = tastes.first(where: { $0.genre == hiddenGem }) {
                gemCallout(gem)
            }
        }
    }

    private var chart: some View {
        Chart {
            quarter(x: 0...medianCount, y: averageRating...ratingCeiling, color: .orange)
            quarter(x: medianCount...countCeiling, y: averageRating...ratingCeiling, color: .green)
            quarter(x: 0...medianCount, y: ratingFloor...averageRating, color: .red)
            quarter(x: medianCount...countCeiling, y: ratingFloor...averageRating, color: .gray)
            ForEach(tastes) { taste in
                PointMark(
                    x: .value("Livres lus", taste.readCount),
                    y: .value("Note moyenne", taste.averageRating)
                )
                .symbol { bubble(taste) }
            }
        }
        .chartXScale(domain: 0...countCeiling)
        .chartYScale(domain: ratingFloor...ratingCeiling)
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
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel()
            }
        }
        .chartPlotStyle { plot in
            plot
                .clipShape(.rect(cornerRadius: 14))
                .overlay(alignment: .topLeading) { quadrant("À creuser", color: .orange) }
                .overlay(alignment: .topTrailing) { quadrant("Valeurs sûres", color: .green) }
                .overlay(alignment: .bottomLeading) { quadrant("Déceptions", color: .red) }
                .overlay(alignment: .bottomTrailing) { quadrant("Habitudes", color: .gray) }
        }
    }

    private func quarter(x: ClosedRange<Double>, y: ClosedRange<Double>, color: Color) -> some ChartContent {
        RectangleMark(
            xStart: .value("Livres lus", x.lowerBound),
            xEnd: .value("Livres lus", x.upperBound),
            yStart: .value("Note moyenne", y.lowerBound),
            yEnd: .value("Note moyenne", y.upperBound)
        )
        .foregroundStyle(color.opacity(0.09))
    }

    /// A glossy bubble, as large as the genre's shelf, named beside it; the gem
    /// rings itself. The name hangs off the bubble rather than being a chart
    /// annotation, which loses its anchor on a symbol drawn as a view.
    private func bubble(_ taste: GenreInsights.Taste) -> some View {
        let size = 12 + 14 * CGFloat(taste.readCount) / CGFloat(countCeiling)
        let onLeft = Double(taste.readCount) > countCeiling * 0.7
        return Circle()
            .fill(taste.genre.tint.gradient)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .frame(width: size, height: size)
            .shadow(color: taste.genre.tint.opacity(0.45), radius: 4, y: 1)
            .background {
                if taste.genre == hiddenGem {
                    Circle()
                        .stroke(taste.genre.tint.opacity(0.5), lineWidth: 1.5)
                        .frame(width: size + 10, height: size + 10)
                }
            }
            .overlay(alignment: onLeft ? .trailing : .leading) {
                Text(taste.genre.label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(taste.genre == hiddenGem ? taste.genre.tint : Color(.secondaryLabel))
                    .fixedSize()
                    .padding(onLeft ? .trailing : .leading, size + (taste.genre == hiddenGem ? 10 : 6))
            }
    }

    private func quadrant(_ text: LocalizedStringKey, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color.opacity(0.8))
            .padding(6)
            .allowsHitTesting(false)
    }

    private func gemCallout(_ gem: GenreInsights.Taste) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(gem.genre.tint.gradient)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("Pépite sous-explorée")
                    .font(.subheadline.weight(.semibold))
                Text("\(gem.genre.label) : \(gem.averageRating.formatted(.number.precision(.fractionLength(1)))) ★ en moyenne, sur \(gem.readCount) livres seulement.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(gem.genre.tint.opacity(0.1), in: .rect(cornerRadius: 14))
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
