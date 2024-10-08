import Foundation

// reads from system apis to get volume sizes
// gives more info than df, specifically
// can account for system usage on the root volume
// where df says it's really low, but the real
// problem is that the machine is thrashing on swap space.
public struct SizeInfo: Sendable,
                        Identifiable,
                        Equatable,
                        Codable
{
    // all sizes in bytes
    let importantCapacity: Int  // size that's really available

    // size that's only available if the os doesn't cleaup it's swap and such
    let opportunisticCapacity: Int
    //let availableCapacity: Int
    let totalCapacity: Int
    
    let timestamp: TimeInterval

    public var id: String { "\(timestamp)" }

    public var freeSize_k: UInt { UInt(importantCapacity/1024) }
    public var totalSize_k: UInt { UInt(totalCapacity/1024) }

    // size info from df output
    init?(dfOutput: String, timestamp: TimeInterval) {
        /*
         expects this kind of string:
           
Filesystem    1024-blocks       Used Available Capacity iused      ifree %iused  Mounted on
/dev/disk14s2  3906870272 3582336656 324533616    92%   97180 4294870099    0%   /Volumes/op
//admin@beast.local/root  5809283456 642511216 5166772240    12% 160627802 1291693060   11%   /System/Volumes/Data/mnt/root
         */

        // should match the beginning of the second line
        let regex = /^\/\/?[\/@\w.]+\s+(\d+)\s+(\d+)\s+(\d+)/

        let lines = dfOutput.components(separatedBy: "\n")
        if lines.count > 1,
           let match = lines[1].firstMatch(of: regex),
           let match1 = Int(match.1),
           let match2 = Int(match.2),
           let match3 = Int(match.3)
        {
            self.totalCapacity = match1*1024
            //self.usedSize_k = match2
            self.opportunisticCapacity = match3*1024
            self.importantCapacity = match3*1024
            self.timestamp = timestamp
        } else {
            return nil
        }
    }

    // size info for local volume at file system path
    init(for path: String, timestamp: TimeInterval) throws {
        let fileURL = URL(fileURLWithPath: path)

        let keys: Set<URLResourceKey> =
          [.volumeTotalCapacityKey,
           //.volumeAvailableCapacityKey,
           .volumeAvailableCapacityForImportantUsageKey,
           .volumeAvailableCapacityForOpportunisticUsageKey]

        let values = try
          fileURL.resourceValues(forKeys: keys)

        if let importantCapacity = values.volumeAvailableCapacityForImportantUsage,
           let opportunisticCapacity = values.volumeAvailableCapacityForOpportunisticUsage,
           //let availableCapacity = values.volumeAvailableCapacity,
           let totalCapacity = values.volumeTotalCapacity
        {
            self.importantCapacity = Int(importantCapacity)
            self.opportunisticCapacity = Int(opportunisticCapacity)
            //self.availableCapacity = availableCapacity
            self.totalCapacity = totalCapacity
            self.timestamp = timestamp
            print("self \(self)")
        } else {
            throw "couldn't read size data for volume \(path)" 
        }
    }

    public static func == (lhs: SizeInfo, rhs: SizeInfo) -> Bool {
        lhs.timestamp == rhs.timestamp &&
        lhs.importantCapacity == rhs.importantCapacity &&
        lhs.opportunisticCapacity == rhs.opportunisticCapacity &&
        //lhs.availableCapacity == rhs.availableCapacity &&
        lhs.totalCapacity == rhs.totalCapacity //&&
    }

    var gigsUsed: UInt { UInt(Double(totalCapacity-opportunisticCapacity)/Double(SizeInfo.oneGiga)) }
    var gigsFree: UInt { UInt(Double(importantCapacity)/Double(SizeInfo.oneGiga)) }
    var gigsTotal: UInt { UInt(Double(totalCapacity)/Double(SizeInfo.oneGiga)) }
    
    // user readable versions
    var totalSize: String { userReadable(totalCapacity) }
    var usedSize: String  { userReadable(totalCapacity-opportunisticCapacity) }
    var freeSize: String  { userReadable(importantCapacity) }

    var totalSizeInt: String { userReadableInts(totalCapacity) }
    var usedSizeInt: String  { userReadableInts(totalCapacity-opportunisticCapacity) }
    var freeSizeInt: String  { userReadableInts(importantCapacity) }

    static let oneKilo:Int = 1024                  // 1 kilo is 1024 bytes
    static let oneMega:Int = SizeInfo.oneKilo*1024 // 1 mega is 1024 kilos
    static let oneGiga:Int = SizeInfo.oneMega*1024 // 1 giga is 1024 megs
    static let oneTera:Int = SizeInfo.oneGiga*1024 // 1 tera is 1024 gigs

    private func userReadable(_ sizeInBytes: Int) -> String {
        if sizeInBytes < SizeInfo.oneMega {
            return String(format: "%.2fK", Double(sizeInBytes))
        } else if sizeInBytes < SizeInfo.oneGiga {
            return String(format: "%.2fM", Double(sizeInBytes)/Double(SizeInfo.oneMega))
        } else if sizeInBytes < SizeInfo.oneTera {
            return String(format: "%.2fG", Double(sizeInBytes)/Double(SizeInfo.oneGiga))
        } else {
            return String(format: "%.2fT", Double(sizeInBytes)/Double(SizeInfo.oneTera))
        }
    }

    private func userReadableInts(_ sizeInBytes: Int) -> String {
        if sizeInBytes < SizeInfo.oneMega {
            return String(format: "%dK", sizeInBytes)
        } else if sizeInBytes < SizeInfo.oneGiga {
            return String(format: "%dM", sizeInBytes/SizeInfo.oneMega)
        } else if sizeInBytes < SizeInfo.oneTera {
            return String(format: "%dG", sizeInBytes/SizeInfo.oneGiga)
        } else {
            return String(format: "%.2fT", Double(sizeInBytes)/Double(SizeInfo.oneTera))
        }
    }
    
}

