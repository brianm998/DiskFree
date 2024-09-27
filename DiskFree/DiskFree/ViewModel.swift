import SwiftUI

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

class VolumeListViewModel: ObservableObject {
    @Published var list: [VolumeViewModel] = []
}

@MainActor
public final class ViewModel: ObservableObject {
    @Published var volumes = VolumeListViewModel()
    @Published var showUsedSpace = false
    @Published var showFreeSpace = true
    @Published var showMultipleCharts = false
    @Published var showSideBar = true

    let manager = Manager()
    let recordKeeper = VolumeRecordKeeper()
    
    let seconds = 8            // XXX make this a published variable

    var newVolumeSizes: VolumeRecords = [:]
    
    func listVolumes() {
        Task {
            do {
                await self.loadStoredRecords()
                let volumes = try await manager.listVolumes()
                await MainActor.run {
                    self.volumes.list = volumes.map { VolumeViewModel(volume: $0) }
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
}

