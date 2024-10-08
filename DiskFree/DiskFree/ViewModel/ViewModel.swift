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
    var localVolumes: [VolumeViewModel] = []
    var networkVolumes: [VolumeViewModel] = []

    var allVolumes: [VolumeViewModel] {
        localVolumes + networkVolumes
    }
    
    var preferences = Preferences()
    
    var warningLocalVolumes: Set<String> = []
    var errorLocalVolumes: Set<String> = []
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

    let localVolumeRecordKeeper = LocalVolumeRecordKeeper()
    let networkVolumeRecordKeeper = NetworkVolumeRecordKeeper()
    
    let preferenceManager = PreferenceManager()
    
    var newLocalVolumeSizes: LocalVolumeRecords = [:]

    var newNetworkVolumeSizes: NetworkVolumeRecords = [:]

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

    var localVolumesSortedByEmptyFirst: [VolumeViewModel] {
        localVolumes.sorted { (a: VolumeViewModel, b: VolumeViewModel) in
            a.lastFreeSize() > b.lastFreeSize()
        } + networkVolumes
    }

    func listNetworkVolumes() {
        self.networkVolumeTask = Task {

            let storedRecords = await self.manager.loadStoredNetworkVolumeRecords() 

            var isFirst = true
            // then iterate until we are cancelled
            while(true) {
                do {
                    let (newNetworkVolumes, sizeRecords) =
                      try await manager.recordNetworkVolumeSizes()
                    
                    await self.networkRecordViewUpdate(volumes: newNetworkVolumes,
                                                       records: sizeRecords)

                    /*
                     reconcile the existing network volumes with new ones
                     create view models for new network volumes
                     */

                    for newVolume in newNetworkVolumes {
                        var isNew = true
                        for volumeView in networkVolumes {
                            if volumeView.volume == newVolume {

                                // set sizes here
                                if let sizes = sizeRecords[volumeView.volume.name] {
                                    volumeView.sizes = sizes
                                }
                                isNew = false
                                break
                            }
                        }

                        if isNew {
                            let viewModel = VolumeViewModel(volume: newVolume,
                                                                   color: .purple,
                                                                   preferences: preferences)
                            if let sizes = sizeRecords[newVolume.name] {
                                viewModel.sizes = sizes
                            }
                            self.networkVolumes.append(viewModel)
                        }
                    }
                  
                    try Task.checkCancellation()
                    if !isFirst {
                        let seconds = await MainActor.run { preferences.networkPollIntervalSeconds }
                        
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
    
    func listLocalVolumes() {
        Task {
            do {
                await self.manager.loadStoredLocalVolumeRecords()
                let volumes = try await manager.listLocalVolumes()
                if preferences.localVolumesToShow.count == 0 {
                    preferences.localVolumesToShow = Set(volumes.map { $0.name })
                }
                await MainActor.run {
                    var colorIndex = 0
                    self.localVolumes = volumes.map {
                        let ret = VolumeViewModel(volume: $0,
                                                  color: lineColors[colorIndex],
                                                  preferences: preferences)
                        colorIndex += 1
                        if colorIndex >= lineColors.count { colorIndex = 0 }

                        if preferences.localVolumesToShow.contains($0.name) {
                            ret.isSelected = true
                        } else {
                            ret.isSelected = false
                        }
                        return ret
                    }
                }
                self.startLocalVolumeTask()
            } catch {
                print("ERROR: \(error)")
            }
        }
    }

    private var localVolumeTask: Task<Void,Never>?
    private var networkVolumeTask: Task<Void,Never>?

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
        if localVolumes.count == 0,
           networkVolumes.count == 0
        {
            return 0
        }
        for volumeViewModel in localVolumes {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.minGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs < ret { ret = maxGigs }
            }
        }
        for volumeViewModel in networkVolumes {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.minGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs < ret { ret = maxGigs }
            }
        }
        return ret
    }

    private func maxGigs(showFree: Bool, showUsed: Bool) -> UInt {
        var ret: UInt = 0
        if localVolumes.count == 0,
           networkVolumes.count == 0
        {
            return UInt.max<<8
        }
        for volumeViewModel in localVolumes {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.maxGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs > ret { ret = maxGigs }
            }
        }
        for volumeViewModel in networkVolumes {
            if volumeViewModel.isSelected {
                let maxGigs = volumeViewModel.maxGigs(showFree: showFree, showUsed: showUsed)
                if maxGigs > ret { ret = maxGigs }
            }
        }
        return ret
    }
    
    func clearAll() {
        for volumeViewModel in localVolumes {
            volumeViewModel.isSelected = false
        }
    }

    func selectAll() {
        for volumeViewModel in localVolumes {
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

    private func networkRecordViewUpdate(volumes: [NetworkVolume],
                                         records: NetworkVolumeRecords,
                                         shouldSave: Bool = true) async
    {
        if shouldSave {
            // save them for later
            Task {
                do {
                    try await networkVolumeRecordKeeper?.save(records: records)
                } catch {
                    print("cannot save network volume records: \(error)")
                }
            }
        }


        await MainActor.run {
            self.newNetworkVolumeSizes = records

        }
        
        // XXX update the UI

        /*
         NEXT, populate the 
         networkVolumes set

         we may not have exactly the same list on each iteration, so add
         any that are new to networkVolumes

         then update the view model with new network info,
         like the local view update below
         */
    }

    private func localRecordViewUpdate(records: LocalVolumeRecords,
                                       shouldSave: Bool = true) async
    {

        if shouldSave {
            // save them for later
            Task {
                do {
                    try await localVolumeRecordKeeper?.save(records: records)
                } catch {
                    print("cannot save local volume records: \(error)")
                }
            }
        }

        // compute the time duration of records we have 
        let duration = Date().timeIntervalSince1970 - oldestTime(from: records)

        await MainActor.run {
            let startTime = Date().timeIntervalSince1970

            self.newLocalVolumeSizes = records

            self.volumeRecordsTimeDurationSeconds = duration
            
            for volume in self.localVolumes {
                if let newSizes = self.newLocalVolumeSizes[volume.volume.name] {
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
                                               lowVolumes: &errorLocalVolumes,
                                               with: preferences.errorVoice)
                        }
                        if preferences.soundVoiceOnWarnings { 
                            potentialSizeAudio(for: oldSize,
                                               and: newSize,
                                               of: volume,
                                               warningThreshold: preferences.lowSpaceWarningThresholdGigs,
                                               badText: "Low Disk Space Warning.  $0 is running low on free space.  It now has only $1 gigabytes of free space left.",

                                               goodText: "$0 is no longer low on free space.  It now has $1 gigabytes of free space left.",
                                               lowVolumes: &warningLocalVolumes,
                                               with: preferences.warningVoice)
                        }
                    }
                    
                    //print("updating volume \(volume.volume.name) size to \(newSizes.count)")
                }
            }
            self.localVolumes.sort {
                $0.lastSize?.totalSize_k ?? 0 > $1.lastSize?.totalSize_k ?? 0
            }

            // apply colors here

            let volumesEmptyFirst = self.localVolumes.sorted {
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

    private func startLocalVolumeTask() {
        self.localVolumeTask = Task {
            var isFirst = true
            // then iterate until we are cancelled
            while(true) {
                do {
                    await self.localRecordViewUpdate(records: try await manager.recordLocalVolumeSizes())

                    try Task.checkCancellation()
                    if !isFirst {
                        let seconds = await MainActor.run { preferences.localPollIntervalSeconds }
                        
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
    
    func update() {
        savePreferences()
    }

    func update(for volumeViewModel: VolumeViewModel? = nil) { 
        if let volumeViewModel {
            if volumeViewModel.isSelected {
                self.preferences.localVolumesToShow.insert(volumeViewModel.volume.name)
            } else {
                self.preferences.localVolumesToShow.remove(volumeViewModel.volume.name)
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

