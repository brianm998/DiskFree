import Foundation

public struct SizeInfo: Sendable {
    let totalSize_k: UInt
    let usedSize_k: UInt
    let freeSize_k: UInt

    init?(dfOutput: String) {
        // reads this kind of output:
// Filesystem    1024-blocks       Used Available Capacity iused      ifree %iused  Mounted on
// /dev/disk14s2  3906870272 3582336656 324533616    92%   97180 4294870099    0%   /Volumes/op
        let regex = /^\/\w+\/\w+\s+(\d+)\s+(\d+)\s+(\d+)/
        let lines = dfOutput.components(separatedBy: "\n")
        if let match = lines[1].firstMatch(of: regex),
           let match1 = UInt(match.1),
           let match2 = UInt(match.2),
           let match3 = UInt(match.3)
        {
            self.totalSize_k = match1
            self.usedSize_k = match2
            self.freeSize_k = match3
        } else {
            return nil
        }
    }

    // add methods to read size in human readable format, and give percentages, etc
}
