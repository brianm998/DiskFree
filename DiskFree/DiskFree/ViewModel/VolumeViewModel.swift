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
    /// false while the volume is unplugged; its history is kept for when it returns
    var isMounted = true
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

    /// low-space thresholds, pushed from ViewModel.preferences whenever they change
    var lowSpaceWarningThresholdGigs: UInt
    var lowSpaceErrorThresholdGigs: UInt
    
    enum Direction {
        case up
        case down
        case equal
    }
    
    public var sizes: [SizeInfo] = [] {
        didSet { recomputeCaches() }
    }

    /// maximum number of points plotted per line
    static let chartPointCap = 150

    /// One plotted point.  `segment` increments across gaps so lines aren't
    /// drawn through time the app wasn't sampling.
    struct ChartPoint: Equatable, Identifiable {
        let size: SizeInfo
        let segment: Int
        var id: TimeInterval { size.timestamp }
        var date: Date { Date(timeIntervalSince1970: size.timestamp) }
        var gigsFree: UInt { size.gigsFree }
        var gigsUsed: UInt { size.gigsUsed }
    }

    /// how long the data is kept; sets the width of a chart time bucket
    var retentionSeconds: TimeInterval = 3600 {
        didSet { if retentionSeconds != oldValue { recomputeCaches() } }
    }
    /// seconds between samples; a gap of more than 3 of these splits the line
    var pollIntervalSeconds: TimeInterval = 4 {
        didSet { if pollIntervalSeconds != oldValue { recomputeCaches() } }
    }

    /// Time-bucketed copy of sizes: the first sample plus the last sample of
    /// every *completed* bucket.  Samples in the still-open bucket are left
    /// out, so it only changes when a bucket completes.
    private(set) var chartSizes: [ChartPoint] = []

    private(set) var cachedMaxUsed: UInt = 0
    private(set) var cachedMaxFree: UInt = 0
    private(set) var cachedMinUsed: UInt = 0
    private(set) var cachedMinFree: UInt = 0

    static func bucketedChartPoints(_ sizes: [SizeInfo], retention: TimeInterval,
                                    pollInterval: TimeInterval, cap: Int) -> [ChartPoint] {
        guard let first = sizes.first else { return [] }
        let width = max(retention / Double(max(cap, 1)), 1)
        let gap = pollInterval * 3

        var out: [ChartPoint] = [ChartPoint(size: first, segment: 0)]
        var segment = 0
        var prev = first
        var pending = out[0]          // last sample seen in pendingBucket
        var pendingBucket = (first.timestamp / width).rounded(.down)
        for s in sizes.dropFirst() {
            if s.timestamp - prev.timestamp > gap { segment += 1 }
            prev = s
            let bucket = (s.timestamp / width).rounded(.down)
            if bucket != pendingBucket {
                // pendingBucket completed; its representative is plotted
                if out.last?.id != pending.id { out.append(pending) }
                pendingBucket = bucket
            }
            pending = ChartPoint(size: s, segment: segment)
        }
        // `pending` sits in the open bucket (== currentBucket): not plotted
        if out.count > cap { out.removeFirst(out.count - cap) }
        return out
    }

    private func recomputeCaches() {
        let points = Self.bucketedChartPoints(sizes, retention: retentionSeconds,
                                              pollInterval: pollIntervalSeconds,
                                              cap: Self.chartPointCap)
        if points != chartSizes { chartSizes = points }
        var maxUsed: UInt = 0, maxFree: UInt = 0
        var minUsed = UInt.max, minFree: UInt = 8000000
        for p in points {
            let used = p.gigsUsed, free = p.gigsFree
            if used > maxUsed { maxUsed = used }
            if free > maxFree { maxFree = free }
            if used < minUsed { minUsed = used }
            if free < minFree { minFree = free }
        }
        let newMinUsed = points.isEmpty ? 0 : minUsed
        let newMinFree = points.isEmpty ? 0 : minFree
        if maxUsed != cachedMaxUsed { cachedMaxUsed = maxUsed }
        if maxFree != cachedMaxFree { cachedMaxFree = maxFree }
        if newMinUsed != cachedMinUsed { cachedMinUsed = newMinUsed }
        if newMinFree != cachedMinFree { cachedMinFree = newMinFree }
    }
    
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
    
    public convenience init(volume: VolumeType, color: Color, preferences: Preferences) {
        self.init(volume: volume, color: color,
                  lowSpaceWarningThresholdGigs: preferences.lowSpaceWarningThresholdGigs,
                  lowSpaceErrorThresholdGigs: preferences.lowSpaceErrorThresholdGigs)
        self.retentionSeconds = preferences.maxDataAgeMinutes * 60
        if case .network = volume {
            self.pollIntervalSeconds = TimeInterval(preferences.networkPollIntervalSeconds)
        }
    }

    public init(volume: VolumeType, color: Color,
                lowSpaceWarningThresholdGigs: UInt, lowSpaceErrorThresholdGigs: UInt) {
        self.volume = volume
        self.lineColor = color
        self.lowSpaceWarningThresholdGigs = lowSpaceWarningThresholdGigs
        self.lowSpaceErrorThresholdGigs = lowSpaceErrorThresholdGigs
    }

    public var showLowSpaceWarning: Bool {
        isBelow(gigs: self.lowSpaceWarningThresholdGigs)
    }
    
    public var showLowSpaceError: Bool {
        isBelow(gigs: self.lowSpaceErrorThresholdGigs)
    }
    
    public func isBelow(gigs: UInt) -> Bool {
        if let lastSize {
            return lastSize.gigsFree < gigs
        }
        return false            // don't want to create false positives
    }

    // make these published values that change when sizes do
    public var maxUsedGigs: UInt { cachedMaxUsed }
    public var maxFreeGigs: UInt { cachedMaxFree }
    public var minUsedGigs: UInt { cachedMinUsed }
    public var minFreeGigs: UInt { cachedMinFree }

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
        var volumeType = "External"

        if self.isNetwork {
            volumeType = "Network"
        } else if self.isInternal {
            volumeType = "Internal"
        }

        var lastSizeStr = ""
        
        if let lastSize = self.lastSize { lastSizeStr = "\(lastSize.totalSize) " }

        return "\(lastSizeStr)\(volumeType) Volume \(volume.name)\n is mounted on \(volume.mountPath)"
    }
}

