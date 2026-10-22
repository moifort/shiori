import SwiftUI

extension GeometryProxy {
    /// Where an iPhone Duo folds across this view, as the horizontal span
    /// content should keep clear of — the crease and the margins the system
    /// asks around it — in the view's own coordinates. Nil on a phone, on the
    /// Duo's outer screen, and when the fold does not cross the view.
    ///
    /// This is the system's own answer: iOS 27.1 reserves the fold as a
    /// `division` region. It is active only while the Duo is partly folded;
    /// laid flat, the region is inactive and zero wide, and `includeInactive`
    /// still reports it, so a split can sit on the fold in both poses.
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

extension EnvironmentValues {
    /// Closes the detail a screen is shown as, beside the page it was opened
    /// from on an unfolded iPhone Duo. Nil when the screen is a sheet, which
    /// closes as a sheet does.
    @Entry var closeDetailPane: (@MainActor () -> Void)?
}
