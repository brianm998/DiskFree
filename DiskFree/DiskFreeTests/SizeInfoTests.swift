import Testing
import Foundation
@testable import DiskFree

struct SizeInfoTests {
    func fs(blocks: UInt64, bavail: UInt64, bsize: UInt32) -> statfs {
        var f = statfs()
        f.f_blocks = blocks
        f.f_bavail = bavail
        f.f_bsize = bsize
        return f
    }

    @Test func statfsMapping() throws {
        let s = try #require(SizeInfo(statfs: fs(blocks: 1000, bavail: 600, bsize: 4096), timestamp: 5))
        #expect(s.totalCapacity == 1000 * 4096)
        #expect(s.importantCapacity == 600 * 4096)
        #expect(s.opportunisticCapacity == 600 * 4096)
        #expect(s.timestamp == 5)
        #expect(s.freeSize_k == 600 * 4)
        #expect(s.totalSize_k == 1000 * 4)
    }

    @Test func statfsEmptyIsNil() {
        #expect(SizeInfo(statfs: fs(blocks: 0, bavail: 0, bsize: 4096), timestamp: 1) == nil)
        #expect(SizeInfo(statfs: statfs(), timestamp: 1) == nil)
    }

    @Test func derivedGigs() {
        let g = SizeInfo.oneGiga
        let s = SizeInfo(importantCapacity: 30 * g, opportunisticCapacity: 40 * g,
                         totalCapacity: 100 * g, timestamp: 0)
        #expect(s.gigsFree == 30)
        #expect(s.gigsUsed == 60)
        #expect(s.gigsTotal == 100)
    }

    @Test func userReadableStrings() {
        let g = SizeInfo.oneGiga
        let s = SizeInfo(importantCapacity: 30 * g, opportunisticCapacity: 30 * g,
                         totalCapacity: 2 * SizeInfo.oneTera, timestamp: 0)
        #expect(s.freeSize == "30 GB")
        #expect(s.freeSizeInt == "30 GB")
        #expect(s.totalSize == "2 TB")
        #expect(s.usedSizeInt.hasSuffix("TB"))
        let small = SizeInfo(importantCapacity: 5 * SizeInfo.oneMega, opportunisticCapacity: 0,
                             totalCapacity: 100, timestamp: 0)
        #expect(small.freeSize == "5 MB")
        #expect(small.freeSizeInt == "5 MB")
    }

    @Test func finderStyleSizes() {
        let t = SizeInfo(importantCapacity: 0, opportunisticCapacity: 0,
                         totalCapacity: 4_000_000_000_000, timestamp: 0)
        #expect(t.totalSize == "4 TB")
        let k = SizeInfo(importantCapacity: 512 * 1024, opportunisticCapacity: 0,
                         totalCapacity: 0, timestamp: 0)
        #expect(k.freeSize == "524 KB")
        let g = SizeInfo(importantCapacity: 100_000_000_000, opportunisticCapacity: 0,
                         totalCapacity: 0, timestamp: 0)
        #expect(g.gigsFree == 100)
    }

    @Test func equality() throws {
        let f = fs(blocks: 100, bavail: 40, bsize: 1024)
        let a = try #require(SizeInfo(statfs: f, timestamp: 5))
        let b = try #require(SizeInfo(statfs: f, timestamp: 5))
        let c = try #require(SizeInfo(statfs: f, timestamp: 6))
        let d = try #require(SizeInfo(statfs: fs(blocks: 100, bavail: 41, bsize: 1024), timestamp: 5))
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
        #expect(a.id == 5.0)
    }
}
