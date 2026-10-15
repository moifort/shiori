import SwiftUI

/// One category of the Books shelf: its symbol, its name and what it holds
/// in a few words over a strip of every cover it holds, a tap on one opening
/// its page. A friend's page draws its shelves the same way; a line with no
/// covers is the heading alone.
struct DiscoverSummaryRow<Covers: View>: View {
    let title: LocalizedStringKey
    /// Nil for a line whose name says enough on its own.
    let systemImage: String?
    let tint: Color
    let line: String
    private let hasCovers: Bool
    @ViewBuilder let covers: Covers

    init(category: DiscoverCategory, line: String, @ViewBuilder covers: () -> Covers) {
        self.init(
            title: category.title,
            systemImage: category.systemImage,
            tint: category.tint,
            line: line,
            covers: covers
        )
    }

    init(
        title: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        line: String,
        @ViewBuilder covers: () -> Covers
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.line = line
        hasCovers = true
        self.covers = covers()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading
                .padding(.horizontal, 12)
            // Cut as far from the card's right edge as the first cover stands
            // from its left one; the room left of that cover is for the badges
            // overhanging its corner.
            if hasCovers {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 10) { covers }
                        .padding(.leading, 6)
                        .padding(.top, 6)
                }
                .padding(.leading, 6)
                .padding(.trailing, 12)
            }
        }
        .padding(.vertical, 12)
        .listRowInsets(EdgeInsets())
        // The line between two categories runs from edge to edge of the card.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in dimensions.width }
    }

    /// The name and what the category holds, its symbol in its colour on the
    /// top trailing corner.
    private var heading: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                // A heading alone has room to say a little more.
                Text(verbatim: line)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(hasCovers ? 1 : 2)
            }
            Spacer(minLength: 0)
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(tint)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension DiscoverSummaryRow where Covers == EmptyView {
    /// A line with nothing under its heading: a shelf too long to sum up in
    /// covers, opened whole by a tap.
    init(title: LocalizedStringKey, systemImage: String? = nil, tint: Color = .accentColor, line: String) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.line = line
        hasCovers = false
        covers = EmptyView()
    }
}

#Preview {
    List {
        Section {
            DiscoverSummaryRow(category: .soon, line: DiscoverSummaryLine.soon([.preview])) {
                ForEach(0..<6, id: \.self) { _ in
                    AwaitedEditionTile(edition: .preview, width: CoverTile.summaryWidth) {}
                }
            }
            DiscoverSummaryRow(category: .friends, line: "Marie, Paul +2") {
                ForEach(0..<6, id: \.self) { _ in
                    AwaitedEditionTile(edition: .preview, width: CoverTile.summaryWidth) {}
                }
            }
        }
    }
}
