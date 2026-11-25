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
        "goodreads-not-goodreads", "goodreads-empty", "player-sleep", "settings", "preparation", "kindle", "audible",
        "kindle-library", "audible-library", "kindle-source", "audible-source", "review",
        "scan-no-result", "scan-failed", "shelf-checklist", "settings-blocked", "premium-spent",
        "book", "author-work", "reading-progress",
    ]

    @State private var choices = GoodreadsChoices(preview: .preview)

    var body: some View {
        // The imports and the scan are drawn dark (`GoodreadsImportScreen`,
        // `KindleImportScreen`, `ScanScreen`…); the settings pages follow the phone.
        Group {
            if Self.drawnDark.contains(name) || (name.hasPrefix("goodreads") && name != "goodreads-source") {
                page
                    .background(Color(.systemBackground).ignoresSafeArea())
                    .environment(\.colorScheme, .dark)
            } else {
                page
            }
        }
        .defaultScrollAnchor(Self.anchor)
    }

    /// Pages whose screen is always drawn dark, whatever the phone is set to.
    private static let drawnDark: Set<String> = [
        "kindle", "audible", "kindle-library", "audible-library", "kindle-source", "audible-source",
        "review", "scan-no-result", "scan-failed", "shelf-checklist",
    ]

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

    /// Two Audible titles, one already on the shelf, as the page's preview has them.
    private static let audibleBooks = [
        ImportableBook(
            asin: "B002V1OF70", title: "Le Nom du vent", authors: ["Patrick Rothfuss"],
            narrators: ["Bernard Gabay"], durationMinutes: 1770, coverURL: nil,
            seriesName: "Chronique du tueur de roi", volume: 1, status: .read, finishedAt: nil,
            alreadyInLibrary: false
        ),
        ImportableBook(
            asin: "B00X57B4KE", title: "La Peur du sage", authors: ["Patrick Rothfuss"],
            narrators: ["Bernard Gabay"], durationMinutes: 2460, coverURL: nil,
            seriesName: "Chronique du tueur de roi", volume: 2, status: .toRead, finishedAt: nil,
            alreadyInLibrary: true
        ),
    ]

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
        case "premium", "premium-spent":
            PremiumSheet(trigger: name == "premium" ? .discover : .scanAllowanceSpent)
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
        case "player-sleep":
            PlayerPage(item: .preview.withSleep(20)) { _ in }
                .environment(\.colorScheme, .dark)
        case "settings", "settings-blocked":
            // A subscriber's settings: behind the wall, every reader is one.
            NavigationStack {
                SettingsHomePage(
                    profileSubtitle: "lecteur@example.com", isPremium: true,
                    notificationsBlocked: name == "settings-blocked",
                    appVersion: "1.4", buildNumber: "212"
                ) { _ in }
            }
        case "preparation":
            // The end of an onboarding that started a Goodreads import, as
            // `LibraryPreparationView` lays it out, its lines at a fixed point.
            ZStack {
                CoverWall()
                CoverVeil(covering: true)
                VStack(spacing: 0) {
                    Text("Préparation de votre bibliothèque")
                        .font(.headline)
                        .padding(.bottom, 20)
                    PreparationChecklist(lines: [
                        PreparationLine(id: "profile", label: "Votre profil", state: .done),
                        PreparationLine(id: "scans", label: "Vos scans de bienvenue", state: .done),
                        PreparationLine(id: "audible", label: "Votre bibliothèque Audible", state: .done),
                        PreparationLine(
                            id: "goodreads", label: "Votre bibliothèque Goodreads", state: .working,
                            detail: String(localized: "\(640) couvertures sur \(1424)")
                        ),
                        PreparationLine(id: "home", label: "Votre accueil", state: .waiting),
                    ])
                }
                .padding(.horizontal, 20)
            }
            .environment(\.colorScheme, .dark)
        case "kindle":
            NavigationStack { KindleConnectPage(marketplace: .constant(.fr), isWorking: false, onConnect: {}) }
        case "audible":
            NavigationStack { AudibleConnectPage(marketplace: .constant(.fr), isWorking: false, onConnect: {}) }
        case "kindle-library":
            NavigationStack {
                KindleLibraryPage(
                    books: ImportableKindleBook.previews, isLoading: false, isImporting: false,
                    selectedCount: 2, canImport: true, isSelected: { !$0.alreadyInLibrary },
                    onToggle: { _ in }, onSelectAll: {}, onDeselectAll: {}, onImport: {}
                )
            }
        case "audible-library":
            NavigationStack {
                AudibleLibraryPage(
                    books: Self.audibleBooks, isLoading: false, isImporting: false,
                    selectedCount: 1, canImport: true, isSelected: { !$0.alreadyInLibrary },
                    onToggle: { _ in }, onSelectAll: {}, onDeselectAll: {}, onImport: {}
                )
            }
        case "kindle-source":
            NavigationStack {
                KindleSourcePage(
                    account: .preview, totalCount: 1424, catalogedCount: 1203, isLoading: false,
                    isSyncing: false, lastSyncOutcome: SyncOutcome(imported: 1, updated: 2),
                    onAutoSyncChange: { _ in }, onSyncNow: {}, onPickBooks: {}, onReconnect: {},
                    onDisconnect: {}
                )
            }
        case "audible-source":
            NavigationStack {
                AudibleSourcePage(
                    account: AudibleAccount(
                        marketplace: .fr, connectedAt: Date().addingTimeInterval(-86400 * 40),
                        lastImportedAt: Date().addingTimeInterval(-86400 * 2), autoSync: true
                    ),
                    totalCount: 128, catalogedCount: 124, isLoading: false, isSyncing: false,
                    lastSyncOutcome: SyncOutcome(imported: 2, updated: 1),
                    onAutoSyncChange: { _ in }, onSyncNow: {}, onPickBooks: {}, onDisconnect: {}
                )
            }
        case "review":
            NavigationStack {
                ScanReviewPage(
                    draft: BookDraft(
                        title: "Le Nom du vent", authors: ["Patrick Rothfuss"], publisher: "Bragelonne",
                        firstPublishedIn: 2007, synopsis: "Kvothe raconte sa propre légende.",
                        genre: .fantasy, subgenres: ["Roman initiatique"], pageCount: 662,
                        isbn13: "9782352943556",
                        series: SeriesMembership(id: "kkc", name: "Chronique du tueur de roi", volume: 1, kind: .main)
                    ),
                    isSaving: false, awaitable: [.audiobook]
                ) { _ in }
            }
        case "book":
            NavigationStack { BookPage(previewing: .preview) }
        case "author-work":
            NavigationStack {
                AuthorWorkPage(
                    work: AuthorWork(title: "Le Prince bâtard", publishedIn: 2013, coverURL: nil),
                    author: "Robin Hobb", isAdding: false
                ) {}
            }
        case "reading-progress":
            Color.clear.sheet(isPresented: .constant(true)) {
                ReadingProgressSheet(current: 214, pageCount: 662) { _, _ in nil }
            }
        case "scan-no-result":
            ScanNoResultPage(onRetake: {}, onDismiss: {})
        case "scan-failed":
            ScanFailedPage(reason: "La requête a expiré.", onRetry: {}, onRetake: {})
        case "shelf-checklist":
            NavigationStack {
                ShelfChecklistPage(
                    photo: ShelfImportFixtures.photo, books: ShelfImportFixtures.books,
                    ticked: ShelfImportFixtures.ticked, remainingScans: 94, crop: { _ in nil }
                ) { _ in }
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
