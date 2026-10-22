import CoreGraphics

/// How the dashboard splits a wide screen in two columns of cards.
///
/// On an open iPhone Duo the space between them covers the fold, so no card
/// is drawn across the crease and each half of the screen holds whole cards:
/// the columns are as wide as each side allows, unequal when the fold is off
/// the page's middle. Elsewhere, two equal halves.
struct HomeColumns: Equatable {
    let leading: CGFloat
    let trailing: CGFloat
    let gutter: CGFloat

    /// The page's side margin, as `.padding(.horizontal)` draws it.
    static let margin: CGFloat = 16
    /// Between two halves of a flat screen, as between two cards.
    static let gutter: CGFloat = 16
    /// Kept clear on either side of the fold, past what the system reserves.
    static let foldClearance: CGFloat = 16
    /// Narrower than this, a column squeezes its cards: one column is better.
    static let minimumColumn: CGFloat = 240

    /// Nil in a compact width — a phone, the Duo folded — or when a column
    /// would squeeze its cards: one column. `fold` is the span the system
    /// reserves for the fold, in the page's own coordinates.
    init?(width: CGFloat, fold: ClosedRange<CGFloat>?, isRegularWidth: Bool) {
        guard isRegularWidth else { return nil }
        if let fold {
            let leading = fold.lowerBound - Self.foldClearance - Self.margin
            let trailing = width - Self.margin - fold.upperBound - Self.foldClearance
            if leading >= Self.minimumColumn, trailing >= Self.minimumColumn {
                self.leading = leading
                self.trailing = trailing
                gutter = fold.upperBound - fold.lowerBound + 2 * Self.foldClearance
                return
            }
        }
        let half = (width - 2 * Self.margin - Self.gutter) / 2
        guard half >= Self.minimumColumn else { return nil }
        leading = half
        trailing = half
        gutter = Self.gutter
    }
}
