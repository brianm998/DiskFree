import XCTest
@testable import DiskFree

final class LowSpacePulseTests: XCTestCase {
    func testPulsesAfterCrossingThenStops() {
        var s = LowSpacePulseState(cycles: 3)
        XCTAssertFalse(s.isPulsing)
        XCTAssertTrue(s.update(isLow: true, reduceMotion: false))
        XCTAssertTrue(s.isPulsing)
        s.finishCycle(); s.finishCycle()
        XCTAssertTrue(s.isPulsing)
        s.finishCycle()
        XCTAssertFalse(s.isPulsing)
        // staying low does not restart
        XCTAssertFalse(s.update(isLow: true, reduceMotion: false))
        XCTAssertFalse(s.isPulsing)
    }

    func testpulsesAgainAfterRecovery() {
        var s = LowSpacePulseState(cycles: 1)
        s.update(isLow: true, reduceMotion: false)
        s.update(isLow: false, reduceMotion: false)
        XCTAssertFalse(s.isPulsing)
        XCTAssertTrue(s.update(isLow: true, reduceMotion: false))
    }

    func testNeverPulsesWithReduceMotion() {
        var s = LowSpacePulseState()
        XCTAssertFalse(s.update(isLow: true, reduceMotion: true))
        XCTAssertFalse(s.isPulsing)
    }
}
