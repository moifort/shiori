import SwiftUI

extension View {
    /// A list row whose separator runs from one edge of the card to the other,
    /// rather than starting at the text: the inset is pinned rather than left
    /// to the list, so the guides know exactly how far the edges are. Put on
    /// the outermost view of the row — a book row followed by a button would
    /// otherwise stop its line short of the button.
    func edgeToEdgeSeparator(inset: CGFloat = 16) -> some View {
        listRowInsets(.horizontal, inset)
            .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] - inset }
            .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] + inset }
    }
}
