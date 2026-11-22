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
        #expect(records["/"]?.count == 1)
        #expect(records[bad] == nil)
    }

    @Test func failingVolumeLastDoesNotAbortPoll() async throws {
        let m = Manager()
        await m.set(volumes: [vol("good", "/"), vol("bad", bad)])
        let records = try await m.recordLocalVolumeSizes()
        #expect(records["/"]?.count == 1)
    }

    @Test func recoversOnNextPoll() async throws {
        let m = Manager()
        await m.set(volumes: [vol("v", bad)])
        let first = try await m.recordLocalVolumeSizes()
        #expect(first[bad] == nil)
        await m.set(volumes: [vol("v", "/")])
        let second = try await m.recordLocalVolumeSizes()
        #expect(second["/"]?.count == 1)
    }
}

extension LocalProbeSeam {
    static func fake(mountOn: @escaping @Sendable (String) -> String,
                     capacity: @escaping @Sendable (String) -> (important: Int, opportunistic: Int)? = { _ in (900, 950) },
                     uuid: @escaping @Sendable (String) -> String? = { _ in nil },
                     statfs: (@Sendable (String) -> Void)? = nil) -> LocalProbeSeam
    {
        LocalProbeSeam(
            statfs: { path, ts in
                statfs?(path)
                return LocalStatfs(mountOn: mountOn(path),
                                   size: SizeInfo(importantCapacity: 800, opportunisticCapacity: 800,
                                                  totalCapacity: 1000, timestamp: ts))
            },
            capacity: capacity, uuid: uuid)
    }
}

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    private var live = 0
    private(set) var maxLive = 0
    var count: Int { lock.lock(); defer { lock.unlock() }; return n }
    func hit() { lock.lock(); n += 1; lock.unlock() }
    func enter() { lock.lock(); live += 1; maxLive = max(maxLive, live); lock.unlock() }
    func leave() { lock.lock(); live -= 1; lock.unlock() }
}

struct LocalProbeTests {
    func vol(_ name: String, _ path: String, uuid: String? = nil) -> LocalVolume {
        LocalVolume(name: name, mountPoint: path, userVisibleMountPoint: path,
                    isInternal: true, isEjectable: true, uuid: uuid)
    }

    @Test func stalledVolumeDelaysNeitherOthersNorNetworkPoll() async throws {
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let m = Manager()
        await m.setLocalProbe(.fake(mountOn: { $0 }, statfs: { if $0 == "/hung" { release.wait() } }),
                              timeout: 0.5)
        await m.set(volumes: [vol("h", "/hung"), vol("a", "/a"), vol("b", "/b")])
        let net = NetworkVolume(username: "u", remoteHost: "h", remotePath: "/p",
                                localMount: "/Volumes/n", type: "smbfs")
        await m.setOverrides(mountListing: { [net] }, networkSize: { _, ts in
            SizeInfo(importantCapacity: 1, opportunisticCapacity: 1, totalCapacity: 2, timestamp: ts)
        })
        let start = Date()
        async let local = m.recordLocalVolumeSizes()
        async let network = m.recordNetworkVolumeSizes()
        let (records, (_, netRecords)) = try await (local, network)
        #expect(Date().timeIntervalSince(start) < 3)
        #expect(records["/a"]?.count == 1)
        #expect(records["/b"]?.count == 1)
        #expect(records["/hung"] == nil)
        #expect(netRecords["/Volumes/n"]?.count == 1)
    }

    @Test func atMostOneProbePerVolumeInFlight() async throws {
        let release = DispatchSemaphore(value: 0)
        let c = Counter()
        let m = Manager()
        await m.setLocalProbe(.fake(mountOn: { $0 }, statfs: { _ in
            c.enter(); c.hit(); release.wait(); c.leave()
        }), timeout: 0.2)
        await m.set(volumes: [vol("h", "/hung")])
        _ = try await m.recordLocalVolumeSizes()
        _ = try await m.recordLocalVolumeSizes()
        _ = try await m.recordLocalVolumeSizes()
        #expect(c.count == 1)
        #expect(c.maxLive == 1)
        release.signal()
    }

    @Test func importantUsageLookedUpOncePerMinutePerVolume() async throws {
        let c = Counter()
        let now = Locked(Date())
        let m = Manager()
        await m.setClock { now.value }
        await m.setLocalProbe(.fake(mountOn: { $0 }, capacity: { _ in c.hit(); return (900, 950) }))
        await m.set(volumes: [vol("a", "/a")])
        var records = try await m.recordLocalVolumeSizes()
        now.value += 4
        _ = try await m.recordLocalVolumeSizes()
        now.value += 4
        records = try await m.recordLocalVolumeSizes()
        #expect(c.count == 1)
        // purgeable offset (900 - 800) is applied to the statfs value
        #expect(records["/a"]?.last?.importantCapacity == 900)
        #expect(records["/a"]?.last?.opportunisticCapacity == 950)
        now.value += 60
        _ = try await m.recordLocalVolumeSizes()
        #expect(c.count == 2)
    }

    @Test func wrongMountPointRecordsNothingAndRequestsRelist() async throws {
        let m = Manager()
        await m.setLocalProbe(.fake(mountOn: { _ in "/" }))
        await m.set(volumes: [vol("x", "/Volumes/x")])
        let records = try await m.recordLocalVolumeSizes()
        #expect(records["/Volumes/x"] == nil)
        #expect(await m.takeRelistRequest())
        #expect(await m.takeRelistRequest() == false)
    }

    @Test func wrongUUIDRecordsNothing() async throws {
        let m = Manager()
        let good = UUID().uuidString
        await m.setLocalProbe(.fake(mountOn: { $0 }, uuid: { _ in UUID().uuidString }))
        await m.set(volumes: [vol("x", "/Volumes/x", uuid: good)])
        let records = try await m.recordLocalVolumeSizes()
        #expect(records[good] == nil)
        #expect(await m.takeRelistRequest())
    }
}

final class Locked<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var v: T
    init(_ v: T) { self.v = v }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return v }
        set { lock.lock(); v = newValue; lock.unlock() }
    }
}

struct VolumeKeyTests {
    func vol(_ name: String, _ path: String, uuid: String? = nil) -> LocalVolume {
        LocalVolume(name: name, mountPoint: path, userVisibleMountPoint: path,
                    isInternal: true, isEjectable: false, uuid: uuid)
    }
    let u1 = UUID().uuidString, u2 = UUID().uuidString

    func tempDir() throws -> String {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d.path
    }

    @Test func keyIsUUIDOrMountPoint() {
        #expect(vol("a", "/Volumes/a", uuid: u1).key == u1)
        #expect(vol("a", "/Volumes/a").key == "/Volumes/a")
        #expect(vol("a", "/Volumes/a", uuid: u1) != vol("a", "/Volumes/a 1", uuid: u2))
        #expect(vol("a", "/Volumes/a", uuid: u1) == vol("b", "/Volumes/b", uuid: u1))
    }

    @Test func sameNamedVolumesKeepSeparateRecordsWithoutDuplicateTimestamps() async throws {
        let m = Manager()
        // temp dirs are not mount points, so stand in for statfs
        await m.setLocalProbe(.fake(mountOn: { $0 }))
        await m.set(volumes: [vol("Untitled", try tempDir(), uuid: u1),
                              vol("Untitled", try tempDir(), uuid: u2)])
        _ = try await m.recordLocalVolumeSizes()
        let records = try await m.recordLocalVolumeSizes()
        #expect(records.count == 2)
        #expect(records[u1]?.count == 2)
        #expect(records[u2]?.count == 2)
        for list in records.values {
            #expect(Set(list.map(\.timestamp)).count == list.count)
        }
    }

    @Test func nameKeysMigrateWhenUnique() {
        let s = SizeInfo(importantCapacity: 1, opportunisticCapacity: 1, totalCapacity: 2, timestamp: 1)
        let vols = [vol("A", "/Volumes/A", uuid: u1), vol("Dup", "/Volumes/D1", uuid: u2),
                    vol("Dup", "/Volumes/D2", uuid: UUID().uuidString)]
        let stored: LocalVolumeRecords = ["A": [s], "Dup": [s], "Gone": [s], u2: [s]]
        let out = Manager.migrateNameKeys(stored, volumes: vols) { a, b in a + b }
        #expect(Set(out.keys) == [u1, u2])
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
    func vol(_ name: String, _ path: String, uuid: String? = nil) -> LocalVolume {
        LocalVolume(name: name, mountPoint: path, userVisibleMountPoint: path,
                    isInternal: true, isEjectable: false, uuid: uuid)
    }

    @Test func changedMountPointKeepsViewModel() {
        let vm = ViewModel()
        vm.preferences.localVolumesHidden = ["/Volumes/B"]
        let uuid = UUID().uuidString
        vm.reconcileLocalVolumes(with: [vol("A", "/Volumes/A", uuid: uuid)])
        let original = vm.localVolumes[0]
        original.isSelected = false
        let id = original.id
        vm.reconcileLocalVolumes(with: [vol("A", "/Volumes/A 1", uuid: uuid)])
        #expect(vm.localVolumes.count == 1)
        #expect(vm.localVolumes[0] === original)
        #expect(vm.localVolumes[0].id == id)
        #expect(vm.localVolumes[0].isSelected == false)
        if case .local(let v) = vm.localVolumes[0].volume {
            #expect(v.mountPoint == "/Volumes/A 1")
        } else { Issue.record("not local") }
    }

    @Test func sameNamedVolumesStaySeparate() {
        let vm = ViewModel()
        let u1 = UUID().uuidString, u2 = UUID().uuidString
        vm.reconcileLocalVolumes(with: [vol("X", "/Volumes/X", uuid: u1), vol("X", "/Volumes/X 1", uuid: u2)])
        #expect(vm.localVolumes.count == 2)
    }

    @Test func renameKeepsViewModel() {
        let vm = ViewModel()
        let u = UUID().uuidString
        vm.reconcileLocalVolumes(with: [vol("Old", "/Volumes/Old", uuid: u)])
        let original = vm.localVolumes[0]
        original.isSelected = false
        original.sizes = [SizeInfo(importantCapacity: 1, opportunisticCapacity: 1, totalCapacity: 2, timestamp: 1)]
        vm.reconcileLocalVolumes(with: [vol("New", "/Volumes/New", uuid: u)])
        #expect(vm.localVolumes.count == 1)
        #expect(vm.localVolumes[0] === original)
        #expect(original.isSelected == false)
        #expect(original.sizes.count == 1)
        #expect(original.volume.name == "New")
    }

    @Test func hiddenNamesMigrateToKeys() {
        let vm = ViewModel()
        let u = UUID().uuidString
        vm.persistsToDisk = false
        vm.preferences.localVolumesHidden = ["B", "Gone"]
        vm.migrateHiddenNames(discovered: [vol("A", "/Volumes/A"), vol("B", "/Volumes/B", uuid: u)])
        #expect(vm.preferences.localVolumesHidden == [u])
    }

    @Test func newVolumeAppendedAndMissingKept() {
        let vm = ViewModel()
        vm.preferences.localVolumesHidden = ["/Volumes/B"]
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
