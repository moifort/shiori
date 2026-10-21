import CoreGraphics

/// How the dashboard splits a wide screen in two columns of cards.
///
/// On an open iPhone Duo the space between them sits on the fold, so no card
/// is drawn across the crease and each half of the screen holds whole cards:
/// the columns are as wide as each side allows, unequal when the page does
/// not start at the window's edge. Elsewhere, two equal halves.
struct HomeColumns: Equatable {
    let leading: CGFloat
    let trailing: CGFloat
    let gutter: CGFloat

    /// The page's side margin, as `.padding(.horizontal)` draws it.
    static let margin: CGFloat = 16
    /// Between two halves of a flat screen, as between two cards.
    static let gutter: CGFloat = 16
    /// Around the fold: clear of the crease on either side.
    static let foldGutter: CGFloat = 32
    /// Narrower than this, a column squeezes its cards: one column is better.
    static let minimumColumn: CGFloat = 240

    /// Nil when the page is narrower than `minimum`: one column.
    /// `fold` is where the screen folds, in the page's own coordinates.
    init?(width: CGFloat, fold: CGFloat?, minimum: CGFloat) {
        guard width >= minimum else { return nil }
        if let fold {
            let leading = fold - Self.foldGutter / 2 - Self.margin
            let trailing = width - Self.margin - fold - Self.foldGutter / 2
            if leading >= Self.minimumColumn, trailing >= Self.minimumColumn {
                self.leading = leading
                self.trailing = trailing
                gutter = Self.foldGutter
                return
            }
        }
        let half = (width - 2 * Self.margin - Self.gutter) / 2
        leading = half
        trailing = half
        gutter = Self.gutter
    }
}
