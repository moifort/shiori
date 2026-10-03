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
    /// The App Store language the run captures. French alone for now: the app
    /// has no string catalogue yet.
    private let language = "fr"

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
            "-AppleLocale", "fr_FR",
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

        // Bibliothèque, its books as a mosaic of covers.
        try open("Bibliothèque")
        let shelves = app.segmentedControls["library-shelf-picker"]
        try tap(shelves.buttons.element(boundBy: 0), until: app.buttons["library-mode-mosaic"])
        try tap(app.buttons["library-mode-mosaic"], until: app.buttons["book-tile"].firstMatch)
        settle()
        save("01-library")

        // The sagas: their strips of covers, the volumes to come.
        try tap(shelves.buttons.element(boundBy: 1), until: app.descendants(matching: .any)["series-row"].firstMatch)
        settle()
        save("03-series")

        // One saga, its next volume announced under its introduction.
        try tap(app.descendants(matching: .any)["series-row"].firstMatch, until: app.descendants(matching: .any)["series-releases"])
        settle()
        save("04-saga")
        // A sheet when it is one, closed by its own button; pushed, the tab bar stays.
        try tap(app.navigationBars.buttons["xmark"].firstMatch, ifPresent: true)

        try open("Découvrir")
        try wait(app.descendants(matching: .any)["discover-volume-row"].firstMatch)
        settle()
        save("05-discover")

        try open("Partagé")
        try wait(app.descendants(matching: .any)["shared-my-page"])
        settle()
        save("06-shared")

        // The scan: the last photo of the add sheet, a cover, read and filled in.
        try open("Scanner")
        try tap(app.descendants(matching: .any)["add-book-recent-photo-0"])
        try wait(app.buttons["review-save"], timeout: 30)
        settle()
        save("00-scan")
        try tap(app.navigationBars["Vérifier"].buttons["xmark"])
        _ = app.buttons["review-save"].waitForNonExistence(timeout: 5)

        // The paywall, for App Review: behind the settings, as the review notes say.
        try open("Accueil")
        try tap(app.descendants(matching: .any)["home-settings"])
        try tap(app.descendants(matching: .any)["settings-premium"])
        try wait(app.staticTexts["Premium annuel"])
        settle()
        save("paywall")
    }

    // MARK: - Steps

    /// A screen that never came: the run stops there rather than photograph it.
    private struct Missing: Error {}

    /// A tab by its label: the run is French, and the tab bar has no
    /// identifiers a `Tab` reliably hands down to its button.
    private func open(_ tab: String) throws {
        let button = app.tabBars.buttons[tab].firstMatch
        if button.waitForExistence(timeout: 5) {
            button.tap()
        } else {
            try tap(app.buttons[tab].firstMatch)
        }
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
    /// place it ever runs.
    private func save(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let directory = repositoryRoot.appending(path: "screenshots/captures/\(language)")
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
