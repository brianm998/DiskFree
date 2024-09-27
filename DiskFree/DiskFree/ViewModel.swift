import SwiftUI
import Combine

typealias VolumeRecords = [String:[SizeInfo]]

class VolumeViewModel: ObservableObject,
                       Identifiable,
                       Hashable
{
    @Published var volume: Volume
    @Published var lastSize: SizeInfo?
    @Published public var isSelected = true
    @Published var sizes: [SizeInfo] = []

    var id = UUID()

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.volume)
    }
    
    static func == (lhs: VolumeViewModel, rhs: VolumeViewModel) -> Bool {
        lhs.volume == rhs.volume
    }

    public init(volume: Volume) {
        self.volume = volume
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

    var chartLineText: String {
        if let lastSize = self.lastSize {
            return "\(self.volume.name) - \(lastSize.freeSizeInt) free"
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
}

class PreferencesViewModel: ObservableObject {
    // this is tracked with published variables in the volume view models
    // used here for initial values, and also shadowing the view model observables
    var volumesToShow: Set<String>
    @Published var chooseDisksToMonitor: Bool
    @Published var showMultipleCharts: Bool
    @Published var showFreeSpace: Bool
    @Published var showUsedSpace: Bool

    init() {
        self.volumesToShow = []
        self.chooseDisksToMonitor = true
        self.showMultipleCharts = false
        self.showFreeSpace = true
        self.showUsedSpace = false
    }

    init(preferences: Preferences) {
        self.volumesToShow = Set(preferences.volumesToShow)
        self.chooseDisksToMonitor = preferences.chooseDisksToMonitor
        self.showMultipleCharts = preferences.showMultipleCharts
        self.showFreeSpace = preferences.showFreeSpace
        self.showUsedSpace = preferences.showUsedSpace
    }

    var preferencesToSave: Preferences {
        Preferences(volumesToShow: Array(volumesToShow),
                    chooseDisksToMonitor: self.chooseDisksToMonitor,
                    showMultipleCharts: self.showMultipleCharts,
                    showFreeSpace: self.showFreeSpace,
                    showUsedSpace: self.showUsedSpace)
    }
}

class VolumeListViewModel: ObservableObject {
    @Published var list: [VolumeViewModel] = []
}

@MainActor
public final class ViewModel: ObservableObject {
    @Published var volumes = VolumeListViewModel()
    @Published var preferences = PreferencesViewModel()

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
        
        Publishers.CombineLatest4(preferences.$chooseDisksToMonitor,
                                  preferences.$showMultipleCharts,
                                  preferences.$showFreeSpace,
                                  preferences.$showUsedSpace)
          .sink { _ in
              print("WOOT")     // XXX save preferences here
          }
          .store(in: &self.cancellables)

        /*
        preferences.$volumesToShow        
          .sink { _ in
              print("WOOT")     // XXX save preferences here
          }
          .store(in: &self.cancellables)*/
    }
    
    let manager = Manager()
    let recordKeeper = VolumeRecordKeeper()
    let preferenceManager = PreferenceManager()
    
    let seconds = 8            // XXX make this a published variable

    var newVolumeSizes: VolumeRecords = [:]
    
    func listVolumes() {
        Task {
            do {
                await self.loadStoredRecords()
                let volumes = try await manager.listVolumes()
                await MainActor.run {
                    self.volumes.list = volumes.map {
                        let ret = VolumeViewModel(volume: $0)

                        if preferences.volumesToShow.contains($0.name) {
                            ret.isSelected = true
                        } else {
                            ret.isSelected = false
                        }
                        return ret
                    }
                    self.objectWillChange.send()
                }
                self.startTaskWithInterval(of: seconds)
            } catch {
                print("ERROR: \(error)")
            }
        }
    }

    private var task: Task<Void,Never>?

    var volumesSortedEmptyFirst: [VolumeViewModel] {
        var list = self.volumes.list
        list.sort { $0.lastSize?.freeSize_k ?? 0 > $1.lastSize?.freeSize_k ?? 0 }
        return list
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
    
    private func viewUpdate(records: VolumeRecords, shouldSave: Bool = true) async {
        await MainActor.run {
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
                if let newSizes = newVolumeSizes[volume.volume.name] {
                    volume.lastSize = newSizes.last
                    volume.sizes = newSizes
                    print("updating volume \(volume.volume.name) size to \(newSizes.count)")
                }
            }
            self.volumes.list.sort {
                $0.lastSize?.totalSize_k ?? 0 > $1.lastSize?.totalSize_k ?? 0
            }
            self.objectWillChange.send()
        }
    }
    
    private func loadStoredRecords() async {
        // on startup, first load any stored records
        var storedRecords: VolumeRecords?
        do {
            storedRecords = try await recordKeeper?.loadRecords() 
            print("loaded stored records \(storedRecords?.count)")
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

