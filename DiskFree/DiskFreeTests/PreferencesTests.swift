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

    @Test func notJSONFailsToDecode() {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(Preferences.self, from: Data("not json".utf8))
        }
    }

    @Test func missingKeyGetsDefault() throws {
        var full = Preferences()
        full.localVolumesToShow = ["/a"]
        full.networkVolumesToShow = ["/n"]
        full.localPollIntervalSeconds = 11
        full.networkPollIntervalSeconds = 22
        full.showSettingsView = true
        full.chartType = .combined
        full.showFreeSpace = false
        full.showUsedSpace = true
        full.soundVoiceOnWarnings = false
        full.soundVoiceOnErrors = false
        full.legendFontSize = 13
        full.lowSpaceWarningThresholdGigs = 7
        full.lowSpaceErrorThresholdGigs = 3
        full.maxDataAgeMinutes = 99
        let data = try JSONEncoder().encode(full)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let defaults = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Preferences())) as! [String: Any]
        #expect(obj.count >= 16)
        for key in obj.keys {
            var partial = obj
            partial.removeValue(forKey: key)
            let d = try JSONSerialization.data(withJSONObject: partial)
            let q = try JSONDecoder().decode(Preferences.self, from: d)
            let qo = try JSONSerialization.jsonObject(with: JSONEncoder().encode(q)) as! [String: Any]
            for other in obj.keys {
                let expected = other == key ? defaults[other]! : obj[other]!
                #expect(NSDictionary(dictionary: [other: qo[other]!]).isEqual(to: [other: expected]),
                        "removing \(key): \(other)")
            }
        }
    }

    @Test func outOfRangeValuesAreClamped() throws {
        for (raw, local, net, age) in [(0, 1, 5, 1.0), (-5, 1, 5, 1.0), (100000, 3600, 3600, 1440.0)] {
            let json = "{\"localPollIntervalSeconds\": \(raw), \"networkPollIntervalSeconds\": \(raw), \"maxDataAgeMinutes\": \(raw)}"
            let p = try JSONDecoder().decode(Preferences.self, from: Data(json.utf8))
            #expect(p.localPollIntervalSeconds == local)
            #expect(p.networkPollIntervalSeconds == net)
            #expect(p.maxDataAgeMinutes == age)
        }
        var q = Preferences()
        q.localPollIntervalSeconds = 0
        #expect(q.sanitized().localPollIntervalSeconds == 1)
    }

    @Test func atomicWriteOverwritesAndThrowsOnBadDirectory() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let keeper = try #require(LocalVolumeRecordKeeper(directory: dir))
        try await keeper.save(records: [:])
        let rec: LocalVolumeRecords = ["x": []]
        try await keeper.save(records: rec)
        #expect(try await keeper.loadRecords().keys.sorted() == ["x"])

        let missing = dir.appendingPathComponent("nope")
        let bad = try #require(NetworkVolumeRecordKeeper(directory: missing))
        await #expect(throws: (any Error).self) { try await bad.save(records: [:]) }

        let ro = dir.appendingPathComponent("ro")
        try FileManager.default.createDirectory(at: ro, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: ro.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: ro.path) }
        let roMgr = try #require(PreferenceManager(directory: ro))
        await roMgr.set(preferences: Preferences())
        await #expect(throws: (any Error).self) { try await roMgr.writePreferences() }
    }

    @MainActor @Test func saveRecordsAtMostEveryFiveMinutes() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let vm = ViewModel()
        vm.persistsToDisk = true
        let keeper = try #require(LocalVolumeRecordKeeper(directory: dir))
        vm.localVolumeRecordKeeper = keeper
        vm.networkVolumeRecordKeeper = NetworkVolumeRecordKeeper(directory: dir)
        var t = Date()
        vm.now = { t }
        let rec: LocalVolumeRecords = ["x": []]
        for _ in 0..<100 {
            await vm.localRecordViewUpdate(records: rec, duration: 1)
            t += 2
            await vm.flushSaves()
        }
        #expect(await keeper.saveCount == 1)
        vm.stopPolling()
        await vm.flushSaves()
        #expect(await keeper.saveCount == 2)
    }

    @MainActor @Test func localLoopNeverWaitsLessThanOneSecond() {
        let vm = ViewModel()
        vm.preferences.localPollIntervalSeconds = 0
        #expect(vm.preferences.localPollIntervalSeconds == 1)
        #expect(vm.currentLocalPollInterval >= 1)
        #expect(ViewModel.effectiveLocalInterval(0) == 1)
        #expect(ViewModel.effectiveLocalInterval(-5) == 1)
        #expect(ViewModel.effectiveNetworkInterval(0) == 5)
    }
}
