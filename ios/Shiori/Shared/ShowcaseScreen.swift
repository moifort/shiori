#if DEBUG
import SwiftUI

/// A page deeper than a tab, opened alone from its fixtures by
/// `-showcase-screen <name>`, so `scripts/device-capture.sh` captures it on the
/// iPhone without a tap. The names are Android's `preview` extras
/// (`DebugPreviews.kt`), so one name opens the same page on both.
struct ShowcaseScreen: View {
    let name: String

    /// The names this view draws; any other leaves the app on its tabs.
    static let names: Set<String> = [
        "goodreads", "goodreads-explain", "goodreads-reading", "goodreads-books",
        "goodreads-done", "goodreads-source",
    ]

    @State private var choices = GoodreadsChoices(preview: .preview)

    var body: some View {
        switch name {
        case "goodreads":
            GoodreadsPreviewPage(preview: .preview, choices: $choices) { _ in }
        case "goodreads-explain":
            NavigationStack { GoodreadsExplainPage(onChooseFile: {}, onOpenGoodreads: {}) }
        case "goodreads-reading":
            GoodreadsReadingPage(lines: GoodreadsReadingPage.lines(found: .preview, reading: false))
        case "goodreads-books":
            NavigationStack {
                GoodreadsBooksPage(preview: .preview, choices: $choices, filter: .all, onDecide: { _ in })
            }
        case "goodreads-done":
            NavigationStack {
                GoodreadsDonePage(
                    outcome: .preview, preview: .preview, choices: choices, onShowLibrary: {}
                )
            }
        default:
            NavigationStack {
                GoodreadsSourcePage(summary: .preview, isLoading: false, onImport: {}, onHowTo: {})
            }
        }
    }
}
#endif
