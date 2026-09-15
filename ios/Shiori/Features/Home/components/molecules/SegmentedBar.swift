import SwiftUI

/// A horizontal bar split into proportional segments, with a legend under it.
struct SegmentedBar: View {
    struct Segment: Identifiable {
        let id: String
        let label: String
        let value: Int
        let color: Color
    }

    let segments: [Segment]

    private var total: Int { max(1, segments.reduce(0) { $0 + $1.value }) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                let spacing: CGFloat = 2
                let available = geometry.size.width - spacing * CGFloat(max(0, segments.count - 1))
                HStack(spacing: spacing) {
                    ForEach(segments) { segment in
                        segment.color
                            .frame(width: available * CGFloat(segment.value) / CGFloat(total))
                    }
                }
            }
            .frame(height: 12)
            .clipShape(.capsule)

            FlowLegend(segments: segments)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(segments.map { "\($0.label) \($0.value)" }.joined(separator: ", "))
    }
}

/// Legend entries that wrap onto as many lines as they need.
private struct FlowLegend: View {
    let segments: [SegmentedBar.Segment]

    var body: some View {
        FlowLayout(spacing: 12, lineSpacing: 6) {
            ForEach(segments) { segment in
                HStack(spacing: 4) {
                    Circle().fill(segment.color).frame(width: 8, height: 8)
                    Text(segment.label).foregroundStyle(.secondary)
                    Text(segment.value, format: .number).fontWeight(.semibold)
                }
                .font(.caption)
            }
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let extra = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += extra
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}

#Preview {
    SegmentedBar(segments: [
        .init(id: "a", label: "Fantasy", value: 7, color: .purple),
        .init(id: "b", label: "Science-fiction", value: 4, color: .cyan),
        .init(id: "c", label: "Aventure", value: 3, color: .orange),
        .init(id: "d", label: "Autres", value: 2, color: .gray),
    ])
    .padding()
}
