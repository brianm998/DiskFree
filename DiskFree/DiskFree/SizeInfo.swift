import Foundation

let oneMega = 1024         // 1 mega is 1024 1024k blocks
let oneGiga = oneMega*1024 // 1 giga is 1024 megs
let oneTera = oneGiga*1024 // 1 tera is 1024 gigs

public struct SizeInfo: Sendable, Identifiable, Equatable {
    let totalSize_k: UInt
    let usedSize_k: UInt
    let freeSize_k: UInt
    let timestamp: TimeInterval

    public var id: String { "\(timestamp)" }
    
    init?(dfOutput: String) {
        /*
         expects this kind of string:
           
Filesystem    1024-blocks       Used Available Capacity iused      ifree %iused  Mounted on
/dev/disk14s2  3906870272 3582336656 324533616    92%   97180 4294870099    0%   /Volumes/op
         */

        // should match the beginning of the second line
        let regex = /^\/\w+\/\w+\s+(\d+)\s+(\d+)\s+(\d+)/
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
            self.timestamp = Date().timeIntervalSince1970
        } else {
            return nil
        }
    }
    
    public static func == (lhs: SizeInfo, rhs: SizeInfo) -> Bool {
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
}
