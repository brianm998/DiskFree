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
        // Launch may still be settling; let the run loop spin until it has.
        let deadline = Date().addingTimeInterval(5)
        while NSApplication.shared.activationPolicy() != .prohibited, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
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
