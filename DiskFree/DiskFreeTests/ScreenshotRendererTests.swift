import XCTest
import AppKit
@testable import DiskFree

@MainActor
final class ScreenshotRendererTests: XCTestCase {
    func testOutputDirectoryArgument() {
        XCTAssertEqual(ScreenshotRenderer.outputDirectory(arguments: ["x", "-renderScreenshots", "/tmp/o"]), "/tmp/o")
        XCTAssertNil(ScreenshotRenderer.outputDirectory(arguments: ["x"]))
    }

    func testDemoDataIsDeterministicAndDemoOnly() {
        let vm = ViewModel(demo: true)
        XCTAssertTrue(vm.isDemo)
        XCTAssertFalse(vm.localVolumes.isEmpty)
        XCTAssertFalse(ViewModel().isDemo)
    }

    func testRendersThreeViewsAt2880x1800() throws {
        let views = ScreenshotRenderer.screenshotViews()
        XCTAssertEqual(views.count, 3)
        for (name, view) in views {
            let data = try XCTUnwrap(ScreenshotRenderer.pngData(for: view), name)
            let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
            XCTAssertEqual(rep.pixelsWide, 2880, name)
            XCTAssertEqual(rep.pixelsHigh, 1800, name)
        }
    }
}
