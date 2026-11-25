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
        "goodreads-done", "goodreads-source", "subscription-trial", "subscription-lapsed",
        "premium", "libraries", "libraries-all",
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
        case "subscription-trial", "subscription-lapsed":
            SubscriptionWallPage(
                kind: name == "subscription-trial" ? .trial : .lapsed,
                offers: PremiumOffer.previewOffers, savings: 0.42,
                onBuy: { _ in }, onRestore: {}, onAccount: {}
            )
            .background { CoverVeil(covering: true) }
            .environment(\.colorScheme, .dark)
        case "premium":
            PremiumSheet(trigger: .discover)
                .environment(SubscriptionStore())
                .environment(\.colorScheme, .dark)
        case "libraries", "libraries-all":
            LibrariesOfferPage(
                connectsAudible: .constant(name == "libraries-all"),
                connectsKindle: .constant(name == "libraries-all"),
                importsGoodreads: .constant(name == "libraries-all"),
                marketplace: .constant(.fr),
                onConnect: {},
                onSkip: {}
            )
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
