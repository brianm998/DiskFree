import Foundation

/*

 todo:

 - implement version number somewhere
 - allow removing items from chart?
 - add loading animation at start
 - missing visual error messages to user
 - show on chart where low space threshold is
   - allow changing it by dragging it
 - create app icon
 - add github link in app
 - support multiple windows better, i.e. separate preferences for each

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
    
    private var localVolumeSizes: LocalVolumeRecords = [:] // keyed by volume.name
    private var networkVolumeSizes: NetworkVolumeRecords = [:] // keyed by volume.localMount

    // every network volume seen this run, keyed by localMount. Automounted
    // shares vanish from `mount` when idle but still work (and remount on access)
    private var knownNetworkVolumes: [String: NetworkVolume] = [:]

    var dfTimeoutSeconds: TimeInterval = 10

    // test seam: replaces the output of `mount`
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

    public func loadStoredLocalVolumeRecords() async {
        do {
            if let recordKeeper = LocalVolumeRecordKeeper() {
                let initialSizes = try await recordKeeper.loadRecords()

                localVolumeSizes = initialSizes
                print("loaded stored records \(initialSizes.count)")
            } 
        } catch {
            print("error loading stored records: \(error)")
        }
    }
    
    public func loadStoredNetworkVolumeRecords() async -> NetworkVolumeRecords? {
        do {
            if let recordKeeper = NetworkVolumeRecordKeeper() {
                let initialSizes = try await recordKeeper.loadRecords()

                networkVolumeSizes = initialSizes
                print("loaded stored records \(initialSizes.count)")

                return initialSizes
            } 
        } catch {
            print("error loading stored records: \(error)")
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

    func listLocalVolumes() async throws -> [LocalVolume] {

        let rootSymlinks = try await readRootSymlinks()

        let keys: [URLResourceKey] = [
            .volumeNameKey,             // non-localized; keys the persisted records
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
                guard values.volumeIsLocal == true,
                      values.volumeIsBrowsable == true,
                      let isRoot = values.volumeIsRootFileSystem,
                      let volumeName = values.volumeName
                else { continue }
                // the sealed system volume is read only but must be listed
                if values.volumeIsReadOnly == true && !isRoot { continue }

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
                                       isEjectable: values.volumeIsEjectable ?? false))
            } catch {
                print("error \(error)")
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
        for v in mounted { knownNetworkVolumes[v.localMount] = v }
        let networkVolumes = knownNetworkVolumes.values.sorted()
        let timestamp = Date().timeIntervalSince1970

        await withTaskGroup(of: (NetworkVolume, SizeInfo?)?.self) { group in
            for volume in networkVolumes {
                group.addTask {
                    do {
                        if let size = try await self.sizeOf(volume: volume, at: timestamp) {
                            return (volume, size)
                        }
                    } catch {
                        print("Error querying \(volume.localMount): \(error)")
                    }
                    return nil
                }
            }

            for await result in group {
                if let (volume, size) = result {
                    if let size {
                        print("got size \(size) for \(volume)")
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
        //print("record volume sizes volumes.count \(volumes.count)")
        // use the same timestamp for all of them,
        // instead of having them be very slightly different
        let timestamp = Date().timeIntervalSince1970
        for volume in volumes {
            // one failing volume must not stop the others from being sampled
            do {
                if let sizeOfVolume = try self.sizeOf(volume: volume, at: timestamp) {
                    localVolumeSizes[volume.name, default: []].append(sizeOfVolume)
                }
            } catch {
                print("error querying size of \(volume.name) at \(volume.mountPoint): \(error)")
            }
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
    func sizeOf(volume: LocalVolume, at timestamp: TimeInterval) throws -> SizeInfo? {
        try SizeInfo(for: volume.mountPoint, timestamp: timestamp)
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
            throw "previous probe of \(path) still blocked"
        }
        let inFlight = inFlightProbes
        let probe = networkProbeOverride
        let timeout = dfTimeoutSeconds
        return try await withCheckedThrowingContinuation { continuation in
            let once = ResumeOnce(continuation)
            DispatchQueue.global().async {
                let size: SizeInfo?
                if let probe {
                    size = probe(path, timestamp)
                } else {
                    var fs = statfs()
                    size = statfs(path, &fs) == 0 ? SizeInfo(statfs: fs, timestamp: timestamp) : nil
                }
                inFlight.end(path)
                once.resume(.success(size))
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                once.resume(.failure("timed out reading \(path)"))
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

final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<SizeInfo?, any Error>?
    init(_ c: CheckedContinuation<SizeInfo?, any Error>) { continuation = c }
    func resume(_ result: Result<SizeInfo?, any Error>) {
        lock.lock()
        let c = continuation
        continuation = nil
        lock.unlock()
        c?.resume(with: result)
    }
}


extension String: @retroactive Error { }
