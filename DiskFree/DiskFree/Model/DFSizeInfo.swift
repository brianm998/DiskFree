import Foundation

let oneMega:UInt = 1024         // 1 mega is 1024 1024k blocks
let oneGiga:UInt = oneMega*1024 // 1 giga is 1024 megs
let oneTera:UInt = oneGiga*1024 // 1 tera is 1024 gigs

// holds df output (deprecated for local volumes)
public struct DFSizeInfo: Sendable,
                          Identifiable,
                          Equatable,
                          Codable
{
    let totalSize_k: UInt
    let usedSize_k: UInt
    let freeSize_k: UInt
    let timestamp: TimeInterval

    public var id: String { "\(timestamp)" }
    
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
           let match1 = UInt(match.1),
           let match2 = UInt(match.2),
           let match3 = UInt(match.3)
        {
            self.totalSize_k = match1
            self.usedSize_k = match2
            self.freeSize_k = match3
            self.timestamp = timestamp
        } else {
            return nil
        }
    }
    
    public static func == (lhs: DFSizeInfo, rhs: DFSizeInfo) -> Bool {
        lhs.timestamp == rhs.timestamp &&
        lhs.freeSize_k == rhs.freeSize_k &&
        lhs.usedSize_k == rhs.usedSize_k &&
        lhs.totalSize_k == rhs.totalSize_k
    }

    var gigsUsed: UInt { UInt(Double(usedSize_k)/Double(oneGiga)) }
    var gigsFree: UInt { UInt(Double(freeSize_k)/Double(oneGiga)) }
    var gigsTotal: UInt { UInt(Double(totalSize_k)/Double(oneGiga)) }
    
    // user readable versions
    var totalSize: String { userReadable(totalSize_k) }
    var usedSize: String  { userReadable(usedSize_k) }
    var freeSize: String  { userReadable(freeSize_k) }

    var totalSizeInt: String { userReadableInts(totalSize_k) }
    var usedSizeInt: String  { userReadableInts(usedSize_k) }
    var freeSizeInt: String  { userReadableInts(freeSize_k) }

    private func userReadable(_ sizeInKilobytes: UInt) -> String {
        if sizeInKilobytes < oneMega {
            return String(format: "%.2fK", Double(sizeInKilobytes))
        } else if sizeInKilobytes < oneGiga {
            return String(format: "%.2fM", Double(sizeInKilobytes)/Double(oneMega))
        } else if sizeInKilobytes < oneTera {
            return String(format: "%.2fG", Double(sizeInKilobytes)/Double(oneGiga))
        } else {
            return String(format: "%.2fT", Double(sizeInKilobytes)/Double(oneTera))
        }
    }

    private func userReadableInts(_ sizeInKilobytes: UInt) -> String {
        if sizeInKilobytes < oneMega {
            return String(format: "%dK", sizeInKilobytes)
        } else if sizeInKilobytes < oneGiga {
            return String(format: "%dM", sizeInKilobytes/oneMega)
        } else if sizeInKilobytes < oneTera {
            return String(format: "%dG", sizeInKilobytes/oneGiga)
        } else {
            return String(format: "%.2fT", Double(sizeInKilobytes)/Double(oneTera))
        }
    }
}
