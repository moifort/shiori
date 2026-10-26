import Foundation
import SwiftUI

/// A view of the Series tab another screen asks it to open on: the dashboard's
/// "series in progress" card opens it on the sagas in progress.
struct SeriesRequest: Equatable {
    var mode: LibraryMode = .all
    var state: SeriesState?
}
