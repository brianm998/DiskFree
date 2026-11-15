import Testing
import Foundation
import SwiftUI
@testable import DiskFree

struct VolumeViewModelTests {
    static let g = SizeInfo.oneGiga

    // free and used in gigs, out of a 1000G volume
    func sample(free: Int, used: Int, t: TimeInterval = 0) -> SizeInfo {
        SizeInfo(importantCapacity: free * Self.g,
                 opportunisticCapacity: (1000 - used) * Self.g,
                 totalCapacity: 1000 * Self.g,
                 timestamp: t)
    }

    func model(_ samples: [SizeInfo] = [], prefs: Preferences = Preferences()) -> VolumeViewModel {
        let lv = LocalVolume(name: "t", mountPoint: "/Volumes/t",
                             userVisibleMountPoint: "/Volumes/t",
                             isInternal: true, isEjectable: false)
        let m = VolumeViewModel(volume: lv, color: .blue, preferences: prefs)
        m.sizes = samples
        m.lastSize = samples.last
        return m
    }

    @Test @MainActor func thresholdChangesReachExistingVolumes() {
        let vm = ViewModel(demo: true)
        let m = model([sample(free: 50, used: 50)])
        vm.localVolumes = [m]
        vm.preferences.lowSpaceWarningThresholdGigs = 100
        vm.preferences.lowSpaceErrorThresholdGigs = 60
        #expect(m.showLowSpaceWarning)
        #expect(m.showLowSpaceError)
        vm.preferences.lowSpaceWarningThresholdGigs = 40
        #expect(!m.showLowSpaceWarning)
        vm.preferences.lowSpaceErrorThresholdGigs = 10
        #expect(!m.showLowSpaceError)
    }

    @Test @MainActor func wholePreferencesAssignmentUpdatesVolumes() {
        let vm = ViewModel(demo: true)
        let m = model([sample(free: 50, used: 50)])
        vm.localVolumes = [m]
        var p = Preferences()
        p.lowSpaceWarningThresholdGigs = 40
        p.lowSpaceErrorThresholdGigs = 10
        vm.preferences = p
        #expect(m.lowSpaceWarningThresholdGigs == 40)
        #expect(m.lowSpaceErrorThresholdGigs == 10)
        #expect(!m.showLowSpaceWarning)
        p.lowSpaceWarningThresholdGigs = 60
        p.lowSpaceErrorThresholdGigs = 55
        vm.preferences = p
        #expect(m.showLowSpaceWarning)
        #expect(m.showLowSpaceError)
    }

    @Test @MainActor func sortedIfChangedNilWhenAlreadySorted() {
        let big = model([sample(free: 1, used: 1)])
        let small = model([sample(free: 1, used: 1)])
        big.lastSize = SizeInfo(importantCapacity: 0, opportunisticCapacity: 0, totalCapacity: 2000 * Self.g, timestamp: 0)
        #expect(ViewModel.sortedIfChanged([big, small]) == nil)
        let r = ViewModel.sortedIfChanged([small, big])
        #expect(r?.map(\.id) == [big.id, small.id])
    }

    @Test func changeAmountKBPerSecond() {
        let m = model()
        let old = SizeInfo(importantCapacity: 1000 * 1024, opportunisticCapacity: 0, totalCapacity: 0, timestamp: 10)
        let new = SizeInfo(importantCapacity: 3000 * 1024, opportunisticCapacity: 0, totalCapacity: 0, timestamp: 14)
        #expect(m.changeAmount(for: old, and: new) == 500)
        // symmetric: absolute difference over absolute time
        #expect(m.changeAmount(for: new, and: old) == 500)
    }

    @Test func changeAmountNoChange() {
        let m = model()
        let s = sample(free: 10, used: 10, t: 1)
        let later = sample(free: 10, used: 10, t: 5)
        #expect(m.changeAmount(for: s, and: later) == 0)
    }

    @Test func isBelowWithoutSizeIsFalse() {
        #expect(!model().isBelow(gigs: 1000))
    }

    @Test func isBelowThreshold() {
        let m = model([sample(free: 50, used: 100)])
        #expect(m.isBelow(gigs: 51))
        #expect(!m.isBelow(gigs: 50))   // strictly below
        #expect(!m.isBelow(gigs: 10))
    }

    @Test func warningAndErrorFlags() {
        // defaults: warning 100G, error 20G
        #expect(model([sample(free: 500, used: 0)]).showLowSpaceWarning == false)
        let warn = model([sample(free: 60, used: 0)])
        #expect(warn.showLowSpaceWarning)
        #expect(!warn.showLowSpaceError)
        let err = model([sample(free: 5, used: 0)])
        #expect(err.showLowSpaceWarning)
        #expect(err.showLowSpaceError)
    }

    @Test func emptySizesGiveZeroGigs() {
        let m = model()
        for (f, u) in [(true, true), (true, false), (false, true), (false, false)] {
            #expect(m.maxGigs(showFree: f, showUsed: u) == 0)
            #expect(m.minGigs(showFree: f, showUsed: u) == 0)
        }
    }

    @Test func maxGigsForEachCombination() {
        let m = model([sample(free: 300, used: 600, t: 1),
                       sample(free: 100, used: 800, t: 2),
                       sample(free: 200, used: 700, t: 3)])
        #expect(m.maxFreeGigs == 300)
        #expect(m.maxUsedGigs == 800)
        #expect(m.maxGigs(showFree: true, showUsed: false) == 300)
        #expect(m.maxGigs(showFree: false, showUsed: true) == 800)
        #expect(m.maxGigs(showFree: true, showUsed: true) == 800)
        #expect(m.maxGigs(showFree: false, showUsed: false) == 0)
    }

    @Test func minGigsForEachCombination() {
        let m = model([sample(free: 300, used: 600, t: 1),
                       sample(free: 100, used: 800, t: 2),
                       sample(free: 200, used: 700, t: 3)])
        #expect(m.minFreeGigs == 100)
        #expect(m.minUsedGigs == 600)
        // results over 50 get 20 subtracted for chart padding
        #expect(m.minGigs(showFree: true, showUsed: false) == 80)
        #expect(m.minGigs(showFree: false, showUsed: true) == 580)
        #expect(m.minGigs(showFree: true, showUsed: true) == 80)
        #expect(m.minGigs(showFree: false, showUsed: false) == 0)
    }

    @Test func minGigsSmallValuesNotPadded() {
        let m = model([sample(free: 30, used: 40), sample(free: 50, used: 45)])
        #expect(m.minGigs(showFree: true, showUsed: false) == 30)
        #expect(m.minGigs(showFree: true, showUsed: true) == 30)
        #expect(m.minGigs(showFree: false, showUsed: true) == 40)
    }

    @Test func amountFullAndEmpty() throws {
        #expect(model().amountFull == nil)
        #expect(model().amountEmpty == nil)
        let m = model([sample(free: 250, used: 750)])
        #expect(try #require(m.amountFull) == 0.75)
        #expect(try #require(m.amountEmpty) == 0.25)
    }

    // MARK: chart caches

    @Test func chartSizesCapsAndKeepsEnds() {
        let samples = (0..<900).map { sample(free: 100 + $0 % 50, used: 500, t: TimeInterval($0)) }
        let m = model(samples)
        #expect(m.chartSizes.count <= 300)
        #expect(m.chartSizes.first == samples.first)
        #expect(m.chartSizes.last == samples.last)
        #expect(m.sizes.count == 900)
    }

    @Test func chartSizesEqualsSizesWhenSmall() {
        let samples = (0..<100).map { sample(free: 100, used: 500, t: TimeInterval($0)) }
        #expect(model(samples).chartSizes == samples)
    }

    @Test func cachedMinMaxMatchFullScan() {
        let samples = [sample(free: 300, used: 700, t: 1),
                       sample(free: 100, used: 900, t: 2),
                       sample(free: 500, used: 500, t: 3)]
        let m = model(samples)
        #expect(m.minFreeGigs == 100)
        #expect(m.maxFreeGigs == 500)
        #expect(m.minUsedGigs == 500)
        #expect(m.maxUsedGigs == 900)
    }

    @Test func cachedMinMaxForEmptySizes() {
        let m = model([])
        #expect(m.minFreeGigs == 0)
        #expect(m.minUsedGigs == 0)
        #expect(m.maxFreeGigs == 0)
        #expect(m.maxUsedGigs == 0)
    }

    @Test func sizeInfoIdIsTimestamp() throws {
        let a = sample(free: 1, used: 1, t: 5)
        let b = sample(free: 1, used: 1, t: 6)
        #expect(a.id == 5)
        #expect(a.id != b.id)
        let data = try JSONEncoder().encode(a)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(!json.contains("\"id\""))
        #expect(try JSONDecoder().decode(SizeInfo.self, from: data) == a)
    }
}
