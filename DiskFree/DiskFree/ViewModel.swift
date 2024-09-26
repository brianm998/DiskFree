import SwiftUI

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

    let manager = Manager()

    let seconds = 8            // XXX make this a published variable

    var newVolumeSizes: [String:[SizeInfo]] = [:]
    
    func listVolumes() {
        Task {
            do {
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
    
    private func startTaskWithInterval(of seconds: Int) {
        self.task = Task {
            do {
                var isFirst = true
                while(true) {
                    let newVolumeSizes: [String:[SizeInfo]] = try await manager.recordVolumeSizes()

                    // sort them here?
                    await MainActor.run {
                        self.newVolumeSizes = newVolumeSizes
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
                    try Task.checkCancellation()
                    if !isFirst {
                        // don't sleep the first time so the graph updates quicker
                        try await Task.sleep(nanoseconds: UInt64(seconds*1_000_000_000))
                    }
                    try Task.checkCancellation()
                    isFirst = false 
                }
            } catch {
                print("ERROR: \(error)")
            }
        }
    }
}

