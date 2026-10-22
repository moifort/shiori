import SwiftUI

extension ToolbarItemPlacement {
    /// Where a sheet's confirming action goes — Enregistrer, Valider, Ajouter.
    /// Pinned to the trailing edge from iOS 27, as Apple asks for the
    /// prominent action of a view: on an iPhone Duo, whose bars stand along
    /// the side, it then sits at the top of the vertical bar under Close, and
    /// never falls into the overflow menu. Before iOS 27, or built with an
    /// older SDK, it is the confirmation placement it always was.
    static var confirmingAction: ToolbarItemPlacement {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            return .topBarPinnedTrailing
        }
        #endif
        return .confirmationAction
    }
}
