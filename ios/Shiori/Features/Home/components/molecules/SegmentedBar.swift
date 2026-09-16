import SwiftUI

/// A horizontal bar split into proportional segments, each carrying its count
/// when it is wide enough to hold it, with an iconed legend under it.
struct SegmentedBar: View {
    struct Segment: Identifiable {
        let id: String
        let label: String
        var icon: Image?
        let value: Int
        let color: Color
    }

    let segments: [Segment]

    private var total: Int { max(1, segments.reduce(0) { $0 + $1.value }) }

    /// Narrower than this and a two-digit count would spill over the edges.
    private static let minimumLabelledWidth: CGFloat = 26

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                let spacing: CGFloat = 2
                let available = geometry.size.width - spacing * CGFloat(max(0, segments.count - 1))
                HStack(spacing: spacing) {
                    ForEach(segments) { segment in
                        let width = available * CGFloat(segment.value) / CGFloat(total)
                        segment.color
                            .frame(width: width)
                            .overlay {
                                if width >= Self.minimumLabelledWidth {
                                    Text(segment.value, format: .number)
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
            .frame(height: 22)
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
                    if let icon = segment.icon {
                        icon
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(segment.color)
                            .frame(width: 16)
                    } else {
                        Circle().fill(segment.color).frame(width: 8, height: 8)
                    }
                    Text(segment.label).foregroundStyle(.secondary)
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
        .init(id: "a", label: "Fantasy", icon: Image(systemName: "wand.and.sparkles"), value: 7, color: .blue),
        .init(id: "b", label: "Science-fiction", icon: Image("rocket"), value: 4, color: .orange),
        .init(id: "c", label: "Aventure", icon: Image(systemName: "map"), value: 3, color: .teal),
        .init(id: "d", label: "Autres", value: 1, color: .gray),
    ])
    .padding()
}
