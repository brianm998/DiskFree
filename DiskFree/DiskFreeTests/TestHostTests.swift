import XCTest
import AppKit
@testable import DiskFree

final class TestHostTests: XCTestCase {
    func testIsActiveInsideHost() {
        XCTAssertTrue(TestHost.isActive)
    }

    @MainActor
    func testNoVisibleWindows() {
        XCTAssertTrue(NSApplication.shared.windows.filter(\.isVisible).isEmpty)
    }

    @MainActor
    func testActivationPolicyIsProhibited() {
        XCTAssertEqual(NSApplication.shared.activationPolicy(), .prohibited)
    }

    @MainActor
    func testViewModelDoesNotPersist() {
        XCTAssertFalse(ViewModel().persistsToDisk)
    }

    func testPureFunction() {
        XCTAssertFalse(TestHost.isTestHost(environment: ["PATH": "/usr/bin"]))
        for key in TestHost.environmentKeys {
            XCTAssertTrue(TestHost.isTestHost(environment: [key: "x"]), key)
        }
    }
}
