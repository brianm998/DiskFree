import Testing
import Foundation
@testable import DiskFree

struct PreferencesTests {
    @Test func defaults() {
        let p = Preferences()
        #expect(p.lowSpaceWarningThresholdGigs == 100)
        #expect(p.lowSpaceErrorThresholdGigs == 20)
        #expect(p.localPollIntervalSeconds == 4)
        #expect(p.networkPollIntervalSeconds == 30)
        #expect(p.maxDataAgeMinutes == 60)
        #expect(p.localVolumesToShow.isEmpty)
        #expect(p.networkVolumesToShow.isEmpty)
        #expect(p.showFreeSpace)
        #expect(!p.showUsedSpace)
    }

    @Test func jsonRoundTrip() throws {
        var p = Preferences()
        p.localVolumesToShow = ["/Volumes/a", "/"]
        p.networkVolumesToShow = ["/mnt/root"]
        p.localPollIntervalSeconds = 9
        p.lowSpaceWarningThresholdGigs = 250
        p.showUsedSpace = true
        p.maxDataAgeMinutes = 15
        let data = try JSONEncoder().encode(p)
        let q = try JSONDecoder().decode(Preferences.self, from: data)
        #expect(q.localVolumesToShow == p.localVolumesToShow)
        #expect(q.networkVolumesToShow == p.networkVolumesToShow)
        #expect(q.localPollIntervalSeconds == 9)
        #expect(q.networkPollIntervalSeconds == 30)
        #expect(q.lowSpaceWarningThresholdGigs == 250)
        #expect(q.lowSpaceErrorThresholdGigs == 20)
        #expect(q.showUsedSpace)
        #expect(q.maxDataAgeMinutes == 15)
        #expect(q.legendFontSize == 24)
    }

    @Test func invalidJSONFailsToDecode() {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Preferences.self, from: Data("{\"localPollIntervalSeconds\": 3}".utf8))
        }
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Preferences.self, from: Data("not json".utf8))
        }
    }
}
