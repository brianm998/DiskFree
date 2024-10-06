import SwiftUI
import Combine

@MainActor @Observable
public final class ViewModel {

    /*
     property wrappers used with @Observable:
     
     @Bindable
     @State
     @Environment

     https://forums.developer.apple.com/forums/thread/735416
     
     */
    var volumes: [VolumeViewModel] = []

    var preferences = Preferences()
    
    var warningVolumes: Set<String> = []
    var errorVolumes: Set<String> = []
    var volumeRecordsTimeDurationSeconds: TimeInterval = 0

    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        Task {
            // try to load load preferences from file
            try? await preferenceManager?.loadPreferences()
            if let preferenceManager,
               let preferences = await preferenceManager.getPreferences()
            {
                await MainActor.run {
                    self.preferences = preferences
                }
                await manager.set(maxDataAgeMinutes: preferences.maxDataAgeMinutes)
            }
        }
    }
    
    let manager = Manager()

    let recordKeeper = VolumeRecordKeeper()
    let preferenceManager = PreferenceManager()
    
    var newVolumeSizes: VolumeRecords = [:]

    func decreaseFontSize() {
        if preferences.legendFontSize > 4 { // XXX hardcoded minimum
            preferences.legendFontSize -= 1
        }
        savePreferences()
    }

    func increaseFontSize() {
        preferences.legendFontSize += 1
        savePreferences()
    }

    var volumesSortedByEmptyFirst: [VolumeViewModel] {
        volumes.sorted { (a: VolumeViewModel, b: VolumeViewModel) in
            a.lastFreeSize() > b.lastFreeSize()
        }
    }
    
    func listVolumes() {
        Task {
            do {
                await self.manager.loadStoredVolumeRecords()
                let volumes = try await manager.listVolumes()
                if preferences.volumesToShow.count == 0 {
                    preferences.volumesToShow = Set(volumes.map { $0.name })
                }
                await MainActor.run {
                    var colorIndex = 0
                    self.volumes = volumes.map {
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
                }
                self.startTask()
            } catch {
                print("ERROR: \(error)")
            }
        }
    }

    private var task: Task<Void,Never>?

    public func chartRange(showFree: Bool, showUsed: Bool) -> ClosedRange<UInt> {

        let min = minGigs(showFree: showFree, showUsed: showUsed)
        let max = maxGigs(showFree: showFree, showUsed: showUsed) + 20

        if min<max {
            return min...max
        } else {
            return 0...max
        }
    }
    
    private func minGigs(showFree: Bool, showUsed: Bool) -> UInt {
        var ret = UInt.max<<8
        if volumes.count == 0 {
            return 0
        }
        for volumeViewModel in volumes {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.minGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs < ret { ret = maxGigs }
            }
        }
        return ret
    }

    private func maxGigs(showFree: Bool, showUsed: Bool) -> UInt {
        var ret: UInt = 0
        if volumes.count == 0 {
            return UInt.max<<8
        }
        for volumeViewModel in volumes {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.maxGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs > ret { ret = maxGigs }
            }
        }
        return ret
    }
    
    func clearAll() {
        for volumeViewModel in volumes {
            volumeViewModel.isSelected = false
        }
    }

    func selectAll() {
        for volumeViewModel in volumes {
            volumeViewModel.isSelected = true
        }
    }

    private func potentialSizeAudio(for oldSize: SizeInfo?,
                                    and newSize: SizeInfo,
                                    of volume: VolumeViewModel,
                                    warningThreshold: UInt,
                                    badText: String,
                                    goodText: String,
                                    lowVolumes: inout Set<String>,
                                    with voice: VoiceActor.Voice)
    {
        if !volume.isSelected { return }

        // compare and see if we've crossed this threshold

        if lowVolumes.contains(volume.volume.name) { 
            if newSize.gigsFree > warningThreshold {
                lowVolumes.remove(volume.volume.name)

                let message = goodText
                  .replacingOccurrences(of: "$0", with: volume.volume.name)
                  .replacingOccurrences(of: "$1", with: "\(newSize.gigsFree)")

                say(message, as: voice)
            }
            return
        }

        let message = badText
          .replacingOccurrences(of: "$0", with: volume.volume.name)
          .replacingOccurrences(of: "$1", with: "\(newSize.gigsFree)")

        if let oldSize,
           oldSize.gigsFree >= warningThreshold,
           newSize.gigsFree < warningThreshold
        {
            say(message, as: voice)
            print("WARNING: \(volume.volume.name) oldSize.gigsFree \(oldSize.gigsFree) newSize.gigsFree \(newSize.gigsFree)")
            lowVolumes.insert(volume.volume.name)
        } else if newSize.gigsFree < warningThreshold {
            // no old size
            print("WARNING: \(volume.volume.name) newSize.gigsFree \(newSize.gigsFree)")
            
            say(message, as: voice)
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

        if shouldSave {
            // save them for later
            Task {
                do {
                    try await recordKeeper?.save(records: records)
                } catch {
                    print("cannot save volume records: \(error)")
                }
            }
        }

        // compute the time duration of records we have 
        let duration = Date().timeIntervalSince1970 - oldestTime(from: records)

        await MainActor.run {
            let startTime = Date().timeIntervalSince1970

            self.newVolumeSizes = records

            self.volumeRecordsTimeDurationSeconds = duration
            
            for volume in self.volumes {
                if let newSizes = newVolumeSizes[volume.volume.name] {
                    //print("volume.lastSize \(volume.lastSize)")

                    let oldSize = volume.lastSize
                    let newSize = newSizes.last
                    
                    volume.lastSize = newSize
                    volume.sizes = newSizes

                    if let oldSize,
                       let newSize
                    {
                        if preferences.soundVoiceOnErrors { 
                            potentialSizeAudio(for: oldSize,
                                               and: newSize,
                                               of: volume,
                                               warningThreshold: preferences.lowSpaceErrorThresholdGigs,
                                               badText: "Low Disk Space Error.  $0 is running EXTREMELY low on free space.  It now has only $1 gigabytes of free space left.",

                                               goodText: "$0 is no longer extremely low on free space.  It now has $1 gigabytes of free space left.",
                                               lowVolumes: &errorVolumes,
                                               with: preferences.errorVoice)
                        }
                        if preferences.soundVoiceOnWarnings { 
                            potentialSizeAudio(for: oldSize,
                                               and: newSize,
                                               of: volume,
                                               warningThreshold: preferences.lowSpaceWarningThresholdGigs,
                                               badText: "Low Disk Space Warning.  $0 is running low on free space.  It now has only $1 gigabytes of free space left.",

                                               goodText: "$0 is no longer low on free space.  It now has $1 gigabytes of free space left.",
                                               lowVolumes: &warningVolumes,
                                               with: preferences.warningVoice)
                        }
                    }
                    
                    //print("updating volume \(volume.volume.name) size to \(newSizes.count)")
                }
            }
            self.volumes.sort {
                $0.lastSize?.totalSize_k ?? 0 > $1.lastSize?.totalSize_k ?? 0
            }

            // apply colors here

            let volumesEmptyFirst = self.volumes.sorted {
                $0.lastFreeSize() > $1.lastFreeSize()
            }
            
            var colorIndex = 0
            var lastSelectedViewModel: VolumeViewModel? = nil
            var firstSelectedViewModel: VolumeViewModel? = nil
            for volumeViewModel in volumesEmptyFirst {
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

            let endTime = Date().timeIntervalSince1970
            print("view update took \(endTime-startTime) seconds")
        }
    }

    private func startTask() {
        self.task = Task {
            var isFirst = true
            // then iterate until we are cancelled
            while(true) {
                do {
                    await self.viewUpdate(records: try await manager.recordVolumeSizes())

                    try Task.checkCancellation()
                    if !isFirst {
                        let seconds = await MainActor.run { preferences.pollIntervalSeconds }
                        
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

    func updateManager() {
      Task {
       await self.manager.set(maxDataAgeMinutes: preferences.maxDataAgeMinutes)
      }
    }
    
    func update(for volumeViewModel: VolumeViewModel? = nil) { 
        if let volumeViewModel {
            if volumeViewModel.isSelected {
                self.preferences.volumesToShow.insert(volumeViewModel.volume.name)
            } else {
                self.preferences.volumesToShow.remove(volumeViewModel.volume.name)
            }
        }
        savePreferences()
    }

    func savePreferences() {
        let prefsToSave = self.preferences
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

