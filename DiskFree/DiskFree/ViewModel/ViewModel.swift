import SwiftUI
import Combine


class VolumeListViewModel: ObservableObject {
    @Published var list: [VolumeViewModel] = [] // XXX make this Binding<VolumeViewModel>?
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
    

    /*

     move basically _all_ of this view update logic off of the main thread

     the backend should already know what the view has, and update the new
     set of records into it for it in the background, only updating up the
     updated view models on the main actor.

     
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
        
        await MainActor.run {
            let startTime = Date().timeIntervalSince1970

            self.newVolumeSizes = records

            for volume in self.volumes.list {
                volume.updateChartFreeLineText()
                if let newSizes = newVolumeSizes[volume.volume.name] {
                    //print("volume.lastSize \(volume.lastSize)")

                    if let oldSize = volume.lastSize,
                       let newSize = newSizes.last
                    {
                        potentialSizeWarning(for: oldSize, and: newSize, of: volume)
                    }
                    
                    volume.lastSize = newSizes.last
                    volume.set(sizes: newSizes)
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

            self.objectWillChange.send() // XXX get rid of this if we can
            /*
             only use published varables from the view model,
             and only use funcs in the view model to update those,
             not from the view code directly.
             
             */

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

