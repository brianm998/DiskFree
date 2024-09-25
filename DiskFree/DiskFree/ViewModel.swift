import SwiftUI

@MainActor
public final class ViewModel: ObservableObject {
    @Published var volumes: [Volume] = []
    @Published var volumeSizes: [Volume:SizeInfo] = [:]

    let manager = Manager()

    let seconds = 20
    
    func listVolumes() {
        Task {
            do {
                let volumes = try await manager.listVolumes()
                var viewVolumes: [Volume] = []
                for volume in volumes {
                    viewVolumes.append(volume)
                }
                print("viewVolumes.count \(viewVolumes.count)")
                await MainActor.run { self.volumes = viewVolumes }
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
                    let newVolumeSizes = try await manager.recordVolumeSizes()
                    await MainActor.run { self.volumeSizes = newVolumeSizes }
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

