import SwiftUI

/// Under a shown book's facts: its summary, once the AI wrote it. While it
/// writes, the page says so with a floating pill (`generatingPill`), readable
/// and usable underneath; the summary appears in place when it is done.
struct ReleaseDescriptionSections: View {
    let isDescribing: Bool
    let synopsis: String?

    var body: some View {
        if !isDescribing, let synopsis, !synopsis.isEmpty {
            BookSynopsisSection(synopsis: synopsis)
        }
    }
}

#Preview("Release description") {
    NavigationStack {
        List {
            ReleaseDescriptionSections(isDescribing: true, synopsis: nil)
            ReleaseDescriptionSections(isDescribing: false, synopsis: ReleaseDescription.preview.book.synopsis)
        }
    }
}
