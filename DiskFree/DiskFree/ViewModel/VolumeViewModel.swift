import SwiftUI
import Combine


@Observable
class VolumeViewModel: Identifiable,
                       Hashable,
                       CustomStringConvertible,
                       Comparable
{
    var volume: VolumeType
    var lastSize: SizeInfo? 
    public var isSelected = true
    var lineColor: Color
    var chartFreeLineText: String {
        if self.sizes.count > 1 {
            let new = self.sizes[self.sizes.count-1]
            
            return "\(new.freeSizeInt)"
            
        } else if let lastSize = self.lastSize {
            return "\(lastSize.freeSizeInt)"
        } else {
            return ""
        }
    }

    var isInternal: Bool {
        switch volume {
        case .local(let volume):
            return volume.isInternal 
        case .network(_):
            return false
        }
    }
    
    var isNetwork: Bool {
        switch volume {
        case .local(_):
            return false
        case .network(_):
            return true
        }
    }
    
    static func < (lhs: VolumeViewModel, rhs: VolumeViewModel) -> Bool {
        lhs.volume < rhs.volume
    }
  
    func changeAmount(for old: SizeInfo, and new: SizeInfo) -> Double { // kb/sed
        let diffInKB = abs(Int(new.freeSize_k) - Int(old.freeSize_k))
        let timeDiff = abs(new.timestamp - old.timestamp)
        return Double(diffInKB)/timeDiff
    }
    
    func changeString(for old: SizeInfo, and new: SizeInfo) -> String {

        let kbPerSec = changeAmount(for: old, and: new)
        
/*        if kbPerSec < 1024 {
            return String(format: "%.0fkb/s", kbPerSec)
        } else*/ if kbPerSec < 1024*1024 {
            return String(format: "%.0f", kbPerSec/1024)
        } else {
            return String(format: "%.1f", kbPerSec/(1024*1024))
        }
    }

    var shouldShowChange: Bool {
        if self.sizes.count > 2 {
            let old = self.sizes[self.sizes.count-3]
            let new = self.sizes[self.sizes.count-1]


            return changeAmount(for: old, and: new) > 1024
            
            
        } else if self.sizes.count > 1 {
            let old = self.sizes[self.sizes.count-2]
            let new = self.sizes[self.sizes.count-1]

            return changeAmount(for: old, and: new) > 1024
        } else {
            return false
        }
    }
    
    var change: String {
        if self.sizes.count > 2 {
            let old = self.sizes[self.sizes.count-3]
            let new = self.sizes[self.sizes.count-1]

          return changeString(for: old, and: new)
            
            
        } else if self.sizes.count > 1 {
            let old = self.sizes[self.sizes.count-2]
            let new = self.sizes[self.sizes.count-1]

          return changeString(for: old, and: new)
        } else {
            return ""
        }
    }
    
    func changeString2(for old: SizeInfo, and new: SizeInfo) -> String {
        let diffInKB = abs(Int(new.freeSize_k) - Int(old.freeSize_k))
        let timeDiff = abs(new.timestamp - old.timestamp)
        let kbPerSec = Double(diffInKB)/timeDiff

/*        if kbPerSec < 1024 {
            return String(format: "%.0fkb/s", kbPerSec)
        } else*/ if kbPerSec < 1024*1024 {
            return String(format: "mb/s")
        } else {
            return String(format: "gb/s")
        }
    }
    
    var change2: String {
        if self.sizes.count > 2 {
            let old = self.sizes[self.sizes.count-3]
            let new = self.sizes[self.sizes.count-1]

          return changeString2(for: old, and: new)
            
            
        } else if self.sizes.count > 1 {
            let old = self.sizes[self.sizes.count-2]
            let new = self.sizes[self.sizes.count-1]

          return changeString2(for: old, and: new)
        } else {
            return ""
        }
    }
    
    var direction: Direction {
        if self.sizes.count > 2 {
            let old = self.sizes[self.sizes.count-3]
            let new = self.sizes[self.sizes.count-1]

            if old.freeSize_k == new.freeSize_k {
                return .equal
            } else if old.freeSize_k < new.freeSize_k {
                return .up
            } else  {
                return .down
            }
            
        } else if self.sizes.count > 1 {
            let old = self.sizes[self.sizes.count-2]
            let new = self.sizes[self.sizes.count-1]

            if old.freeSize_k == new.freeSize_k {
                return .equal
            } else if old.freeSize_k < new.freeSize_k {
                return .up
            } else  {
                return .down
            }
        } else {
            return .equal
        }
    }
    
    var isMostEmpty = false
    var isMostFull = false

    var preferences: Preferences
    
    enum Direction {
        case up
        case down
        case equal
    }
    
    public var sizes: [SizeInfo] = []
    
    var id = UUID()

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.volume)
    }

    func lastFreeSize() -> UInt {
        self.lastSize?.freeSize_k ?? 0
    }

    // between zero and one
    // zero is totally empty
    // one is totally full
    var amountFull: Double? {
        if let lastSize {
            let total = lastSize.totalCapacity
            let free = lastSize.importantCapacity
            return Double(total-free)/Double(total)
        }
        return nil
    }
    
    // between zero and one
    // zero is totally full
    // one is totally empty
    var amountEmpty: Double? {
        if let lastSize {
            let total = lastSize.totalCapacity
            let free = lastSize.importantCapacity
            return Double(free)/Double(total)
        }
        return nil
    }
    
    var description: String {
        "\(volume.name) \(chartFreeLineText)"
    }

    var weightAdjustedColor: Color {
        if showLowSpaceError {
            return .red
        } else if showLowSpaceWarning {
            return .yellow
        } else {
            return lineColor 
        }
    }

    static func == (lhs: VolumeViewModel, rhs: VolumeViewModel) -> Bool {
        lhs.volume == rhs.volume
    }

  public convenience init(volume: NetworkVolume, color: Color, preferences: Preferences) {
        self.init(volume: .network(volume), color: color, preferences: preferences)
    }

  public convenience init(volume: LocalVolume, color: Color, preferences: Preferences) {
        self.init(volume: .local(volume), color: color, preferences: preferences)
    }
    
    public init(volume: VolumeType, color: Color, preferences: Preferences) {
        self.volume = volume
        self.lineColor = color
        self.preferences = preferences
    }

    public var showLowSpaceWarning: Bool {
        isBelow(gigs: self.preferences.lowSpaceWarningThresholdGigs)
    }
    
    public var showLowSpaceError: Bool {
        isBelow(gigs: self.preferences.lowSpaceErrorThresholdGigs)
    }
    
    public func isBelow(gigs: UInt) -> Bool {
        if let lastSize {
            return lastSize.gigsFree < gigs
        }
        return false            // don't want to create false positives
    }

    // make these published values that change when sizes do
    public var maxUsedGigs: UInt {
        var ret: UInt = 0
        for size in sizes { if size.gigsUsed > ret { ret = size.gigsUsed } }
        return ret
    }

    public var maxFreeGigs: UInt {
        var ret: UInt = 0
        for size in sizes { if size.gigsFree > ret { ret = size.gigsFree } }
        return ret
    }

    public var minUsedGigs: UInt {
        var ret: UInt = UInt.max
        if sizes.count == 0 { return 0 }
        for size in sizes { if size.gigsUsed < ret { ret = size.gigsUsed } }
        return ret
    }

    public var minFreeGigs: UInt {
        var ret: UInt = 8000000
        if sizes.count == 0 { return 0 }
        for size in sizes { if size.gigsFree < ret { ret = size.gigsFree } }
        return ret
    }

    var chartUsedLineText: String {
        if let lastSize = self.lastSize {
            return "\(self.volume.name) - \(lastSize.usedSizeInt) used"
        } else {
            return self.volume.name
        }
    }
    
    public func maxGigs(showFree: Bool, showUsed: Bool) -> UInt {
        if showFree {
            if showUsed {
                return max(maxFreeGigs, maxUsedGigs)
            } else {
                return maxFreeGigs
            }
        } else {
            if showUsed {
                return maxUsedGigs
            } else {
                return 0
            }
        }
    }

    public func minGigs(showFree: Bool, showUsed: Bool) -> UInt {
        var ret: UInt = 0
        if showFree {
            if showUsed {
                ret = min(minFreeGigs, minUsedGigs)
            } else {
                ret = minFreeGigs
            }
        } else {
            if showUsed {
                ret = minUsedGigs
            } else {
                ret = 0
            }
        }

        // give some space at the bottom of the graph
        if ret > 50 {
            ret -= 20
        }

        return ret
    }

    public var helpText: String {
        var ret =  ""
        if let lastSize = self.lastSize {
            ret = "\(lastSize.totalSize) Volume \(volume.name)\n is mounted on \(volume.name)"
        } else {
            ret = "Volume \(volume.name)"
        }
        return ret
    }
}

