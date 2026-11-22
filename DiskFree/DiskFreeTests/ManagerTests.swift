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

struct NetworkPollTests {
    func nv(_ mount: String) -> NetworkVolume {
        NetworkVolume(username: "u", remoteHost: "h", remotePath: "/p", localMount: mount, type: "smbfs")
    }

    @Test func previouslySeenVolumeStillPolledWhenMissingFromMount() async throws {
        let a = nv("/Volumes/a"), b = nv("/Volumes/b")
        let listings = Listings([[a, b], [a]])
        let m = Manager()
        await m.setOverrides(
            mountListing: { await listings.next() },
            networkSize: { _, ts in
                SizeInfo(importantCapacity: 1, opportunisticCapacity: 1, totalCapacity: 2, timestamp: ts)
            })
        _ = try await m.recordNetworkVolumeSizes()
        let (vols, records) = try await m.recordNetworkVolumeSizes()
        #expect(vols.map(\.localMount) == ["/Volumes/a", "/Volumes/b"])
        #expect(records["/Volumes/b"]?.count == 2)
        #expect(records["/Volumes/a"]?.count == 2)
    }
}

struct NetworkProbeTests {
    @Test func hungProbeTimesOutAndOthersStillReport() async throws {
        let hung = NetworkVolume(username: "u", remoteHost: "h", remotePath: "/p",
                                 localMount: "/Volumes/hung", type: "smbfs")
        let ok = NetworkVolume(username: "u", remoteHost: "h", remotePath: "/p",
                               localMount: "/Volumes/ok", type: "smbfs")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let m = Manager()
        await m.setProbeOverride({ path, ts in
            if path == "/Volumes/hung" { release.wait() }
            return SizeInfo(importantCapacity: 1, opportunisticCapacity: 1, totalCapacity: 2, timestamp: ts)
        }, timeout: 0.5)
        await m.setOverrides(mountListing: { [hung, ok] }, networkSize: nil)
        let start = Date()
        let (_, records) = try await m.recordNetworkVolumeSizes()
        #expect(Date().timeIntervalSince(start) < 3)
        #expect(records["/Volumes/ok"]?.count == 1)
        #expect(records["/Volumes/hung"] == nil)
    }
}

struct RootSymlinkTests {
    @Test func mapsRealPathToUserPath() {
        let m = Manager.rootSymlinkMap(from: [
            ("home", "/System/Volumes/Data/home"),
            ("op", "Volumes/op"),
            ("etc", "private/etc"),
        ])
        #expect(m["/System/Volumes/Data/home"] == "/home")
        #expect(m["/Volumes/op"] == "/op")
        #expect(m["/private/etc"] == "/etc")
    }
}

actor Listings {
    var items: [[NetworkVolume]]
    init(_ items: [[NetworkVolume]]) { self.items = items }
    func next() -> [NetworkVolume] { items.isEmpty ? [] : items.removeFirst() }
}

@MainActor
struct ReconcileTests {
    func vol(_ name: String, _ path: String) -> LocalVolume {
        LocalVolume(name: name, mountPoint: path, userVisibleMountPoint: path,
                    isInternal: true, isEjectable: false)
    }

    @Test func changedMountPointKeepsViewModel() {
        let vm = ViewModel()
        vm.preferences.localVolumesHidden = ["B"]
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
        vm.preferences.localVolumesHidden = ["B"]
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

struct KnownShareTests {
    static func vol(_ m: String) -> NetworkVolume {
        NetworkVolume(username: "", remoteHost: "h", remotePath: "/p", localMount: m, type: "nfs")
    }
    static func ok(_ path: String, _ ts: TimeInterval) -> SizeInfo? {
        SizeInfo(importantCapacity: 1, opportunisticCapacity: 1, totalCapacity: 2, timestamp: ts)
    }

    @Test func mountPointMismatchYieldsNoSample() {
        #expect(Manager.mountMatches(mountOn: "/System/Volumes/Data/mnt/a", expectedMount: "/mnt/a"))
        #expect(!Manager.mountMatches(mountOn: "/System/Volumes/Data", expectedMount: "/mnt/a"))
        var fs = statfs()
        withUnsafeMutableBytes(of: &fs.f_mntonname) { buf in
            for (i, b) in "/System/Volumes/Data".utf8.enumerated() { buf[i] = b }
        }
        fs.f_bsize = 4096; fs.f_blocks = 100; fs.f_bavail = 50; fs.f_bfree = 50
        #expect(Manager.sample(from: fs, expectedMount: "/mnt/a", timestamp: 1) == nil)
    }

    @Test func savedKnownSharesAreProbedAfterReload() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let a = Manager()
        await a.setRecordDirectory(dir)
        await a.setProbeOverride(Self.ok)
        await a.setOverrides(mountListing: { [Self.vol("/mnt/a")] }, networkSize: nil)
        _ = try await a.recordNetworkVolumeSizes()

        let b = Manager()
        await b.setRecordDirectory(dir)
        await b.setProbeOverride(Self.ok)
        await b.setOverrides(mountListing: { [] }, networkSize: nil)
        _ = await b.loadStoredNetworkVolumeRecords()
        let (vols, records) = try await b.recordNetworkVolumeSizes()
        #expect(vols.map(\.localMount) == ["/mnt/a"])
        #expect(records["/mnt/a"]?.isEmpty == false)
    }

    @Test func knownSharesExpireAfter24h() async throws {
        let m = Manager()
        let t0 = Date()
        await m.setClock { t0 }
        await m.setProbeOverride({ _, _ in nil })
        await m.setOverrides(mountListing: { [Self.vol("/mnt/a")] }, networkSize: nil)
        _ = try await m.recordNetworkVolumeSizes()
        #expect(await m.knownShareMounts == ["/mnt/a"])
        await m.setOverrides(mountListing: { [] }, networkSize: nil)
        await m.setClock { t0.addingTimeInterval(23 * 3600) }
        _ = try await m.recordNetworkVolumeSizes()
        #expect(await m.knownShareMounts == ["/mnt/a"])
        await m.setClock { t0.addingTimeInterval(25 * 3600) }
        let (vols, _) = try await m.recordNetworkVolumeSizes()
        #expect(vols.isEmpty)
        #expect(await m.knownShareMounts.isEmpty)
    }
}
