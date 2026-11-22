import Foundation
import DiskArbitration
import os

/*

 todo:

 - allow removing items from chart?
 - add loading animation at start
 - missing visual error messages to user
 - show on chart where low space threshold is
   - allow changing it by dragging it
 - create app icon

 - look into this:
   diskutil info -plist /
 - and also this:
 https://developer.apple.com/documentation/foundation/urlresourcekey/checking_volume_storage_capacity

 - allow toggle between showing important and Opportunistic Usage
 - find how to identify backup volumes



 - plan for NAS

   run `mount` to see what is there

//floof@mammoth/mammoth on /System/Volumes/Data/mammoth (smbfs, nodev, nosuid, automounted, noowners, nobrowse, mounted by brian)
//admin@goliath.local/branch on /System/Volumes/Data/mnt/branch (afpfs, nodev, nosuid, automounted, nobrowse, mounted by brian)
//admin@goliath.local/trunk on /System/Volumes/Data/mnt/trunk (afpfs, nodev, nosuid, automounted, nobrowse, mounted by brian)
//admin@colossus.local/tree on /System/Volumes/Data/mnt/tree (afpfs, nodev, nosuid, automounted, nobrowse, mounted by brian)
//admin@beast.local/root on /System/Volumes/Data/mnt/root (afpfs, nodev, nosuid, automounted, nobrowse, mounted by brian)

   any no longer active volumes will no longer show up on this list

   have a different schedule for checking remote volumes
   write out a different json file as well

   each time, run `mount` to see what's there
    - add any new network volumes
    - make inactive any that are no longer there
    - query any that are present with the df logic we used to use for local drives
 */

public actor Manager: Sendable {

    private var volumes: [LocalVolume] = []

    private let inFlightProbes = InFlightProbes() // network mounts with a statfs outstanding
    
    private var localVolumeSizes: LocalVolumeRecords = [:] // keyed by volume.key
    private var networkVolumeSizes: NetworkVolumeRecords = [:] // keyed by volume.localMount

    // every network volume seen this run, keyed by localMount. Automounted
    // shares vanish from `mount` when idle but still work (and remount on access)
    // (persisted, and forgotten after `knownShareExpiry` without a sample)
    private var knownNetworkVolumes: [String: KnownNetworkVolume] = [:]

    static let knownShareExpiry: TimeInterval = 24 * 3600

    // test seams: the clock, and where network records are kept
    var clock: @Sendable () -> Date = { Date() }
    var recordDirectory: URL?

    func setClock(_ clock: @escaping @Sendable () -> Date) { self.clock = clock }
    func setRecordDirectory(_ url: URL?) { recordDirectory = url }

    var knownShareMounts: [String] { knownNetworkVolumes.keys.sorted() }

    var dfTimeoutSeconds: TimeInterval = 10
    var localTimeoutSeconds: TimeInterval = 5

    private let localInFlight = InFlightProbes() // local volumes with a probe outstanding
    private let capacityCache = CapacityCache()
    private var relistRequested = false
    // test seam: replaces the system calls of a local probe (run on a background thread)
    var localProbe = LocalProbeSeam.live

    func setLocalProbe(_ probe: LocalProbeSeam, timeout: TimeInterval? = nil) {
        localProbe = probe
        if let timeout { localTimeoutSeconds = timeout }
    }

    // test seam: replaces the output of `mount`
    // test seam: replaces the listing of local volumes
    var localListingOverride: (@Sendable () async throws -> [LocalVolume])?
    func setLocalListingOverride(_ l: (@Sendable () async throws -> [LocalVolume])?) { localListingOverride = l }
    var mountListingOverride: (@Sendable () async throws -> [NetworkVolume])?
    // test seam: replaces the statfs probe of a network mount (runs on a background thread)
    var networkProbeOverride: (@Sendable (String, TimeInterval) -> SizeInfo?)?
    // test seam: replaces the size lookup of a network volume
    var networkSizeOverride: (@Sendable (NetworkVolume, TimeInterval) async throws -> SizeInfo?)?

    func setProbeOverride(_ probe: (@Sendable (String, TimeInterval) -> SizeInfo?)?, timeout: TimeInterval? = nil) {
        networkProbeOverride = probe
        if let timeout { dfTimeoutSeconds = timeout }
    }

    func setOverrides(mountListing: (@Sendable () async throws -> [NetworkVolume])?,
                      networkSize: (@Sendable (NetworkVolume, TimeInterval) async throws -> SizeInfo?)?)
    {
        mountListingOverride = mountListing
        networkSizeOverride = networkSize
    }

    /// Records stored under a volume name move to the key of the one mounted
    /// volume with that name; names that match none or several are dropped.
    /// Entries that already look like keys (UUID or path) are kept, so an
    /// unplugged drive keeps its history.
    static func migrateNameKeys<T>(_ stored: [String: T],
                                   volumes: [LocalVolume],
                                   merge: (T, T) -> T) -> [String: T]
    {
        let keys = Set(volumes.map(\.key))
        var out: [String: T] = [:]
        func add(_ key: String, _ value: T) {
            if let old = out[key] { out[key] = merge(old, value) } else { out[key] = value }
        }
        for (key, value) in stored {
            if keys.contains(key) || LocalVolume.looksLikeKey(key) {
                add(key, value)
            } else {
                let matches = volumes.filter { $0.name == key }
                if matches.count == 1 { add(matches[0].key, value) }
            }
        }
        return out
    }

    public func loadStoredLocalVolumeRecords() async {
        await loadStoredLocalVolumeRecords(volumes: volumes)
    }

    func loadStoredLocalVolumeRecords(volumes: [LocalVolume]) async {
        do {
            if let recordKeeper = LocalVolumeRecordKeeper() {
                let stored = try await recordKeeper.loadRecords()
                let initialSizes = Self.migrateNameKeys(stored, volumes: volumes) { a, b in
                    (a + b).sorted { $0.timestamp < $1.timestamp }
                }

                localVolumeSizes = initialSizes
                Log.persistence.info("loaded stored records \(initialSizes.count, privacy: .public)")
            } 
        } catch {
            Log.persistence.error("error loading stored records: \(error, privacy: .public)")
        }
    }
    
    public func loadStoredNetworkVolumeRecords() async -> NetworkVolumeRecords? {
        do {
            if let recordKeeper = NetworkVolumeRecordKeeper(directory: recordDirectory) {
                // seed known shares so idle automounted ones are probed (and remounted)
                do {
                    for k in try await recordKeeper.loadKnown() {
                        knownNetworkVolumes[k.volume.localMount] = k
                    }
                } catch {
                    Log.persistence.error("error loading known network volumes: \(error, privacy: .public)")
                }
                let initialSizes = try await recordKeeper.loadRecords()

                networkVolumeSizes = initialSizes
                Log.persistence.info("loaded stored records \(initialSizes.count, privacy: .public)")

                return initialSizes
            } 
        } catch {
            Log.persistence.error("error loading stored records: \(error, privacy: .public)")
        }
        return nil
    }
    
    // data older than this is discarded
    private var maxDataAgeMinutes: TimeInterval = 60
    
    // keep track of volume sizes

    func set(volumes: [LocalVolume]) {
        self.volumes = volumes
    }

    func set(maxDataAgeMinutes: TimeInterval) {
        self.maxDataAgeMinutes = maxDataAgeMinutes
    }

    func readNetworkVolumes() async throws -> [NetworkVolume] {
        // statfs gives f_mntfromname like //floof@mammoth/mammoth, f_mntonname
        // like /System/Volumes/Data/mammoth and f_fstypename like smbfs / afpfs
        NetworkVolume.mounted()
    }

    // maps the real path of a root symlink to its user visible path, e.g.
    // /Volumes/op -> /op. `links` is (name in /, symlink destination)
    static func rootSymlinkMap(from links: [(name: String, destination: String)]) -> [String: String] {
        var ret: [String: String] = [:]
        for (name, destination) in links {
            var rootPath = name
            var realPath = destination
            if !realPath.starts(with: "/") { realPath = "/\(realPath)" }
            if !rootPath.starts(with: "/") { rootPath = "/\(rootPath)" }
            ret[realPath] = rootPath
        }
        return ret
    }

    func readRootSymlinks() async throws -> [String: String] { // /Volumes/op -> /op
        // /etc/synthetic.conf is not readable, but the links in / are
        let fm = FileManager.default
        var links: [(name: String, destination: String)] = []
        for name in try fm.contentsOfDirectory(atPath: "/") {
            if let destination = try? fm.destinationOfSymbolicLink(atPath: "/" + name) {
                links.append((name, destination))
            }
        }
        return Self.rootSymlinkMap(from: links)
    }

    /// True when DiskArbitration says the volume is a mounted disk image.
    /// DADiskCreateFromVolumePath only reads the mount table, so it needs no
    /// entitlement in the app sandbox.  If it can't answer, the volume is
    /// treated as a physical drive (shown rather than hidden).
    static func isDiskImage(url: URL) -> Bool {
        guard let session = DASessionCreate(kCFAllocatorDefault),
              let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, url as CFURL),
              let desc = DADiskCopyDescription(disk) as? [String: Any]
        else { return false }
        let model = (desc[kDADiskDescriptionDeviceModelKey as String] as? String)?
            .trimmingCharacters(in: .whitespaces)
        let proto = desc[kDADiskDescriptionDeviceProtocolKey as String] as? String
        return model == "Disk Image" || proto == "Virtual Interface"
    }

    func listLocalVolumes() async throws -> [LocalVolume] {
        if let localListingOverride {
            let ret = try await localListingOverride()
            self.volumes = ret
            return ret
        }

        let rootSymlinks = try await readRootSymlinks()

        let keys: [URLResourceKey] = [
            .volumeNameKey,             // displayed and spoken
            .volumeUUIDStringKey,       // keys the persisted records
            .volumeIsLocalKey,
            .volumeIsRootFileSystemKey, // identifies which volume is '/'
            .volumeIsInternalKey,
            .volumeIsEjectableKey,
            .volumeIsBrowsableKey,      // used to filter out volumes user shouldn't see
            .volumeIsReadOnlyKey,
        ]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                         options: []) ?? []

        var ret: [LocalVolume] = []

        for url in urls {
            do {
                let values = try url.resourceValues(forKeys: Set(keys))
                guard let isRoot = values.volumeIsRootFileSystem,
                      let volumeName = values.volumeName
                else { continue }
                let isReadOnly = values.volumeIsReadOnly == true
                // only read-only volumes need the (costlier) disk image check
                let isDiskImage = isReadOnly && !isRoot && Self.isDiskImage(url: url)
                guard LocalVolume.shouldList(isLocal: values.volumeIsLocal == true,
                                             isBrowsable: values.volumeIsBrowsable == true,
                                             isReadOnly: isReadOnly,
                                             isRoot: isRoot,
                                             isDiskImage: isDiskImage)
                else { continue }

                let mountPoint = url.path
                // the user visible mount point is still a valid path,
                // but may be a symlink or such, so we can't query at that
                // path for volume size, have to use the real mountPoint for that
                var userVisibleMountPoint = mountPoint
                if isRoot {
                    userVisibleMountPoint = "/"
                } else if let rootSymlink = rootSymlinks[mountPoint] {
                    userVisibleMountPoint = rootSymlink
                }
                ret.append(LocalVolume(name: volumeName,
                                       mountPoint: mountPoint,
                                       userVisibleMountPoint: userVisibleMountPoint,
                                       isInternal: values.volumeIsInternal ?? false,
                                       isEjectable: values.volumeIsEjectable ?? false,
                                       uuid: values.volumeUUIDString,
                                       isReadOnly: isReadOnly))
            } catch {
                Log.volumes.error("error: \(error, privacy: .public)")
            }
        }
        self.volumes = ret
        return ret
    }

    func recordNetworkVolumeSizes() async throws -> ([NetworkVolume], NetworkVolumeRecords) {

        // list mounts available now
        let mounted: [NetworkVolume]
        if let mountListingOverride {
            mounted = try await mountListingOverride()
        } else {
            mounted = try await readNetworkVolumes()
        }
        let nowDate = clock()
        // forget shares that have not produced a sample for a day
        knownNetworkVolumes = knownNetworkVolumes.filter {
            nowDate.timeIntervalSince1970 - $0.value.lastSample <= Self.knownShareExpiry
        }
        for v in mounted {
            let last = knownNetworkVolumes[v.localMount]?.lastSample ?? nowDate.timeIntervalSince1970
            knownNetworkVolumes[v.localMount] = KnownNetworkVolume(volume: v, lastSample: last)
        }
        let networkVolumes = knownNetworkVolumes.values.map(\.volume).sorted()
        let timestamp = nowDate.timeIntervalSince1970

        await withTaskGroup(of: (NetworkVolume, SizeInfo?)?.self) { group in
            for volume in networkVolumes {
                group.addTask {
                    do {
                        if let size = try await self.sizeOf(volume: volume, at: timestamp) {
                            return (volume, size)
                        }
                    } catch {
                        Log.network.error("error querying \(volume.localMount, privacy: .public): \(error, privacy: .public)")
                    }
                    return nil
                }
            }

            for await result in group {
                if let (volume, size) = result {
                    if let size {
                        knownNetworkVolumes[volume.localMount]?.lastSample = timestamp
                        Log.network.debug("got size \(String(describing: size), privacy: .public) for \(volume.localMount, privacy: .public)")
                        if var existingList = networkVolumeSizes[volume.localMount] {
                            existingList.append(size)
                            networkVolumeSizes[volume.localMount] = existingList
                        } else {
                            networkVolumeSizes[volume.localMount] = [size]
                        }
                    }
                }
            }
        }

        if let keeper = NetworkVolumeRecordKeeper(directory: recordDirectory) {
            do { try await keeper.save(known: Array(knownNetworkVolumes.values)) }
            catch { Log.persistence.error("error saving known network volumes: \(error, privacy: .public)") }
        }

        // only keep newer entries 
        let maxOldAge = Date().timeIntervalSince1970 - maxDataAgeMinutes*60 - 60
        
        for (volume, sizes) in networkVolumeSizes {
            var newEnough: [SizeInfo] = []
            for info in sizes {
                if info.timestamp > maxOldAge {
                    newEnough.append(info)
                }
            }
            networkVolumeSizes[volume] = newEnough
        }
        
        return (networkVolumes, networkVolumeSizes)
    }
    
    func recordLocalVolumeSizes() async throws -> LocalVolumeRecords {
        // use the same timestamp for all of them,
        // instead of having them be very slightly different
        let now = clock()
        let timestamp = now.timeIntervalSince1970

        // all volumes are probed in parallel, off this actor; a stalled one
        // times out and simply gets no sample this poll
        let results: [(LocalVolume, SizeInfo?)] = await withTaskGroup(of: (LocalVolume, SizeInfo?).self) { group in
            for volume in volumes {
                group.addTask {
                    do {
                        return (volume, try await self.sizeOf(volume: volume, at: timestamp))
                    } catch {
                        Log.volumes.error("error querying size of \(volume.name, privacy: .public) at \(volume.mountPoint, privacy: .public): \(error, privacy: .public)")
                        return (volume, nil)
                    }
                }
            }
            var out: [(LocalVolume, SizeInfo?)] = []
            for await r in group { out.append(r) }
            return out
        }
        for (volume, size) in results {
            if let size { localVolumeSizes[volume.key, default: []].append(size) }
        }

        // only keep newer entries 
        let maxOldAge = Date().timeIntervalSince1970 - maxDataAgeMinutes*60 - 60
        
        for (volume, sizes) in localVolumeSizes {
            var newEnough: [SizeInfo] = []
            for info in sizes {
                if info.timestamp > maxOldAge {
                    newEnough.append(info)
                }
            }
            localVolumeSizes[volume] = newEnough
        }
        
        return localVolumeSizes
    }


    // size of local volume
    func sizeOf(volume: LocalVolume, at timestamp: TimeInterval) async throws -> SizeInfo? {
        // one outstanding probe per volume: a stalled disk keeps its thread
        // blocked in the kernel, don't pile more on top of it
        let key = volume.key
        guard localInFlight.begin(key) else {
            throw DiskFreeError.probeStillInFlight(path: volume.mountPoint)
        }
        let inFlight = localInFlight
        let seam = localProbe
        let cache = capacityCache
        let timeout = localTimeoutSeconds
        let outcome: LocalProbeOutcome = try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce<LocalProbeOutcome>(continuation)
            DispatchQueue.global().async {
                let outcome = Manager.probe(volume, timestamp: timestamp, seam: seam, cache: cache)
                inFlight.end(key)
                once.resume(.success(outcome))
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                once.resume(.failure(DiskFreeError.probeTimedOut(path: volume.mountPoint)))
            }
        }
        switch outcome {
        case .sample(let size): return size
        case .failed: return nil
        case .wrongVolume:
            Log.volumes.info("\(volume.mountPoint, privacy: .public) is not the expected volume; requesting a re-list")
            relistRequested = true
            return nil
        }
    }

    /// true once if a probe found something other than the expected volume
    func takeRelistRequest() -> Bool {
        defer { relistRequested = false }
        return relistRequested
    }

    /// Runs on a background thread.
    static func probe(_ volume: LocalVolume, timestamp: TimeInterval,
                      seam: LocalProbeSeam, cache: CapacityCache) -> LocalProbeOutcome
    {
        let path = volume.mountPoint
        guard let fs = seam.statfs(path, timestamp) else { return .failed }
        guard mountMatches(mountOn: fs.mountOn, expectedMount: path) else { return .wrongVolume }
        if let expected = volume.uuid, !expected.isEmpty {
            // unknown (nil) is not a mismatch; a different UUID is
            if let actual = seam.uuid(path), actual.caseInsensitiveCompare(expected) != .orderedSame {
                return .wrongVolume
            }
        }
        return .sample(cache.apply(key: volume.key, base: fs.size, now: timestamp) {
            seam.capacity(path)
        })
    }
    
    // true when statfs answered for the share itself. If the share is gone but
    // its mount-point directory remains, statfs describes the containing volume.
    static func mountMatches(mountOn: String, expectedMount: String) -> Bool {
        NetworkVolume.normalizedMountPath(mountOn) == NetworkVolume.normalizedMountPath(expectedMount)
    }

    static func sample(from fs: statfs, expectedMount: String, timestamp: TimeInterval) -> SizeInfo? {
        var fs = fs
        let on = withUnsafePointer(to: &fs.f_mntonname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        guard mountMatches(mountOn: on, expectedMount: expectedMount) else { return nil }
        return SizeInfo(statfs: fs, timestamp: timestamp)
    }

    // size of network volume
    func sizeOf(volume: NetworkVolume, at timestamp: TimeInterval) async throws -> SizeInfo? {
        if let networkSizeOverride {
            return try await networkSizeOverride(volume, timestamp)
        }
        // one outstanding probe per mount: a hung mount keeps its thread
        // blocked in the kernel, don't pile more on top of it
        let path = volume.localMount
        guard inFlightProbes.begin(path) else {
            throw DiskFreeError.probeStillInFlight(path: path)
        }
        let inFlight = inFlightProbes
        let probe = networkProbeOverride
        let timeout = dfTimeoutSeconds
        return try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce<SizeInfo?>(continuation)
            DispatchQueue.global().async {
                let size: SizeInfo?
                if let probe {
                    size = probe(path, timestamp)
                } else {
                    var fs = statfs()
                    size = statfs(path, &fs) == 0
                        ? Manager.sample(from: fs, expectedMount: path, timestamp: timestamp)
                        : nil
                }
                inFlight.end(path)
                once.resume(.success(size))
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                once.resume(.failure(DiskFreeError.probeTimedOut(path: path)))
            }
        }
    }
}

final class InFlightProbes: @unchecked Sendable {
    private let lock = NSLock()
    private var paths: Set<String> = []
    func begin(_ path: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return paths.insert(path).inserted
    }
    func end(_ path: String) {
        lock.lock(); defer { lock.unlock() }
        paths.remove(path)
    }
}

final class ResumeOnce<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    init(_ c: CheckedContinuation<T, any Error>) { continuation = c }
    func resume(_ result: Result<T, any Error>) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(with: result)
    }
}




/// What a local probe found.
enum LocalProbeOutcome: Sendable {
    case sample(SizeInfo)
    case failed
    case wrongVolume // statfs/UUID describe some other volume
}

struct LocalStatfs: Sendable {
    let mountOn: String
    let size: SizeInfo
}

/// The system calls behind a local probe, replaceable in tests.
struct LocalProbeSeam: Sendable {
    /// cheap: statfs of the path
    var statfs: @Sendable (_ path: String, _ timestamp: TimeInterval) -> LocalStatfs?
    /// expensive: (important, opportunistic) available capacity
    var capacity: @Sendable (_ path: String) -> (important: Int, opportunistic: Int)?
    /// the volume UUID string at the path
    var uuid: @Sendable (_ path: String) -> String?

    static let live = LocalProbeSeam(
        statfs: { path, ts in
            liveStatfs(path, timestamp: ts)
        },
        capacity: { path in
            let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey,
                                             .volumeAvailableCapacityForOpportunisticUsageKey]
            guard let v = try? URL(fileURLWithPath: path).resourceValues(forKeys: keys),
                  let i = v.volumeAvailableCapacityForImportantUsage,
                  let o = v.volumeAvailableCapacityForOpportunisticUsage
            else { return nil }
            return (Int(i), Int(o))
        },
        uuid: { path in
            try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString
        })
}

/// Remembers, per volume, when the expensive important/opportunistic figures were
/// last read and how far they were from statfs's number, so polls in between can
/// apply that purgeable offset to the cheap statfs value.
final class CapacityCache: @unchecked Sendable {
    static let refreshInterval: TimeInterval = 60
    private struct Entry { var at: TimeInterval; var importantOffset: Int; var opportunisticExtra: Int }
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]

    func apply(key: String, base: SizeInfo, now: TimeInterval,
               lookup: () -> (important: Int, opportunistic: Int)?) -> SizeInfo
    {
        lock.lock()
        let entry = entries[key]
        lock.unlock()
        var e = entry
        if entry == nil || now - entry!.at >= Self.refreshInterval || now < entry!.at {
            if let c = lookup() {
                e = Entry(at: now,
                          importantOffset: c.important - base.importantCapacity,
                          opportunisticExtra: c.opportunistic - c.important)
                lock.lock(); entries[key] = e; lock.unlock()
            }
        }
        guard let e else { return base }
        let important = min(max(base.importantCapacity + e.importantOffset, 0), base.totalCapacity)
        let opportunistic = min(max(important + e.opportunisticExtra, 0), base.totalCapacity)
        return SizeInfo(importantCapacity: important, opportunisticCapacity: opportunistic,
                        totalCapacity: base.totalCapacity, timestamp: base.timestamp)
    }
}

private func liveStatfs(_ path: String, timestamp: TimeInterval) -> LocalStatfs? {
    var fs = statfs()
    guard statfs(path, &fs) == 0, let size = SizeInfo(statfs: fs, timestamp: timestamp) else { return nil }
    let on = withUnsafePointer(to: &fs.f_mntonname) {
        $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
    }
    return LocalStatfs(mountOn: on, size: size)
}
