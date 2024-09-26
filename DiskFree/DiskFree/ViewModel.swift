import SwiftUI

class VolumeViewModel: ObservableObject,
                       Identifiable,
                       Hashable
{
    @Published var volume: Volume
    @Published var lastSize: SizeInfo?
    @Published var counter = 0
    @Published public var isSelected = false
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
}

class VolumeListViewModel: ObservableObject {
    @Published var list: [VolumeViewModel] = []
}

@MainActor
public final class ViewModel: ObservableObject {
    @Published var volumes = VolumeListViewModel()
    @Published var counter = 0

    let manager = Manager()

    let seconds = 12            // XXX make this a published variable

    var newVolumeSizes: [String:[SizeInfo]] = [:]
    
    func listVolumes() {
        Task {
            do {
                let volumes = try await manager.listVolumes()
                print("volumes.count \(volumes.count)")

                await MainActor.run {
                    self.volumes.list = volumes.map { VolumeViewModel(volume: $0) }
                    self.counter += 1
//                    self.volumes.objectWillChange.send()
                }
                self.startTaskWithInterval(of: seconds)
            } catch {
                print("ERROR: \(error)")
            }
        }
    }

    private var task: Task<Void,Never>?
    
    private func startTaskWithInterval(of seconds: Int) {
        self.task = Task {
            do {
                while(true) {
                    let newVolumeSizes: [String:[SizeInfo]] = try await manager.recordVolumeSizes()

                    // sort them here?
                    await MainActor.run {
                        self.newVolumeSizes = newVolumeSizes
                        for volume in self.volumes.list {
                            if let newSizes = newVolumeSizes[volume.volume.name] {
                                volume.lastSize = newSizes.last
                                volume.sizes = newSizes
                                volume.counter += 1
                                print("updating volume \(volume.volume.name) size to \(newSizes.count) counter \(volume.counter)")
                            }
                         }
                        self.volumes.list.sort {
                            $0.lastSize?.totalSize_k ?? 0 > $1.lastSize?.totalSize_k ?? 0
                        }
                        self.counter += 1
                     }
                    try Task.checkCancellation()
                    try await Task.sleep(nanoseconds: UInt64(seconds*1_000_000_000))
                    try Task.checkCancellation()
                }
            } catch {
                print("ERROR: \(error)")
            }
        }
    }
}

