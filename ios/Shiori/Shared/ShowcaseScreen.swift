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
                "site-book", "series", "shelf", "scan-review", "player", "wishlist", "pile",
        "agenda", "news-full", "suggestion", "awaited-series",
        "onboarding-audible", "onboarding-kindle", "onboarding-goodreads",
        "onboarding-audible-connected", "onboarding-audible-failed", "onboarding-amazon",
    ]

    @State private var choices = GoodreadsChoices(preview: .preview)

    /// Five showcase covers standing on a dark shelf, the photo a shelf scan
    /// starts from; the boxes of `shelfBooks` frame them.
    private static let shelfSlugs = ["dune", "messie-de-dune", "fondation", "sorceleur-01", "etranger"]

    /// The photo's size, and each cover's: a 2:3 book standing on the plank.
    private static let shelfSize = CGSize(width: 1080, height: 470)
    private static let coverSize = CGSize(width: 196, height: 294)

    private static let shelfPhoto: UIImage = {
        UIGraphicsImageRenderer(size: shelfSize).image { context in
            let cg = context.cgContext
            // The back of the shelf, warm wood in low light.
            let wall = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.20, green: 0.14, blue: 0.10, alpha: 1).cgColor,
                    UIColor(red: 0.33, green: 0.23, blue: 0.15, alpha: 1).cgColor,
                ] as CFArray,
                locations: [0, 1]
            )!
            cg.drawLinearGradient(wall, start: .zero, end: CGPoint(x: 0, y: shelfSize.height), options: [])
            // The plank the books stand on.
            UIColor(red: 0.45, green: 0.31, blue: 0.19, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 392, width: shelfSize.width, height: 78))
            UIColor(red: 0.56, green: 0.40, blue: 0.25, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 392, width: shelfSize.width, height: 8))
            for (index, slug) in shelfSlugs.enumerated() {
                let box = shelfBox(index)
                let rect = CGRect(
                    x: box.minX * shelfSize.width, y: box.minY * shelfSize.height,
                    width: box.width * shelfSize.width, height: box.height * shelfSize.height
                )
                cg.saveGState()
                cg.setShadow(offset: CGSize(width: 0, height: 8), blur: 18, color: UIColor.black.withAlphaComponent(0.6).cgColor)
                UIColor.black.setFill()
                cg.fill(rect)
                cg.restoreGState()
                if let url = Showcase.cover(slug), let image = UIImage(contentsOfFile: url.path) {
                    // Aspect-filled into the 2:3 box, never stretched.
                    let scale = max(rect.width / image.size.width, rect.height / image.size.height)
                    let drawn = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                    cg.saveGState()
                    cg.clip(to: rect)
                    image.draw(in: CGRect(
                        x: rect.midX - drawn.width / 2, y: rect.midY - drawn.height / 2,
                        width: drawn.width, height: drawn.height
                    ))
                    cg.restoreGState()
                }
            }
        }
    }()

    private static func shelfBox(_ index: Int) -> CGRect {
        let gap = (shelfSize.width - 5 * coverSize.width) / 6
        let x = gap + Double(index) * (coverSize.width + gap)
        let y = 392 - coverSize.height
        return CGRect(
            x: x / shelfSize.width, y: y / shelfSize.height,
            width: coverSize.width / shelfSize.width, height: coverSize.height / shelfSize.height
        )
    }

    /// A page inside the app's tab bar, on the tab it lives under, as the
    /// reader sees it: the other tabs stand empty, nothing is ever tapped.
    private func inTab(_ tab: TabSelection, @ViewBuilder _ page: () -> some View) -> some View {
        let content = page()
        return TabView(selection: .constant(tab)) {
            ForEach([TabSelection.home, .library, .news, .friends]) { item in
                Tab(item.label, systemImage: item.symbol, value: item) {
                    if item == tab { content } else { Color.clear }
                }
            }
            Tab(
                TabSelection.scan.label, systemImage: TabSelection.scan.symbol,
                value: TabSelection.scan, role: Self.scanRole
            ) {
                Color.clear
            }
        }
    }

    /// The scan tab's role, as ContentView sets it.
    private static var scanRole: TabRole {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) { return .prominent }
        #endif
        return .search
    }

    /// Actu from its fixtures: the agenda with its large cards, the friends'
    /// news, the month's discoveries and the awards.
    private static var newsAgenda: NewsAgenda {
        NewsAgenda(
            released: NewsFeedLayout.released(
                releases: UpcomingRelease.releasedPreviews.map(siteRelease), narrator: [.preview], format: nil
            ),
            events: FeedEvent.previews + FeedEvent.sameStartPreviews,
            upcoming: ReleaseCalendar(releases: UpcomingRelease.previews.map(siteRelease), now: .now).dated,
            suggestions: MonthlyDiscoveries.preview.suggestions,
            awards: AwardSection.previews.map { section in
                AwardSection(genre: section.genre, winners: section.winners.map { winner in
                    var winner = winner
                    let slug = winner.release.title == "La Maison vide" ? "maison-vide" : "buffalo-hunter"
                    winner.release.coverURL = Showcase.cover(slug)
                    return winner
                })
            }
        )
    }

    /// The fixtures' Berserk, a manga, turned into the Three-Body trilogy for
    /// the site, on the showcase's own covers.
    private static func siteRelease(_ release: UpcomingRelease) -> UpcomingRelease {
        guard release.seriesName == "Berserk" else { return release }
        let second = release.volume == 42
        let series = Showcase.local("Le Problème à trois corps", "The Three-Body Problem")
        return UpcomingRelease(
            id: release.id.replacingOccurrences(of: "berserk", with: "trois-corps"),
            source: release.source, format: .book,
            title: second
                ? Showcase.local("La Forêt sombre", "The Dark Forest")
                : Showcase.local("La Mort immortelle", "Death's End"),
            authors: ["Liu Cixin"], date: release.date,
            coverURL: Showcase.cover(second ? "foret-sombre" : "mort-immortelle"),
            seriesName: series, volume: second ? 2 : 3, author: release.author,
            sagaRating: release.sagaRating, sagaFavorite: release.sagaFavorite
        )
    }

    /// A wishlist full enough to read as one, on the showcase's own covers.
    private static let wishlist: Wishlist = {
        func wish(
            _ slug: String, _ title: String, _ author: String, _ origin: Wish.Origin,
            _ label: String? = nil, days: Double
        ) -> Wish {
            Wish(
                id: slug, title: title, authors: [author], format: .book, language: Showcase.language,
                seriesName: nil, volume: nil, coverURL: Showcase.cover(slug), isbn13: nil,
                origin: origin, originLabel: label, friendId: label, wishedAt: Showcase.daysAgo(days)
            )
        }
        func awaited(
            _ slug: String, _ title: String, _ author: String, _ format: ReleaseFormat,
            _ state: AwaitedState, _ date: String?
        ) -> AwaitedEdition {
            AwaitedEdition(
                id: slug, format: format, state: state, title: title, originalTitle: title,
                originalLanguage: .en, authors: [author], date: date, coverURL: Showcase.cover(slug),
                storeURL: nil, awaitedAt: .now, bookId: slug, ownerId: "me"
            )
        }
        func local(_ french: String, _ english: String) -> String { Showcase.local(french, english) }
        return Wishlist(
            wishes: [
                wish("hyperion", local("Hypérion", "Hyperion"), "Dan Simmons", .friend, local("Camille", "Chloe"), days: 1),
                wish("nom-du-vent", local("Le Nom du vent", "The Name of the Wind"), "Patrick Rothfuss", .friend, local("Hugo", "Jack"), days: 2),
                wish("horde-du-contrevent", local("La Horde du Contrevent", "The Wind Chasers"), "Alain Damasio", .friend, local("Léa", "Emma"), days: 3),
                wish("murderbot", local("Journal d'un AssaSynth", "All Systems Red"), "Martha Wells", .friend, local("Camille", "Chloe"), days: 4),
                wish("foret-sombre", local("La Forêt sombre", "The Dark Forest"), "Liu Cixin", .discovery, days: 5),
                wish("leviathan", local("L'Éveil du Léviathan", "Leviathan Wakes"), "James S. A. Corey", .award, "Hugo", days: 6),
                wish("main-gauche-nuit", local("La Main gauche de la nuit", "The Left Hand of Darkness"), "Ursula K. Le Guin", .award, "Nebula", days: 7),
                wish("depossedes", local("Les Dépossédés", "The Dispossessed"), "Ursula K. Le Guin", .author, days: 8),
                wish("fondation", local("Fondation", "Foundation"), "Isaac Asimov", .scan, days: 9),
                wish("rama", local("Rendez-vous avec Rama", "Rendezvous with Rama"), "Arthur C. Clarke", .scan, days: 10),
                wish("ender", local("La Stratégie Ender", "Ender's Game"), "Orson Scott Card", .scan, days: 11),
            ],
            awaited: [
                awaited("one-piece-114", local("One Piece, tome 114", "One Piece, Vol. 114"), "Eiichiro Oda", .book, .announced, dayFromNow(9)),
                awaited("frieren-15", local("Frieren, tome 15", "Frieren, Vol. 15"), "Kanehito Yamada", .book, .announced, dayFromNow(23)),
                awaited("golden-son", "Golden Son", "Pierce Brown", .audiobook, .available, dayFromNow(-6)),
                awaited("morning-star", "Morning Star", "Pierce Brown", .audiobook, .available, dayFromNow(-20)),
            ]
        )
    }()

    private static func dayFromNow(_ days: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        return date.formatted(.iso8601.year().month().day())
    }

    private static let shelfBooks: [DetectedBook] = {
        let fr = Showcase.language == .fr
        let rows: [(String?, [String], String?, Int?, Bool)] = [
            ("Dune", ["Frank Herbert"], "Dune", 1, false),
            (fr ? "Le Messie de Dune" : "Dune Messiah", ["Frank Herbert"], "Dune", 2, false),
            (fr ? "Fondation" : "Foundation", ["Isaac Asimov"], nil, nil, true),
            (nil, [], nil, nil, false),
            (fr ? "L'Étranger" : "The Stranger", ["Albert Camus"], nil, nil, false),
        ]
        return rows.enumerated().map { index, row in
            DetectedBook(
                id: index, title: row.0, authors: row.1, publisher: nil, language: nil,
                format: nil, seriesName: row.2, volume: row.3, box: shelfBox(index), owned: row.4
            )
        }
    }()

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
        case "onboarding-audible", "onboarding-kindle", "onboarding-goodreads":
            // The onboarding's step for one library, before its sign-in.
            let library = OnboardingLibrary(rawValue: String(name.dropFirst("onboarding-".count))) ?? .audible
            let number = (OnboardingLibrary.allCases.firstIndex(of: library) ?? 0) + 1
            LibraryStepPage(
                library: library, number: number, count: 3,
                next: OnboardingLibrary.allCases.dropFirst(number).first,
                onPrimary: {}, onSecondary: {}
            )
            .background { CoverVeil(covering: true) }
            .environment(\.colorScheme, .dark)
        case "onboarding-audible-connected", "onboarding-audible-failed":
            LibraryStepPage(
                library: .audible, number: 1, count: 3,
                phase: name.hasSuffix("connected") ? .connected : .failed, next: .kindle,
                onPrimary: {}, onSecondary: {}
            )
            .background { CoverVeil(covering: true) }
            .environment(\.colorScheme, .dark)
        case "onboarding-amazon":
            // Amazon's sheet over the Audible step, its page left blank: the
            // showcase never reaches Amazon.
            LibraryStepPage(library: .audible, number: 1, count: 3, next: .kindle, onPrimary: {}, onSecondary: {})
                .background { CoverVeil(covering: true) }
                .environment(\.colorScheme, .dark)
                .sheet(isPresented: .constant(true)) {
                    AmazonSignInSheet(
                        login: AmazonLogin(url: "about:blank", redirectURL: "about:blank", cookies: []),
                        onCode: { _ in }, onCancel: {},
                        source: .audible, subtitle: "sur amazon.fr · étape 1 sur 3"
                    )
                    .environment(\.colorScheme, .dark)
                }
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
        case "site-book":
            inTab(.library) { NavigationStack { BookPage(previewing: Showcase.featured) } }
        case "series":
            let screen = SeriesFixtures.screen
            inTab(.library) { NavigationStack {
                SeriesPage(
                    series: screen.series, owned: screen.owned, opinion: screen.opinion,
                    isLoading: false, errorMessage: nil, language: Showcase.language, friend: nil,
                    isFollowed: true, addingTitle: nil,
                    releases: Showcase.sagaReleases(seriesId: SeriesFixtures.followed[0].seriesId),
                    takenFormat: .book, announcedVolume: { _ in nil }
                ) { _ in }
            } }
        case "shelf":
            NavigationStack {
                ShelfChecklistPage(
                    photo: Self.shelfPhoto, books: Self.shelfBooks,
                    ticked: [0, 1, 4], remainingScans: 24, crop: { _ in nil }
                ) { _ in }
            }
        case "scan-review":
            NavigationStack {
                ScanReviewPage(
                    draft: BookDraft(
                        title: Showcase.local("L'Œil de la Veuve du Chaos", "The Eye of the Bedlam Bride"),
                        authors: ["Matt Dinniman"],
                        publisher: Showcase.local("Bragelonne", "Ace"),
                        firstPublishedIn: 2023,
                        synopsis: Showcase.local(
                            """
                            Sixième étage du donjon : Carl et Princesse Beignet affrontent un \
                            immense jeu de chasse où chaque proie peut devenir chasseur, pendant \
                            que les spectateurs de la galaxie parient sur leur survie.
                            """,
                            """
                            The sixth floor of the dungeon: Carl and Princess Donut face a vast \
                            hunting game where any prey can turn hunter, while the galaxy's \
                            viewers bet on their survival.
                            """
                        ),
                        genre: .scienceFiction,
                        subgenres: ["LitRPG"],
                        pageCount: 712,
                        coverURL: Showcase.cover("dcc-06"),
                        series: SeriesMembership(
                            id: "dungeon-crawler-carl", name: "Dungeon Crawler Carl",
                            volume: 6, kind: .main
                        )
                    ),
                    isSaving: false,
                    sagaVolumes: Showcase.seriesPage(limit: 200, after: nil, mode: .all, state: nil)
                        .items.first { $0.seriesId == "dungeon-crawler-carl" }?.strip ?? []
                ) { _ in }
            }
        case "player":
            PlayerPage(item: .preview) { _ in }
        case "wishlist":
            inTab(.library) { NavigationStack {
                WishlistPage(
                    wishlist: Self.wishlist, formats: [.book, .audiobook], isLoading: false,
                    errorMessage: nil
                ) { _ in }
                .toolbarTitleDisplayMode(.inlineLarge)
            } }
        case "pile":
            let pile = Showcase.pile(view: ShelvesView())
            inTab(.library) { NavigationStack {
                PilePage(
                    pile: pile,
                    upNext: Showcase.seriesPage(limit: 200, after: nil, mode: .all, state: nil)
                        .items.filter { !$0.isSetAside }.upNext,
                    genres: pile.genres, isLoading: false, errorMessage: nil
                ) { _ in }
            } }
        case "awaited-series":
            // An edition awaited from a scan, with no copy on the shelf: the
            // saga's row still comes, from the saga the server names on it.
            let edition = Self.awaitedWithSaga
            let shown = Self.awaitedWithSagaShown
            let row = ReleaseSaga.row(Self.dungeonCrawlerCarlLacking, placing: shown)
            inTab(.library) { NavigationStack {
                AwaitedEditionPage(
                    edition: edition,
                    shown: shown,
                    isDescribing: false,
                    sagaVolumes: row.volumes,
                    sagaCurrentId: row.currentId
                ) { _ in }
            } }
        case "suggestion":
            if let suggestion = Showcase.monthlyDiscoveries.suggestions.first {
                inTab(.home) { NavigationStack {
                    SuggestionPage(
                        suggestion: suggestion, shown: suggestion.cover, isDescribing: false,
                        choices: DiscoveryChoices(), onChoice: { _, _ in true }
                    ) { _ in }
                } }
            }
        case "agenda", "news-full":
            inTab(.news) { NavigationStack {
                NewsPage(
                    agenda: name == "agenda" ? Self.newsAgenda.agendaOnly(cards: 3) : Self.newsAgenda,
                    isLoading: false, errorMessage: nil, alertsSilenced: false, onAction: { _ in }
                )
            } }
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

#if DEBUG
extension ShowcaseScreen {
    /// Dungeon Crawler Carl's sixth volume awaited as a recording from a scan,
    /// no copy on the shelf.
    static var awaitedWithSaga: AwaitedEdition {
        var edition = AwaitedEdition(
            id: "dcc-06-audio", format: .audiobook, state: .unannounced,
            title: Showcase.local("L'Œil de la Veuve du Chaos", "The Eye of the Bedlam Bride"),
            originalTitle: "The Eye of the Bedlam Bride", originalLanguage: .en,
            authors: ["Matt Dinniman"], date: nil, coverURL: Showcase.cover("dcc-06"), storeURL: nil,
            awaitedAt: .now, bookId: nil, ownerId: "me"
        )
        edition.release.series = SeriesMembership(
            id: "dungeon-crawler-carl--matt-dinniman--audio~fr", name: "Dungeon Crawler Carl",
            volume: 6, kind: .main
        )
        return edition
    }

    /// The edition as its page draws it once described.
    static var awaitedWithSagaShown: Book {
        var shown = awaitedWithSaga.cover
        shown.synopsis = Showcase.local(
            "Septième étage du donjon : Carl et Princesse Beignet affrontent un immense jeu de chasse.",
            "The dungeon's next floor: Carl and Princess Donut face a vast hunting game."
        )
        return shown
    }

    /// The saga as its catalogue lists it, none of it held.
    static var dungeonCrawlerCarlLacking: [SeriesStripItem] {
        let titles = Showcase.local(
            ["Dungeon Crawler Carl", "Carl's Doomsday Scenario", "The Dungeon Anarchist's Cookbook",
             "The Gate of the Feral Gods", "The Butcher's Masquerade", "L'Œil de la Veuve du Chaos",
             "This Inevitable Ruin"],
            ["Dungeon Crawler Carl", "Carl's Doomsday Scenario", "The Dungeon Anarchist's Cookbook",
             "The Gate of the Feral Gods", "The Butcher's Masquerade", "The Eye of the Bedlam Bride",
             "This Inevitable Ruin"]
        )
        return titles.enumerated().map { index, title in
            let number = index + 1
            return .missing(
                key: "dcc-\(number)", number: number, title: title, forthcoming: number == 7,
                date: number == 7 ? "2026-12-11" : nil,
                coverURL: number <= 6 ? Showcase.cover(String(format: "dcc-%02d", number)) : nil
            )
        }
    }
}
#endif
