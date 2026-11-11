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
}
