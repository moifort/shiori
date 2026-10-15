import SwiftUI

/// A horizontal strip inside a list row, as the dashboard's shelves scroll:
/// edge to edge, with room above for the badges that overhang a corner.
struct PicksStrip<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) { content }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
    }
}

#Preview {
    List {
        PicksStrip {
            ForEach(FriendPicks.preview.books) { loved in
                LovedBookTile(loved: loved) {}
            }
        }
    }
}
