import Testing
import Foundation
@testable import DiskFree

final class ProbeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return n }
    func hit() { lock.lock(); n += 1; lock.unlock() }
    func unhit() { lock.lock(); n -= 1; lock.unlock() }
    func set(_ v: Int) { lock.lock(); n = v; lock.unlock() }
}

@MainActor
struct ViewModelPollingTests {
    func nv() -> NetworkVolume {
        NetworkVolume(username: "u", remoteHost: "h", remotePath: "/p", localMount: "/Volumes/t", type: "smbfs")
    }

    func makeModel(counter: ProbeCounter) async -> ViewModel {
        let vm = ViewModel()
        vm.persistsToDisk = false
        vm.networkPollIntervalOverride = 0
        let v = nv()
        await vm.manager.setProbeOverride({ _, ts in
            counter.hit()
            Thread.sleep(forTimeInterval: 0.01)
            return SizeInfo(importantCapacity: 1, opportunisticCapacity: 1, totalCapacity: 2, timestamp: ts)
        })
        await vm.manager.setOverrides(mountListing: { [v] }, networkSize: nil)
        return vm
    }

    func waitUntil(_ cond: () -> Bool) async {
        for _ in 0..<300 where !cond() { try? await Task.sleep(nanoseconds: 10_000_000) }
    }

    @Test func stopPollingStopsNetworkLoop() async throws {
        let counter = ProbeCounter()
        let vm = await makeModel(counter: counter)
        vm.listNetworkVolumes()
        await waitUntil { counter.count >= 3 }
        #expect(counter.count >= 3)
        vm.stopPolling()
        try await Task.sleep(nanoseconds: 200_000_000) // let an in-flight poll finish
        let after = counter.count
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(counter.count == after)
    }

    @Test func secondListNetworkVolumesStartsNoSecondLoop() async throws {
        let counter = ProbeCounter()
        let vm = await makeModel(counter: counter)
        let active = ProbeCounter(), maxActive = ProbeCounter()
        let v = nv()
        // a single loop never has two mount listings in flight at once
        await vm.manager.setOverrides(mountListing: { [v] in
            active.hit()
            let now = active.count
            if now > maxActive.count { maxActive.set(now) }
            try await Task.sleep(nanoseconds: 20_000_000)
            active.unhit()
            return [v]
        }, networkSize: nil)
        vm.listNetworkVolumes()
        vm.listNetworkVolumes()
        await waitUntil { counter.count >= 5 }
        vm.stopPolling()
        #expect(counter.count >= 5)
        #expect(maxActive.count == 1)
    }
}
