import SwiftUI
import Combine

typealias VolumeRecords = [String:[SizeInfo]]

class VolumeViewModel: ObservableObject,
                       Identifiable,
                       Hashable,
                       CustomStringConvertible
{
    @Published var volume: Volume
    @Published var lastSize: SizeInfo?
    @Published public var isSelected = true
    @Published var sizes: [SizeInfo] = []
    @Published var lineColor: Color
    @Published var chartFreeLineText: String = ""
    @Published var isMostEmpty = false
    @Published var isMostFull = false
    let preferences: PreferencesViewModel
    
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

class PreferencesViewModel: ObservableObject {
    // this is tracked with published variables in the volume view models
    // used here for initial values, and also shadowing the view model observables
    var volumesToShow: Set<String>
    @Published var showSettingsView: Bool
    @Published var showMultipleCharts: Bool
    @Published var showFreeSpace: Bool
    @Published var showUsedSpace: Bool
    @Published var soundVoiceOnErrors: Bool
    @Published var errorVoice: VoiceActor.Voice
    @Published var legendFontSize: Int
    @Published var pollIntervalSeconds: Int
    @Published var lowSpaceWarningThresholdGigs: UInt
    @Published var lowSpaceErrorThresholdGigs: UInt

    init() {
        self.volumesToShow = []
        self.showSettingsView = true
        self.showMultipleCharts = false
        self.showFreeSpace = true
        self.showUsedSpace = false
        self.soundVoiceOnErrors = true
        self.errorVoice = .Ellen // random
        self.legendFontSize = 24
        self.pollIntervalSeconds = 12
        self.lowSpaceWarningThresholdGigs = 100
        self.lowSpaceErrorThresholdGigs = 20
    }

    init(preferences: Preferences) {
        self.volumesToShow = Set(preferences.volumesToShow)
        self.showSettingsView = preferences.showSettingsView
        self.showMultipleCharts = preferences.showMultipleCharts
        self.showFreeSpace = preferences.showFreeSpace
        self.showUsedSpace = preferences.showUsedSpace
        self.errorVoice = preferences.errorVoice
        self.soundVoiceOnErrors = preferences.soundVoiceOnErrors
        self.legendFontSize = preferences.legendFontSize
        self.pollIntervalSeconds = preferences.pollIntervalSeconds
        self.lowSpaceWarningThresholdGigs = preferences.lowSpaceWarningThresholdGigs
        self.lowSpaceErrorThresholdGigs = preferences.lowSpaceErrorThresholdGigs
    }

    var preferencesToSave: Preferences {
        Preferences(volumesToShow: Array(volumesToShow),
                    showSettingsView: self.showSettingsView,
                    showMultipleCharts: self.showMultipleCharts,
                    showFreeSpace: self.showFreeSpace,
                    showUsedSpace: self.showUsedSpace,
                    soundVoiceOnErrors: self.soundVoiceOnErrors,
                    errorVoice: self.errorVoice,
                    legendFontSize: self.legendFontSize,
                    pollIntervalSeconds: self.pollIntervalSeconds,
                    lowSpaceWarningThresholdGigs: self.lowSpaceWarningThresholdGigs,
                    lowSpaceErrorThresholdGigs: self.lowSpaceErrorThresholdGigs)
    }
}

class VolumeListViewModel: ObservableObject {
    @Published var list: [VolumeViewModel] = []
}

@MainActor
public final class ViewModel: ObservableObject {
    @Published var volumes = VolumeListViewModel()
    @Published var preferences = PreferencesViewModel()
    @Published var lowVolumes: Set<String> = []
    
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        Task {
            // try to load load preferences from file
            try? await preferenceManager?.loadPreferences()
            if let preferenceManager,
               let preferences = await preferenceManager.getPreferences()
            {
                await MainActor.run {
                  self.preferences = PreferencesViewModel(preferences: preferences)
                }
            }
        }
    }
    
    let manager = Manager()

    let recordKeeper = VolumeRecordKeeper()
    let preferenceManager = PreferenceManager()
    
    let seconds = 8            // XXX make this a published variable

    var newVolumeSizes: VolumeRecords = [:]

    func listVolumes() {
        Task {
            do {
                //say("we are now loading stored records", as: .Bad)
                await self.loadStoredRecords()
                //say("we are now loading volumes")
                let volumes = try await manager.listVolumes()

                //say("we are now done loading volumes")
                await MainActor.run {
                    var colorIndex = 0
                    self.volumes.list = volumes.map {
                        let ret = VolumeViewModel(volume: $0,
                                                  color: lineColors[colorIndex],
                                                  preferences: preferences)
                        colorIndex += 1
                        if colorIndex >= lineColors.count { colorIndex = 0 }

                        if preferences.volumesToShow.contains($0.name) {
                            ret.isSelected = true
                        } else {
                            ret.isSelected = false
                        }
                        return ret
                    }
                    self.objectWillChange.send()
                }
                self.startTaskWithInterval(of: preferences.pollIntervalSeconds)
            } catch {
                print("ERROR: \(error)")
            }
        }
    }

    private var task: Task<Void,Never>?

    public func minGigs(showFree: Bool, showUsed: Bool) -> UInt {
        var ret = UInt.max<<8
        if volumes.list.count == 0 { return 0 }
        for volumeViewModel in volumes.list {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.minGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs < ret { ret = maxGigs }
            }
        }
        return ret
    }

    public func maxGigs(showFree: Bool, showUsed: Bool) -> UInt {
        var ret: UInt = 0
        if volumes.list.count == 0 { return UInt.max<<8 }
        for volumeViewModel in volumes.list {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.maxGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs > ret { ret = maxGigs }
            }
        }

        return ret
    }
    
    func clearAll() {
        for volumeViewModel in volumes.list {
            volumeViewModel.isSelected = false
        }
    }

    func selectAll() {
        for volumeViewModel in volumes.list {
            volumeViewModel.isSelected = true
        }
    }

    // make sure the size infos aren't too old
    private func sizeInfoListTrim(_ list: [SizeInfo]) -> [SizeInfo] {
        // one hour before now
        let maxOldAge = Date().timeIntervalSince1970 - 60*60 // XXX make param
        
        var ret: [SizeInfo] = []

        for info in list {
            if info.timestamp > maxOldAge {
                ret.append(info)
            }
        }

        ret.sort { $0.timestamp < $1.timestamp } // necessary?
        
        return ret
    }
    
    private func mergeRecords(_ records1: VolumeRecords, _ records2: VolumeRecords) -> VolumeRecords {
        var processedVolumes: Set<String> = []

        var ret: VolumeRecords = [:]

        for (volume, sizeInfoList1) in records1 {
            processedVolumes.insert(volume)
            if let sizeInfoList2 = records2[volume] {
                // combine volumes
                ret[volume] = sizeInfoListTrim(sizeInfoList1 + sizeInfoList2)
            } else {
                // no record for this volume in records2
                ret[volume] = sizeInfoListTrim(sizeInfoList1)
            }
        }
        for (volume, sizeInfoList2) in records2 {
            if !processedVolumes.contains(volume) {
                ret[volume] = sizeInfoListTrim(sizeInfoList2)
            }
        }
        return ret
    }

    private func potentialSizeWarning(for oldSize: SizeInfo?,
                                      and newSize: SizeInfo,
                                      of volume: VolumeViewModel) {
        if !preferences.soundVoiceOnErrors         { return }
        if !volume.isSelected                      { return }

        // compare and see if we've crossed this threshold
        let warningThreshold = preferences.lowSpaceWarningThresholdGigs

        if lowVolumes.contains(volume.volume.name) { 
            if newSize.gigsFree > warningThreshold {
                lowVolumes.remove(volume.volume.name)
                say("\(volume.volume.name) is no longer low on free space.  It now has \(newSize.gigsFree) gigabytes of free space left.")
            }
            return
        }
        
        let message = "Low Disk Space Warning.  \(volume.volume.name) is running low on free space.  It now has only \(newSize.gigsFree) gigabytes of free space left."
        
        if let oldSize,
           oldSize.gigsFree >= warningThreshold,
           newSize.gigsFree < warningThreshold
        {
            say(message, as: preferences.errorVoice)
            print("WARNING: \(volume.volume.name) oldSize.gigsFree \(oldSize.gigsFree) newSize.gigsFree \(newSize.gigsFree)")
            lowVolumes.insert(volume.volume.name)
        } else if newSize.gigsFree < warningThreshold {
            // no old size
            print("WARNING: \(volume.volume.name) newSize.gigsFree \(newSize.gigsFree)")
            
            say(message, as: preferences.errorVoice)
            lowVolumes.insert(volume.volume.name)
        } else {
            // put out some kind of other error if it gets empty or really close to so
        }
    }
    
    private let lineColors: [Color] =
      [
        .blue,
        .cyan,
        .indigo,
        .brown,
        .yellow,
        .pink,
        .orange,
        .purple,
      ]
    /*
     [.mint,
     .green,
     .blue,
     
     .orange,

     .teal,

     */
    


    private func viewUpdate(records: VolumeRecords, shouldSave: Bool = true) async {
        await MainActor.run {
            let startTime = Date().timeIntervalSince1970
            // merge them in and apply a time threshold
            self.newVolumeSizes = mergeRecords(records, self.newVolumeSizes)

            let recordsToSave = self.newVolumeSizes
            if shouldSave {
                // save them for later
                Task {
                    do {
                        try await recordKeeper?.save(records: recordsToSave)
                    } catch {
                        print("cannot save volume records: \(error)")
                    }
                }
            }
            for volume in self.volumes.list {
                volume.computeChartFreeLineText()
                if let newSizes = newVolumeSizes[volume.volume.name] {
                    //print("volume.lastSize \(volume.lastSize)")

                    if let oldSize = volume.lastSize,
                       let newSize = newSizes.last
                    {
                        potentialSizeWarning(for: oldSize, and: newSize, of: volume)
                    }
                    
                    volume.lastSize = newSizes.last
                    volume.sizes = newSizes
                    //print("updating volume \(volume.volume.name) size to \(newSizes.count)")
                }
            }
            self.volumes.list.sort {
                $0.lastSize?.totalSize_k ?? 0 > $1.lastSize?.totalSize_k ?? 0
            }

            // apply colors here

            let volumesEmptyFirst = self.volumes.list.sorted {
                $0.lastFreeSize() > $1.lastFreeSize()
            }
            
            var colorIndex = 0
            var lastSelectedViewModel: VolumeViewModel? = nil
            var firstSelectedViewModel: VolumeViewModel? = nil
            for var volumeViewModel in volumesEmptyFirst {
                volumeViewModel.isMostFull = false
                volumeViewModel.isMostEmpty = false
                if volumeViewModel.isSelected {
                    if firstSelectedViewModel == nil {
                        firstSelectedViewModel = volumeViewModel
                        volumeViewModel.lineColor = .green
                    } else {
                        volumeViewModel.lineColor = lineColors[colorIndex]
                        colorIndex += 1
                        if colorIndex >= lineColors.count { colorIndex = 0 }
                    }
                    lastSelectedViewModel = volumeViewModel
                } else {
                    volumeViewModel.isMostFull = false
                }
            }

            if let lastSelectedViewModel {
                lastSelectedViewModel.isMostFull = true
                lastSelectedViewModel.lineColor = .red
            }

            if let firstSelectedViewModel {
                firstSelectedViewModel.isMostEmpty = true
            }
            self.objectWillChange.send()
            let endTime = Date().timeIntervalSince1970
            print("view update took \(endTime-startTime) seconds")
        }
    }
    
    private func loadStoredRecords() async {
        // on startup, first load any stored records
        var storedRecords: VolumeRecords?
        do {
            storedRecords = try await recordKeeper?.loadRecords() 
//            print("loaded stored records \(storedRecords?.count)")
        } catch {
            print("error loading stored records: \(error)")
        }

        if let storedRecords {
            // update the view with any stored records
            await self.viewUpdate(records: storedRecords, shouldSave: false)
        }
    }
    
    private func startTaskWithInterval(of seconds: Int) {
        self.task = Task {
            var isFirst = true
            // then iterate until we are cancelled
            while(true) {
                do {
                    await self.viewUpdate(records: try await manager.recordVolumeSizes())

                    try Task.checkCancellation()
                    if !isFirst {
                        // don't sleep the first time so the graph updates quicker
                        try await Task.sleep(nanoseconds: UInt64(seconds*1_000_000_000))
                    }
                    try Task.checkCancellation()
                    isFirst = false 
                } catch {
                    print("ERROR: \(error)")
                }
            }
        }
    }

    // XXX call this for top bar toggles too (not just volume selection toggles)
    func update(for volumeViewModel: VolumeViewModel? = nil) { 
        if let volumeViewModel {
            if volumeViewModel.isSelected {
                self.preferences.volumesToShow.insert(volumeViewModel.volume.name)
            } else {
                self.preferences.volumesToShow.remove(volumeViewModel.volume.name)
            }
        }

        let prefsToSave = self.preferences.preferencesToSave
        Task {
            do {
              await self.preferenceManager?.set(preferences: prefsToSave)
                try await self.preferenceManager?.writePreferences()
            } catch {
                print("error saving preferences: \(error)")
            }
        }
    }
}

