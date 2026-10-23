import SwiftUI

extension GeometryProxy {
    /// Where a partly folded iPhone Duo folds across this view, as the
    /// horizontal span content keeps clear of — the crease and the margins
    /// the system asks around it — in the view's own coordinates. Nil on a
    /// phone, on the Duo's outer screen, on its inner screen laid flat, and
    /// when the fold does not cross the view.
    ///
    /// iOS 27.1 reserves the fold as a `division` region, active only while
    /// the Duo is partly folded.
    func foldSpan() -> ClosedRange<CGFloat>? {
        #if canImport(SwiftUICore, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            guard let fold = reservedRegions(kind: .division).first else { return nil }
            let lower = fold.frame.minX - fold.margins.leading
            let upper = fold.frame.maxX + fold.margins.trailing
            return lower <= upper ? lower...upper : fold.frame.midX...fold.frame.midX
        }
        #endif
        return nil
    }
}
