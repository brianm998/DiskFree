import Testing
import Foundation
@testable import DiskFree

struct ManagerTests {
    func vol(_ name: String, _ path: String) -> LocalVolume {
        LocalVolume(name: name, mountPoint: path, userVisibleMountPoint: path,
                    isInternal: true, isEjectable: false)
    }

    let bad = "/Volumes/does-not-exist-\(UUID().uuidString)"

    @Test func failingVolumeFirstDoesNotAbortPoll() async throws {
        let m = Manager()
        await m.set(volumes: [vol("bad", bad), vol("good", "/")])
        let records = try await m.recordLocalVolumeSizes()
        #expect(records["good"]?.count == 1)
        #expect(records["bad"] == nil)
    }

    @Test func failingVolumeLastDoesNotAbortPoll() async throws {
        let m = Manager()
        await m.set(volumes: [vol("good", "/"), vol("bad", bad)])
        let records = try await m.recordLocalVolumeSizes()
        #expect(records["good"]?.count == 1)
    }

    @Test func recoversOnNextPoll() async throws {
        let m = Manager()
        await m.set(volumes: [vol("v", bad)])
        let first = try await m.recordLocalVolumeSizes()
        #expect(first["v"] == nil)
        await m.set(volumes: [vol("v", "/")])
        let second = try await m.recordLocalVolumeSizes()
        #expect(second["v"]?.count == 1)
    }
}

@MainActor
struct ReconcileTests {
    func vol(_ name: String, _ path: String) -> LocalVolume {
        LocalVolume(name: name, mountPoint: path, userVisibleMountPoint: path,
                    isInternal: true, isEjectable: false)
    }

    @Test func changedMountPointKeepsViewModel() {
        let vm = ViewModel()
        vm.preferences.localVolumesToShow = ["A"]
        vm.reconcileLocalVolumes(with: [vol("A", "/Volumes/A")])
        let original = vm.localVolumes[0]
        original.isSelected = false
        let id = original.id
        vm.reconcileLocalVolumes(with: [vol("A", "/Volumes/A 1")])
        #expect(vm.localVolumes.count == 1)
        #expect(vm.localVolumes[0] === original)
        #expect(vm.localVolumes[0].id == id)
        #expect(vm.localVolumes[0].isSelected == false)
        if case .local(let v) = vm.localVolumes[0].volume {
            #expect(v.mountPoint == "/Volumes/A 1")
        } else { Issue.record("not local") }
    }

    @Test func newVolumeAppendedAndMissingKept() {
        let vm = ViewModel()
        vm.preferences.localVolumesToShow = ["A"]
        vm.reconcileLocalVolumes(with: [vol("A", "/Volumes/A")])
        vm.reconcileLocalVolumes(with: [vol("B", "/Volumes/B")])
        #expect(vm.localVolumes.map { $0.volume.name } == ["A", "B"])
        #expect(vm.localVolumes[0].isSelected == true)
        #expect(vm.localVolumes[1].isSelected == false)
    }

    @Test func rediscoveryInterval() {
        #expect(ViewModel.rediscoveryPollCount(pollIntervalSeconds: 10) == 6)
        #expect(ViewModel.rediscoveryPollCount(pollIntervalSeconds: 120) == 1)
        #expect(ViewModel.rediscoveryPollCount(pollIntervalSeconds: 0) == 1)
    }
}
