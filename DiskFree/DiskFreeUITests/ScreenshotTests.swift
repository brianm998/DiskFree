//
//  ScreenshotTests.swift
//
//  Captures the App Store screenshots.  Run by scripts/screenshots.sh, which
//  extracts the attachments from the .xcresult.  The app is launched with
//  -screenshotMode so it shows deterministic demo volumes, never real disks.
//

import XCTest

final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func capture(name: String, extraArguments: [String]) throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-screenshotMode",
            // pin the window to the main display; a frame autosaved on another
            // (possibly absent or asleep) display makes the window unreachable
            "-NSWindow Frame DiskFree.ContentView-1-AppWindow-1", "300 300 1440 900 0 0 2560 1415",
            "-ApplePersistenceIgnoreState", "YES",
        ] + extraArguments
        app.launch()

        let window = app.windows.firstMatch
        if !window.waitForExistence(timeout: 30) { print("DEBUG-HIER", app.debugDescription) }
        XCTAssertTrue(window.exists)
        // let charts finish laying out
        Thread.sleep(forTimeInterval: 2)

        let attachment = XCTAttachment(screenshot: window.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

    }

    @MainActor
    func testCombinedLayout() throws {
        try capture(name: "01-combined", extraArguments: ["-screenshotLayout", "combined"])
    }

    @MainActor
    func testSeparateLayout() throws {
        try capture(name: "02-separate", extraArguments: ["-screenshotLayout", "separate"])
    }

    @MainActor
    func testSettings() throws {
        try capture(name: "03-settings", extraArguments: ["-screenshotLayout", "combined", "-screenshotSettings"])
    }
}
