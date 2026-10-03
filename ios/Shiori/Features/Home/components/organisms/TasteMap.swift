import Charts
import SwiftUI

/// Each genre placed by how many of its books the reader finished against how
/// they rated them, drawn straight on the page. The median count and the
/// reader's average rating cut the map in four, each quarter washed in its own
/// colour and fading out towards the edges into the page: what the reader reads
/// a lot and likes, reads a lot out of habit, should read more of, and keeps
/// being let down by. A genre is a bubble as large as its shelf.
struct TasteMap: View {
    let tastes: [GenreInsights.Taste]
    let averageRating: Double
    let gem: GenreInsights.Taste?

    /// The plot's size, once drawn: what the labels are laid out against.
    @State private var plotSize: CGSize = .zero

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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .trailing, spacing: 2) {
                chart
                    .frame(height: 280)
                // Below the chart rather than as its axis label, which the
                // quarter washes leave undrawn.
                Text("Livres lus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            if let gem {
                gemCallout(gem)
            }
        }
    }

    private var chart: some View {
        let sides = labelSides
        return Chart(tastes) { taste in
            PointMark(
                x: .value("Livres lus", taste.readCount),
                y: .value("Note moyenne", taste.averageRating)
            )
            .symbol { bubble(taste, side: sides[taste.id] ?? .trailing) }
        }
        .chartXScale(domain: 0...countCeiling)
        .chartYScale(domain: ratingFloor...ratingCeiling)
        .chartXAxis {
            AxisMarks(values: Array(stride(from: 0, through: countCeiling, by: countCeiling > 12 ? 5 : 2))) { _ in
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: Array(stride(from: ratingFloor.rounded(.up), through: 5, by: 1))) { value in
                AxisValueLabel {
                    if let rating = value.as(Double.self) {
                        HStack(spacing: 1) {
                            Image(systemName: "star.fill").imageScale(.small)
                            Text("\(Int(rating))")
                        }
                    }
                }
            }
        }
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let plotFrame = proxy.plotFrame {
                    quarters(in: geometry[plotFrame], proxy: proxy)
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { plotSize = $0 }
                }
            }
        }
        .chartPlotStyle { plot in
            plot
                .overlay(alignment: .topLeading) { quadrant("À creuser", color: .orange) }
                .overlay(alignment: .topTrailing) { quadrant("Valeurs sûres", color: .green) }
                .overlay(alignment: .bottomLeading) { quadrant("Déceptions", color: .red) }
                .overlay(alignment: .bottomTrailing) { quadrant("Habitudes", color: .gray) }
        }
    }

    /// The four washes, behind the bubbles, split where the median and the
    /// average fall and faded out on every side so the map has no edge.
    private func quarters(in frame: CGRect, proxy: ChartProxy) -> some View {
        let splitX = (proxy.position(forX: medianCount) ?? frame.width / 2)
        let splitY = (proxy.position(forY: averageRating) ?? frame.height / 2)
        return ZStack(alignment: .topLeading) {
            wash(.orange, x: 0, y: 0, width: splitX, height: splitY)
            wash(.green, x: splitX, y: 0, width: frame.width - splitX, height: splitY)
            wash(.red, x: 0, y: splitY, width: splitX, height: frame.height - splitY)
            wash(.gray, x: splitX, y: splitY, width: frame.width - splitX, height: frame.height - splitY)
        }
        .frame(width: frame.width, height: frame.height, alignment: .topLeading)
        .mask(fade(.horizontal))
        .mask(fade(.vertical))
        .offset(x: frame.minX, y: frame.minY)
    }

    private func wash(_ color: Color, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        color.opacity(0.16)
            .frame(width: max(0, width), height: max(0, height))
            .offset(x: x, y: y)
    }

    private func fade(_ axis: Axis) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.22),
                .init(color: .black, location: 0.78),
                .init(color: .clear, location: 1),
            ],
            startPoint: axis == .horizontal ? .leading : .top,
            endPoint: axis == .horizontal ? .trailing : .bottom
        )
    }

    /// A glossy bubble, as large as the genre's shelf, named on the side
    /// `labelSides` gave it; the gem rings itself. The name hangs off the bubble
    /// rather than being a chart annotation, which loses its anchor on a symbol
    /// drawn as a view.
    private func bubble(_ taste: GenreInsights.Taste, side: LabelSide) -> some View {
        let size = bubbleSize(taste)
        let isGem = taste == gem
        return Circle()
            .fill(taste.genre.tint.gradient)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .frame(width: size, height: size)
            .shadow(color: taste.genre.tint.opacity(0.45), radius: 4, y: 1)
            .background {
                if isGem {
                    Circle()
                        .stroke(taste.genre.tint.opacity(0.5), lineWidth: 1.5)
                        .frame(width: size + 10, height: size + 10)
                }
            }
            .overlay {
                Text(taste.label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isGem ? taste.genre.tint : Color(.secondaryLabel))
                    .fixedSize()
                    .offset(labelOffset(taste, side: side))
            }
    }

    private func bubbleSize(_ taste: GenreInsights.Taste) -> CGFloat {
        12 + 14 * CGFloat(taste.readCount) / CGFloat(countCeiling)
    }

    // MARK: - Label layout

    /// Where a bubble's name reads: beside it on either hand, or under it when
    /// both hands are taken.
    private enum LabelSide: CaseIterable {
        case trailing, leading, below
    }

    private static let labelFont = UIFont.systemFont(
        ofSize: UIFont.preferredFont(forTextStyle: .caption2).pointSize,
        weight: .medium
    )

    private func labelGap(_ taste: GenreInsights.Taste) -> CGFloat {
        taste == gem ? 7 : 4
    }

    private func labelSize(_ taste: GenreInsights.Taste) -> CGSize {
        (taste.label as NSString).size(withAttributes: [.font: Self.labelFont])
    }

    /// How far the name's centre sits from the bubble's.
    private func labelOffset(_ taste: GenreInsights.Taste, side: LabelSide) -> CGSize {
        let label = labelSize(taste)
        let reach = bubbleSize(taste) / 2 + labelGap(taste)
        return switch side {
        case .trailing: CGSize(width: reach + label.width / 2, height: 0)
        case .leading: CGSize(width: -(reach + label.width / 2), height: 0)
        case .below: CGSize(width: 0, height: reach + label.height / 2 - 2)
        }
    }

    /// The bubble's centre on the plot, in points.
    private func centre(_ taste: GenreInsights.Taste) -> CGPoint {
        CGPoint(
            x: plotSize.width * CGFloat(Double(taste.readCount) / countCeiling),
            y: plotSize.height
                * CGFloat((ratingCeiling - taste.averageRating) / (ratingCeiling - ratingFloor))
        )
    }

    /// Every name's side, laid out once for the whole map: the most read first,
    /// each taking the first side that runs into no bubble and no name already
    /// placed, nor off the plot; when none is free, the side that overlaps
    /// least. Nothing is measured before the plot is drawn, when every name
    /// reads on the right.
    private var labelSides: [GenreInsights.Taste.ID: LabelSide] {
        guard plotSize != .zero else { return [:] }
        // The axis labels leave a little room past either edge of the plot.
        let bounds = CGRect(origin: .zero, size: plotSize).insetBy(dx: -24, dy: -8)
        var taken = tastes.map { taste in
            let size = bubbleSize(taste)
            let centre = centre(taste)
            return CGRect(x: centre.x - size / 2, y: centre.y - size / 2, width: size, height: size)
        }
        var sides: [GenreInsights.Taste.ID: LabelSide] = [:]
        for taste in tastes.sorted(by: { $0.readCount > $1.readCount }) {
            let candidates = LabelSide.allCases.map { side in
                let label = labelSize(taste)
                let offset = labelOffset(taste, side: side)
                let centre = centre(taste)
                let rect = CGRect(
                    x: centre.x + offset.width - label.width / 2,
                    y: centre.y + offset.height - label.height / 2,
                    width: label.width,
                    height: label.height
                )
                let overlap = taken.reduce(0) { $0 + area($1.intersection(rect)) }
                let outside = area(rect) - area(bounds.intersection(rect))
                return (side: side, rect: rect, cost: overlap + outside)
            }
            let best = candidates.first { $0.cost == 0 } ?? candidates.min { $0.cost < $1.cost }!
            sides[taste.id] = best.side
            taken.append(best.rect)
        }
        return sides
    }

    private func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }

    private func quadrant(_ text: LocalizedStringKey, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color.opacity(0.85))
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
                Text("\(gem.label) : \(gem.averageRating.formatted(.number.precision(.fractionLength(1)))) ★ en moyenne, sur \(gem.readCount) livres seulement.")
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
    TasteMap(
        tastes: GenreInsights.preview.tastes,
        averageRating: GenreInsights.preview.averageRating ?? 4,
        gem: GenreInsights.preview.gem
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
