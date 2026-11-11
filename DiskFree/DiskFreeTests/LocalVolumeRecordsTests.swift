import Testing
import Foundation
@testable import DiskFree

struct LocalVolumeRecordsTests {
    func sample(_ t: TimeInterval) -> SizeInfo {
        SizeInfo(importantCapacity: 1, opportunisticCapacity: 1, totalCapacity: 2, timestamp: t)
    }

    @Test func emptyRecordsGiveSentinel() {
        #expect(oldestTime(from: [:]) == 1000000000000000000)
    }

    @Test func volumeWithNoSamplesGivesSentinel() {
        #expect(oldestTime(from: ["/a": []]) == 1000000000000000000)
    }

    @Test func singleVolume() {
        #expect(oldestTime(from: ["/a": [sample(30), sample(10), sample(20)]]) == 10)
    }

    @Test func oldestAcrossVolumes() {
        let records: LocalVolumeRecords = [
            "/a": [sample(100), sample(50)],
            "/b": [sample(75), sample(20), sample(90)],
            "/c": [sample(60)],
            "/d": [],
        ]
        #expect(oldestTime(from: records) == 20)
    }
}
