import Testing
import Foundation
@testable import DiskFree

struct SizeInfoTests {
    static let header = "Filesystem    1024-blocks       Used Available Capacity iused      ifree %iused  Mounted on\n"
    static let localLine = "/dev/disk14s2  3906870272 3582336656 324533616    92%   97180 4294870099    0%   /Volumes/op"
    static let smbLine = "//admin@beast.local/root  5809283456 642511216 5166772240    12% 160627802 1291693060   11%   /System/Volumes/Data/mnt/root"

    @Test func localVolumeLine() throws {
        let s = try #require(SizeInfo(dfOutput: Self.header + Self.localLine, timestamp: 5))
        #expect(s.totalCapacity == 3906870272 * 1024)
        #expect(s.importantCapacity == 324533616 * 1024)
        #expect(s.opportunisticCapacity == 324533616 * 1024)
        #expect(s.timestamp == 5)
        #expect(s.freeSize_k == 324533616)
        #expect(s.totalSize_k == 3906870272)
    }

    @Test func smbVolumeLine() throws {
        let s = try #require(SizeInfo(dfOutput: Self.header + Self.smbLine + "\n", timestamp: 1))
        #expect(s.totalCapacity == 5809283456 * 1024)
        #expect(s.freeSize_k == 5166772240)
    }

    @Test func headerOnlyIsNil() {
        #expect(SizeInfo(dfOutput: Self.header, timestamp: 1) == nil)
        #expect(SizeInfo(dfOutput: "", timestamp: 1) == nil)
    }

    @Test func malformedLineIsNil() {
        #expect(SizeInfo(dfOutput: Self.header + "garbage here", timestamp: 1) == nil)
        #expect(SizeInfo(dfOutput: Self.header + "/dev/disk1 abc def ghi", timestamp: 1) == nil)
        #expect(SizeInfo(dfOutput: Self.header + "/dev/disk1 100 50", timestamp: 1) == nil)
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
        #expect(s.freeSize == "30.00G")
        #expect(s.freeSizeInt == "30G")
        #expect(s.totalSize == "2.00T")
        #expect(s.usedSizeInt.hasSuffix("T"))
        let small = SizeInfo(importantCapacity: 5 * SizeInfo.oneMega, opportunisticCapacity: 0,
                             totalCapacity: 100, timestamp: 0)
        #expect(small.freeSize == "5.00M")
        #expect(small.freeSizeInt == "5M")
    }

    @Test func equality() throws {
        let a = try #require(SizeInfo(dfOutput: Self.header + Self.localLine, timestamp: 5))
        let b = try #require(SizeInfo(dfOutput: Self.header + Self.localLine, timestamp: 5))
        let c = try #require(SizeInfo(dfOutput: Self.header + Self.localLine, timestamp: 6))
        let d = try #require(SizeInfo(dfOutput: Self.header + Self.smbLine, timestamp: 5))
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
        #expect(a.id == "5.0")
    }

    @Test func hyphenatedHostDf() throws {
        let line = "//admin@my-nas-2.local/data  1000 400 600    40% 1 2   0%   /Volumes/data"
        let s = try #require(SizeInfo(dfOutput: Self.header + line, timestamp: 1))
        #expect(s.totalCapacity == 1000 * 1024)
        #expect(s.importantCapacity == 600 * 1024)
    }

    @Test func percentEncodedShareDf() throws {
        let line = "//brian@nas.local/My%20Share  2000 500 1500    25% 1 2   0%   /Volumes/My Share"
        let s = try #require(SizeInfo(dfOutput: Self.header + line, timestamp: 1))
        #expect(s.totalCapacity == 2000 * 1024)
        #expect(s.importantCapacity == 1500 * 1024)
    }
}
