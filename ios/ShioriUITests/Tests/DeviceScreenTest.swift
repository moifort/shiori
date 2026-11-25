import XCTest

/// Opens one showcase screen and keeps a screenshot of it in the result
/// bundle: the UI-test route to a capture, for a screen that needs taps to
/// reach. A tab alone is quicker through `scripts/device-capture.sh`, which
/// launches the app and captures with `devicectl`, without a test runner.
///
/// Runs on the reader's iPhone as on a simulator: `-showcase` keeps it off
/// the server and off the account (`ShowcaseDevice`). The screen and the
/// appearance come from `xcodebuild test`'s environment:
/// `TEST_RUNNER_SHIORI_SCREEN=library TEST_RUNNER_SHIORI_APPEARANCE=dark`.
@MainActor
final class DeviceScreenTest: XCTestCase {
    func testCaptureScreen() throws {
        let environment = ProcessInfo.processInfo.environment
        let screen = environment["SHIORI_SCREEN"] ?? "home"
        let app = XCUIApplication()
        app.launchArguments = ["-showcase", "-showcase-tab", screen]
        if let appearance = environment["SHIORI_APPEARANCE"] {
            app.launchArguments += ["-showcase-appearance", appearance]
        }
        app.launch()
        defer { app.terminate() }

        // The tab bar is up once the showcase has routed past the launch curtain.
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        Thread.sleep(forTimeInterval: 2)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = screen
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
