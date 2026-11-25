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
        "premium", "libraries", "libraries-all", "goodreads-same-book", "goodreads-progress",
        "goodreads-not-goodreads", "goodreads-empty",
    ]

    @State private var choices = GoodreadsChoices(preview: .preview)

    var body: some View {
        // The import is a full-screen cover drawn dark (`GoodreadsImportScreen`);
        // only its settings page follows the phone.
        Group {
            if name.hasPrefix("goodreads"), name != "goodreads-source" {
                page.environment(\.colorScheme, .dark)
            } else {
                page
            }
        }
        .defaultScrollAnchor(Self.anchor)
    }

    /// Where a long page opens, after `-showcase-anchor top|center|bottom`:
    /// three captures of one page, stitched into the board's full-length artboard.
    private static var anchor: UnitPoint? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-showcase-anchor"), index + 1 < arguments.count
        else { return nil }
        switch arguments[index + 1] {
        case "center": return .center
        case "bottom": return .bottom
        default: return .top
        }
    }

    @ViewBuilder private var page: some View {
        switch name {
        case "goodreads":
            GoodreadsPreviewPage(preview: .preview, choices: $choices) { _ in }
        case "goodreads-same-book":
            NavigationStack {
                GoodreadsBooksPage(preview: .preview, choices: $choices, filter: .all, onDecide: { _ in })
            }
            .sheet(isPresented: .constant(true)) {
                GoodreadsSameBookSheet(row: GoodreadsPreview.preview.uncertainRows[0], onSame: {}, onDifferent: {})
            }
        case "goodreads-progress":
            NavigationStack {
                GoodreadsProgressPage(
                    covers: GoodreadsPreview.preview.newRows.prefix(5).map(\.cover),
                    done: 640, total: 1424, progress: 0.45, onClose: {}
                )
            }
        case "goodreads-not-goodreads", "goodreads-empty":
            NavigationStack {
                Group {
                    if name == "goodreads-empty" {
                        EmptyState(
                            systemImage: "book",
                            title: "Aucun livre dans ce fichier",
                            message: "Vérifiez que vous étiez connecté au bon compte Goodreads au moment de l'export.",
                            primary: EmptyState.Action("Choisir un autre fichier") {}
                        )
                    } else {
                        EmptyState(
                            systemImage: "doc.questionmark",
                            title: "Ce fichier ne vient pas de Goodreads",
                            message: "Choisissez le fichier goodreads_library_export.csv préparé par Goodreads.",
                            primary: EmptyState.Action("Choisir un autre fichier") {}
                        )
                    }
                }
                .navigationTitle("Goodreads")
                .navigationBarTitleDisplayMode(.inline)
            }
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
