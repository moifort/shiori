import SwiftUI

/// A category of Découvrir's Books shelf opened from its summary line: every
/// cover it holds, three a row, drawn and opened as its strip draws and opens
/// them.
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

/// Three covers a row.
struct DiscoverCoverGrid<Content: View>: View {
    @ViewBuilder let content: Content

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 20) { content }
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
