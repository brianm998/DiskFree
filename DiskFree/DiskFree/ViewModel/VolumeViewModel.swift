import SwiftUI
import Combine

@Observable
class VolumeViewModel: Identifiable,
                       Hashable,
                       CustomStringConvertible
{
    var volume: Volume
    var lastSize: SizeInfo?
    public var isSelected = true
    var lineColor: Color
    var chartFreeLineText: String = ""
    var direction: Direction = .equal
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

    public init(volume: Volume, color: Color, preferences: Preferences) {
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

    func updateChartFreeLineText() {

        if self.sizes.count > 2 {
            let old = self.sizes[self.sizes.count-3]
            let new = self.sizes[self.sizes.count-1]

            chartFreeLineText = "\(new.freeSizeInt)"
            if old.freeSize_k == new.freeSize_k {
                direction = .equal
            } else if old.freeSize_k < new.freeSize_k {
                direction = .up
            } else  {
                direction = .down
            }
            
        } else if self.sizes.count > 1 {
            let old = self.sizes[self.sizes.count-2]
            let new = self.sizes[self.sizes.count-1]

            chartFreeLineText = "\(new.freeSizeInt)"
            if old.freeSize_k == new.freeSize_k {
                direction = .equal
            } else if old.freeSize_k < new.freeSize_k {
                direction = .up
            } else  {
                direction = .down
            }
            
        } else if let lastSize = self.lastSize {
            chartFreeLineText = "\(lastSize.freeSizeInt)"
        } else {
            chartFreeLineText = ""
        }
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
            ret = "\(lastSize.totalSize) Volume \(volume.name)\n is mounted on \(volume.mountPoint)"
        } else {
            ret = "Volume \(volume.name)"
        }
        return ret
    }
}

