import SwiftUI

/// A category of Découvrir's Books shelf opened from its summary line: every
/// cover it holds, three a row, drawn and opened as its strip draws and opens
/// them. A category split by genre, as the award winners are, keeps a heading
/// per part.
struct DiscoverCategoryPage<Content: View>: View {
    let category: DiscoverCategory
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) { content }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Three covers a row, under a heading when the page has several parts.
struct DiscoverCoverGrid<Content: View>: View {
    var heading: String?
    @ViewBuilder let content: Content

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let heading {
                Text(verbatim: heading)
                    .font(.headline)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) { content }
        }
    }
}

extension CoverTile {
    /// A tile in a grid of three, wide enough that they fit beside each other
    /// on the narrowest iPhone.
    static let gridWidth: CGFloat = 100
}

#Preview {
    NavigationStack {
        DiscoverCategoryPage(category: .soon) {
            DiscoverCoverGrid {
                ForEach(0..<5, id: \.self) { _ in
                    AwaitedEditionTile(edition: .preview, width: CoverTile.gridWidth) {}
                }
            }
        }
    }
}
