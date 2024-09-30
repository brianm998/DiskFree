import SwiftUI
import Combine

class VolumeViewModel: ObservableObject,
                       Identifiable,
                       Hashable,
                       CustomStringConvertible
{
    @Published var volume: Volume
    @Published var lastSize: SizeInfo?
    @Published public var isSelected = true
    @Published var lineColor: Color
    @Published var chartFreeLineText: String = ""
    @Published var isMostEmpty = false
    @Published var isMostFull = false
    let preferences: PreferencesViewModel

    public private(set) var sizes: [SizeInfo] = []
    
    var id = UUID()

    func set(sizes: [SizeInfo]) {
        self.sizes = sizes

        // update maxUsedGigs and such here
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.volume)
    }

    func lastFreeSize() -> UInt {
        self.lastSize?.freeSize_k ?? 0
    }
    
    var description: String {
        "\(volume.name) \(chartFreeLineText)"
    }
    
    static func == (lhs: VolumeViewModel, rhs: VolumeViewModel) -> Bool {
        lhs.volume == rhs.volume
    }

    public init(volume: Volume, color: Color, preferences: PreferencesViewModel) {
        self.volume = volume
        self.lineColor = color
        self.preferences = preferences
    }

    public var showLowSpaceWarning: Bool {
        isBelow(gigs: self.preferences.lowSpaceWarningThresholdGigs)
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

    func computeChartFreeLineText() {
        if let lastSize = self.lastSize {
            chartFreeLineText = "\(lastSize.freeSizeInt)"
        } else {
            chartFreeLineText = ""
        }
        self.objectWillChange.send()
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
}
