import SwiftUI

/// The Library tab: its entry screen, from which every shelf — the books, the
/// series, the authors, a genre — is pushed. Another tab asking for one of
/// them (the home's "Pile à lire", "Séries en cours") has it pushed at once.
struct LibraryTab: View {
    let onAdd: () -> Void
    @Binding var libraryRequest: LibraryRequest?
    @Binding var seriesRequest: SeriesRequest?

    var body: some View {
        LibraryShelvesScreen(request: $libraryRequest, seriesRequest: $seriesRequest)
    }
}
