import XCTest

/// Captures the screens the App Store shows, from the showcase library the app
/// carries in its Debug build (`Shiori/Shared/Showcase.swift`).
///
/// Run through `scripts/screenshots.sh`, which builds the app, boots the
/// 6.9" simulator and puts the scanned cover in its photo library. The app is
/// launched with `-showcase`: no Apple sign-in, no server, the same library on
/// every run.
///
/// Every wait is on an element that only exists once a screen has its data, so
/// a capture never shows a spinner.
@MainActor
final class ScreenshotTest: XCTestCase {
    /// The App Store language the run captures: `fr` or `en`, which
    /// `scripts/screenshots.sh` hands down as `SHIORI_CAPTURE_LANGUAGE`.
    private let language = ProcessInfo.processInfo.environment["SHIORI_CAPTURE_LANGUAGE"] ?? "fr"

    /// The labels the run finds its way by, in the language it captures.
    private var labels: [String: String] {
        language == "en"
            ? [
                "Bibliothèque": "Library", "Découvrir": "Discover", "Partagé": "Shared",
                "Scanner": "Scan", "Accueil": "Home", "Vérifier": "Review",
                "Premium annuel": "Premium Yearly",
            ]
            : [:]
    }

    /// A French label, as the run's language says it.
    private func label(_ french: String) -> String {
        labels[french] ?? french
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Tests/
            .deletingLastPathComponent() // ShioriUITests/
            .deletingLastPathComponent() // ios/
            .deletingLastPathComponent() // repository root
    }

    var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-showcase",
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "en" ? "en_US" : "fr_FR",
            // The search opens on what a reader who uses it sees: books looked
            // at lately and the last searches, read from the defaults.
            "-recently-viewed-books",
            "(dungeon-crawler-carl-5, horde-du-contrevent, projet-derniere-chance, trois-corps, dune, frieren-1, fondation, sapiens)",
            "-library-search-recents", #"(damasio, frieren, "liu cixin")"#,
        ]
        app.launch()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testCaptureAppStoreScreens() throws {
        // Accueil: the reading shelf only exists once the dashboard is drawn.
        try wait(app.descendants(matching: .any)["home-reading"])
        settle()
        save("02-home")

        // The detailed statistics, behind the genres card.
        try tap(app.descendants(matching: .any)["home-genres"].firstMatch, until: app.descendants(matching: .any)["genre-insights"])
        settle()
        save("02-stats")
        closeDetail()
        _ = app.descendants(matching: .any)["genre-insights"].waitForNonExistence(timeout: 5)

        // Bibliothèque, its books as a mosaic of covers.
        try open("Bibliothèque")
        let shelves = app.segmentedControls["library-shelf-picker"]
        try tap(shelves.buttons.element(boundBy: 0), until: app.buttons["library-mode-mosaic"])
        try tap(app.buttons["library-mode-mosaic"], until: app.buttons["book-tile"].firstMatch)
        settle()
        save("01-library")

        // The authors: each with the books held and the sagas they write.
        try tap(shelves.buttons.element(boundBy: 2), until: app.descendants(matching: .any)["author-row"].firstMatch)
        settle()
        save("09-authors")

        // The sagas: their strips of covers, the volumes to come.
        try tap(shelves.buttons.element(boundBy: 1), until: app.descendants(matching: .any)["series-row"].firstMatch)
        settle()
        save("03-series")

        // One saga, its next volume announced under its introduction.
        try tap(app.descendants(matching: .any)["series-row"].firstMatch, until: app.descendants(matching: .any)["series-releases"])
        settle()
        save("04-saga")
        closeDetail()

        try open("Découvrir")
        try wait(app.descendants(matching: .any)["discover-volume-row"].firstMatch)
        settle()
        save("05-discover")

        // One of the month's discoveries: the book Claude chose, and why.
        try tap(
            app.descendants(matching: .any)["discover-suggestion"].firstMatch,
            until: app.descendants(matching: .any)["suggestion-reason"]
        )
        settle()
        save("07-discovery")
        closeDetail()
        _ = app.descendants(matching: .any)["suggestion-reason"].waitForNonExistence(timeout: 5)

        // Further down Découvrir: the friends' favorites and the series' next volumes.
        app.swipeUp()
        settle()
        save("08-discover-more")

        // Découvrir's Séries shelf: each saga followed, its next volume dated.
        let discoverShelves = app.segmentedControls["library-shelf-picker"]
        try tap(
            discoverShelves.buttons.element(boundBy: 1),
            until: app.descendants(matching: .any)["discover-series-row"].firstMatch
        )
        settle()
        save("10-discover-series")

        try open("Partagé")
        try wait(app.descendants(matching: .any)["shared-my-page"])
        settle()
        save("06-shared")

        // The scan: the last photo of the add sheet, a cover, read and filled in.
        try open("Scanner")
        // A fresh install has not been allowed the photos yet: the sheet asks, and
        // the system's alert is answered with full access.
        let permission = app.descendants(matching: .any)["add-book-photos-permission"]
        if permission.waitForExistence(timeout: 3) {
            permission.tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            let allow = springboard.buttons
                .matching(NSPredicate(format: "label CONTAINS[c] 'complet' OR label CONTAINS[c] 'Full Access'"))
                .firstMatch
            try tap(allow)
        }
        try tap(app.descendants(matching: .any)["add-book-recent-photo-0"])
        try wait(app.buttons["review-add"], timeout: 30)
        settle()
        save("00-scan")
        try tap(app.navigationBars[label("Vérifier")].buttons["xmark"])
        _ = app.buttons["review-add"].waitForNonExistence(timeout: 5)

        // The paywall, for App Review: behind the settings, as the review notes say.
        try open("Accueil")
        try tap(app.descendants(matching: .any)["home-settings"])
        try tap(app.descendants(matching: .any)["settings-premium"])
        try wait(app.staticTexts[label("Premium annuel")])
        settle()
        save("paywall")
    }

    /// The search, and the cover picker reached from a book it finds: the
    /// landing page's tour, not the App Store's.
    func testCaptureSearchAndCover() throws {
        try open("Bibliothèque")
        try tap(app.descendants(matching: .any)["library-search"], until: app.descendants(matching: .any)["search-viewed"].firstMatch)
        settle()
        save("11-search")

        let field = app.searchFields.firstMatch
        try tap(field)
        field.typeText("rothfuss")
        let book = app.descendants(matching: .any).matching(identifier: "search-book")
            .matching(NSPredicate(format: "label CONTAINS %@", language == "en" ? "Name of the Wind" : "Nom du vent"))
            .firstMatch
        try tap(book, until: app.descendants(matching: .any)["book-detail-menu"].firstMatch)
        try tap(app.descendants(matching: .any)["book-detail-menu"].firstMatch, until: app.descendants(matching: .any)["book-cover"].firstMatch)
        try tap(app.descendants(matching: .any)["book-cover"].firstMatch, until: app.buttons["cover-choose"])
        let other = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", language == "en" ? "Other edition" : "Autre édition")).firstMatch
        try tap(other)
        settle()
        save("12-cover")
    }

    // MARK: - Steps


    /// A screen that never came: the run stops there rather than photograph it.
    private struct Missing: Error {}

    /// A tab by its French label, translated for the run: the tab bar has no
    /// identifiers a `Tab` reliably hands down to its button.
    private func open(_ french: String) throws {
        let tab = label(french)
        let button = app.tabBars.buttons[tab].firstMatch
        if button.waitForExistence(timeout: 5) {
            button.tap()
        } else {
            try tap(app.buttons[tab].firstMatch)
        }
    }

    /// Leaves the detail on screen: a page pushed on a phone goes back, one
    /// set beside the list on an unfolded iPhone Duo closes by its button.
    private func closeDetail() {
        let close = app.navigationBars.buttons["xmark"].firstMatch
        if close.waitForExistence(timeout: 2) { return close.tap() }
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
    }

    private func element(labelled text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    private func wait(_ element: XCUIElement, timeout: TimeInterval = 15) throws {
        guard element.waitForExistence(timeout: timeout) else {
            // What was on screen instead, for whoever reads the failure.
            try? app.debugDescription.write(
                toFile: "/tmp/shiori-screenshot-tree.txt", atomically: true, encoding: .utf8
            )
            XCTFail("never appeared: \(element), screen tree in /tmp/shiori-screenshot-tree.txt")
            throw Missing()
        }
    }

    private func tap(_ element: XCUIElement, ifPresent: Bool = false) throws {
        guard element.waitForExistence(timeout: ifPresent ? 2 : 15) else {
            if ifPresent { return }
            // What was on screen instead, for whoever reads the failure.
            try? app.debugDescription.write(
                toFile: "/tmp/shiori-screenshot-tree.txt", atomically: true, encoding: .utf8
            )
            XCTFail("never appeared: \(element), screen tree in /tmp/shiori-screenshot-tree.txt")
            throw Missing()
        }
        element.tap()
    }

    /// Taps until the screen it leads to is there: a tap landing while a tab
    /// is still sliding in is dropped.
    private func tap(_ element: XCUIElement, until target: XCUIElement) throws {
        for _ in 0..<4 {
            try tap(element)
            if target.waitForExistence(timeout: 4) { return }
        }
        try wait(target, timeout: 1)
    }

    /// The covers are read off disk and fade in: a beat for them to land.
    private func settle() {
        Thread.sleep(forTimeInterval: 1.5)
    }

    /// Writes straight into the working copy through `#filePath`, which ties
    /// the run to a simulator on the Mac holding the repository: the only
    /// place it ever runs. `SHIORI_CAPTURE_DIR` sends a run on another device
    /// elsewhere, so checking a layout never overwrites the App Store captures.
    private func save(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let directory = ProcessInfo.processInfo.environment["SHIORI_CAPTURE_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? repositoryRoot.appending(path: "screenshots/captures/\(language)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: directory.appending(path: "\(name).png"))
        } catch {
            XCTFail("could not save \(name) to \(directory.path): \(error)")
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
