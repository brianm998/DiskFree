import Testing
import Foundation
import AppKit
@testable import DiskFree

final class ListingBox: @unchecked Sendable {
    private let lock = NSLock()
    private var v: [LocalVolume] = []
    private var n = 0
    var volumes: [LocalVolume] { get { lock.lock(); defer { lock.unlock() }; return v }
                                 set { lock.lock(); v = newValue; lock.unlock() } }
    var calls: Int { lock.lock(); defer { lock.unlock() }; return n }
    func list() -> [LocalVolume] { lock.lock(); defer { lock.unlock() }; n += 1; return v }
}

@MainActor
struct MountNotificationTests {
    func vol(_ name: String) -> LocalVolume {
        LocalVolume(name: name, mountPoint: "/Volumes/\(name)", userVisibleMountPoint: "/Volumes/\(name)",
                    isInternal: false, isEjectable: true, uuid: "UUID-\(name)")
    }

    func size(freeGB: Int, totalGB: Int) -> SizeInfo {
        let gb = 1_000_000_000
        return SizeInfo(importantCapacity: freeGB*gb, opportunisticCapacity: freeGB*gb,
                        totalCapacity: totalGB*gb, timestamp: Date().timeIntervalSince1970)
    }

    func makeModel(_ box: ListingBox) async -> (ViewModel, NotificationCenter) {
        let vm = ViewModel()
        vm.persistsToDisk = false
        vm.mountDebounceSeconds = 0.05
        let center = NotificationCenter()
        vm.mountNotificationCenter = center
        await vm.manager.setLocalListingOverride { box.list() }
        return (vm, center)
    }

    func waitUntil(timeout: TimeInterval = 1, _ cond: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !cond() {
            if Date() >= deadline { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    @Test func mountNotificationAddsVolumeWithin1s() async {
        let box = ListingBox()
        box.volumes = [vol("A")]
        let (vm, center) = await makeModel(box)
        vm.startObservingMounts()
        vm.reconcileLocalVolumes(with: [vol("A")])
        box.volumes = [vol("A"), vol("B")]
        center.post(name: NSWorkspace.didMountNotification, object: nil)
        let ok = await waitUntil { vm.localVolumes.count == 2 }
        #expect(ok)
        vm.stopPolling()
    }

    @Test func unmountMarksDisconnectedAndExcludesFromRangeAndColors() async {
        let box = ListingBox()
        box.volumes = [vol("A"), vol("B")]
        let (vm, center) = await makeModel(box)
        vm.startObservingMounts()
        vm.reconcileLocalVolumes(with: box.volumes)
        let a = vm.localVolumes.first { $0.volume.name == "A" }!
        let b = vm.localVolumes.first { $0.volume.name == "B" }!
        a.sizes = [size(freeGB: 100, totalGB: 200)]; a.lastSize = a.sizes.last
        b.sizes = [size(freeGB: 900, totalGB: 1000)]; b.lastSize = b.sizes.last
        vm.applyColors()
        #expect(b.isMostEmpty && a.isMostFull)
        let before = vm.chartRange(showFree: true, showUsed: false)

        box.volumes = [vol("A")]
        center.post(name: NSWorkspace.didUnmountNotification, object: nil)
        let ok = await waitUntil { !b.isMounted }
        #expect(ok)
        #expect(a.isMounted)
        vm.applyColors()
        let after = vm.chartRange(showFree: true, showUsed: false)
        #expect(after.upperBound < before.upperBound)
        #expect(a.isMostFull && a.isMostEmpty)
        #expect(!b.isMostFull && !b.isMostEmpty)

        // remount keeps history
        box.volumes = [vol("A"), vol("B")]
        center.post(name: NSWorkspace.didMountNotification, object: nil)
        let back = await waitUntil { b.isMounted }
        #expect(back)
        #expect(b.sizes.count == 1)
        #expect(vm.localVolumes.count == 2)
        vm.stopPolling()
    }

    @Test func noRelistAfterStopPolling() async throws {
        let box = ListingBox()
        let (vm, center) = await makeModel(box)
        vm.startObservingMounts()
        vm.stopPolling()
        #expect(!vm.isObservingMounts)
        center.post(name: NSWorkspace.didMountNotification, object: nil)
        center.post(name: NSWorkspace.didUnmountNotification, object: nil)
        vm.handleMountNotification() // even called directly
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(box.calls == 0)
    }
}
