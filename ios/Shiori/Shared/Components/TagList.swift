import SwiftUI

/// Short labels drawn as pills that wrap onto as many lines as they need — a
/// book's genres, where a comma-joined line would truncate on the third one.
struct TagList: View {
    let tags: [String]
    var systemImage: String?

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Pill(text: tag, systemImage: systemImage)
            }
        }
    }
}

/// One word in a capsule: a tag, or a figure set apart from the text around it.
struct Pill: View {
    let text: String
    var systemImage: String?
    /// A pill that stands for a status takes that status's colour, as the
    /// library row's chips do. Nil draws the neutral grey of a plain fact.
    var tint: Color?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).imageScale(.small)
            }
            Text(text)
        }
        // A pill is one short fact: "7 h 37" split over two lines reads as two.
        .lineLimit(1)
        .fixedSize()
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .foregroundStyle(tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.primary))
        .background(
            tint.map { AnyShapeStyle($0.opacity(0.15)) } ?? AnyShapeStyle(.quaternary),
            in: Capsule()
        )
    }
}

/// Lays its children out left to right, starting a new line when the next one
/// would overflow the proposed width.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

#Preview {
    List {
        TagList(tags: ["Fantasy", "Roman initiatique", "Aventure", "Magie", "Musique"])
    }
}
