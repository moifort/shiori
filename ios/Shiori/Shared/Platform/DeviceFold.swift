import SwiftUI

extension GeometryProxy {
    /// Where an iPhone Duo folds across this view, as the horizontal span
    /// content keeps clear of — the crease and the margins the system asks
    /// around it — in the view's own coordinates. Nil on a phone, on the Duo's
    /// outer screen, and when the fold does not cross the view.
    ///
    /// iOS 27.1 reserves the fold as a `division` region, active only while
    /// the Duo is partly folded. Laid flat it is inactive and zero wide, and
    /// `includeInactive` still reports its line, so a layout can keep to it
    /// in both poses and not jump as the Duo folds.
    func foldSpan(includeInactive: Bool = false) -> ClosedRange<CGFloat>? {
        #if canImport(SwiftUICore, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            let regions = reservedRegions(kind: .division, options: includeInactive ? .includeInactive : [])
            guard let fold = regions.first else { return nil }
            // Laid flat, the crease is no obstacle: only its line counts, not
            // the margins the system asks around it while the Duo is folded.
            let margins = fold.isActive ? fold.margins : EdgeInsets()
            let lower = fold.frame.minX - margins.leading
            let upper = fold.frame.maxX + margins.trailing
            return lower <= upper ? lower...upper : fold.frame.midX...fold.frame.midX
        }
        #endif
        return nil
    }
}
