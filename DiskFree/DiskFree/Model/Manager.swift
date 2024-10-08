import Foundation

/*

 todo:

 - write release scripts
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

    private var dfActors: [NetworkVolume:ShellActor] = [:] // used for network volumes 
    
    private var localVolumeSizes: LocalVolumeRecords = [:] // keyed by volume.name
    private var networkVolumeSizes: NetworkVolumeRecords = [:] // keyed by volume.localMount

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

    let diskUtilActor = ShellActor("diskutil", arguments: ["info", "-all"])

    func set(maxDataAgeMinutes: TimeInterval) {
        self.maxDataAgeMinutes = maxDataAgeMinutes
    }

    func readNetworkVolumes() async throws -> [NetworkVolume] {

        /*
//floof@mammoth/mammoth on /System/Volumes/Data/mammoth (smbfs, nodev, nosuid, automounted, noowners, nobrowse, mounted by brian)
//admin@goliath.local/branch on /System/Volumes/Data/mnt/branch (afpfs, nodev, nosuid, automounted, nobrowse, mounted by brian)
//admin@goliath.local/trunk on /System/Volumes/Data/mnt/trunk (afpfs, nodev, nosuid, automounted, nobrowse, mounted by brian)
//admin@colossus.local/tree on /System/Volumes/Data/mnt/tree (afpfs, nodev, nosuid, automounted, nobrowse, mounted by brian)
//admin@beast.local/root on /System/Volumes/Data/mnt/root (afpfs, nodev, nosuid, automounted, nobrowse, mounted by brian)
         */
        let syntheticConfigActor = ShellActor("mount", arguments: [])

        let output = try await syntheticConfigActor.execute()

        let outputLines = output.components(separatedBy: "\n")

//        print("mount: \(output)")

        var ret: [NetworkVolume] = []
        
        for line in outputLines {
            if let networkVolume = NetworkVolume(from: line) {
                ret.append(networkVolume)
//                print("found \(networkVolume)")
                /*

                 next steps:

                 - package the above values into a Sendable struct
                 - add a parallel remote/local path for it
                   * add new json file
                   * use new polling interval
                   - add separate ui, similar, but different
                   - add remote / local global config options
                   - 
                 */
            }            
        }
        return ret
    }

    func readRootSymlinks() async throws -> [String: String] { // /Volumes/op -> /op
        /*

lrwxr-xr-x@   1 root  wheel    11 Sep  5 13:54 etc -> private/etc
lrwxr-xr-x    1 root  wheel    25 Sep 26 15:55 home -> /System/Volumes/Data/home
lrwxr-xr-x    1 root  wheel    28 Sep 29 10:58 mammoth -> /System/Volumes/Data/mammoth
lrwxr-xr-x    1 root  wheel    24 Sep 26 15:55 mnt -> /System/Volumes/Data/mnt
lrwxr-xr-x    1 root  wheel    10 Sep 26 15:55 op -> Volumes/op
drwxr-xr-x    5 root  wheel   160 Jun 25 07:05 opt
lrwxr-xr-x    1 root  wheel    10 Sep 26 15:55 pp -> Volumes/pp
drwxr-xr-x    6 root  wheel   192 Sep 26 15:55 private
lrwxr-xr-x    1 root  wheel    10 Sep 26 15:55 qp -> Volumes/qp
lrwxr-xr-x    1 root  wheel    10 Sep 26 15:55 rp -> Volumes/rp
drwxr-xr-x@  77 root  wheel  2464 Sep  5 13:54 sbin
lrwxr-xr-x    1 root  wheel    10 Sep 26 15:55 sp -> Volumes/sp
lrwxr-xr-x    1 root  wheel     3 Sep 26 15:55 sw -> usr
lrwxr-xr-x@   1 root  wheel    11 Sep  5 13:54 tmp -> private/tmp
drwxr-xr-x@  11 root  wheel   352 Sep  5 13:54 usr
lrwxr-xr-x@   1 root  wheel    11 Sep  5 13:54 var -> private/var
         
         */

        var ret: [String: String] = [:]

        // first read /etc/synthetic.conf
        // XXX cannot read synthetic.conf, but can read ls -l / :)
        let syntheticConfigActor = ShellActor("ls", arguments: ["-l", "/"])

        let output = try await syntheticConfigActor.execute()
        let outputLines = output.components(separatedBy: "\n")

//        print("syntheticConfigOutput \(output)")
        
        for line in outputLines {
            if let match = line.firstMatch(of: /([\/\w]+)\s+->\s+([\/\w]+)$/) {
                var rootPath = String(match.1)
                var realPath = String(match.2)
                if !realPath.starts(with: "/") { realPath = "/\(realPath)" }
                if !rootPath.starts(with: "/") { rootPath = "/\(rootPath)" }
                ret[realPath] = rootPath
            }
        }
        
        return ret
    }
    
    func listLocalVolumes() async throws -> [LocalVolume] {

        let rootSymlinks = try await readRootSymlinks()
        
        let output = try await diskUtilActor.execute()
//        print(output)  // printing out the full diskutil output is EXTREMELY verbose
        let outputLines = output.components(separatedBy: "\n")

        var ret: [LocalVolume]  = []
        
        var mountPoint: String?
        var volumeName: String?
        var readOnly: String?

        for line in outputLines {
            if line.starts(with: "*******") {

                if let mountPoint,
                   let readOnly,
                   readOnly == "No",
                   let volumeName
                {
                    do {
                        let volumeInfo = try VolumeInfo(for: mountPoint)
                        // the user visible mount point is still a valid path,
                        // but may be a symlink or such, so we can't query at that
                        // path for volume size, have to use the real mountPoint for that
                        var userVisibleMountPoint = mountPoint
                        
                        if volumeInfo.isBrowsable {
                            if volumeInfo.isRootFileSystem {
                                userVisibleMountPoint = "/"
                            } else if let rootSymlink = rootSymlinks[userVisibleMountPoint] {
                                userVisibleMountPoint = rootSymlink
                            }
                            ret.append(LocalVolume(name: volumeName,
                                                   mountPoint: mountPoint,
                                                   userVisibleMountPoint: userVisibleMountPoint,
                                                   isInternal: volumeInfo.isInternal,
                                                   isEjectable: volumeInfo.isEjectable))
                        }
                    } catch {
                        print("error \(error)")
                    }
                }
                mountPoint = nil
                readOnly = nil
            } else if let match = line.firstMatch(of: /^\s+([^:]+):\s+(.*)$/) {
                let name = match.1
                let value = match.2

                /*
                 if something is part of whole, then we need to gather all things that are
                 also part of that whole.
                 */
                
                // Part of Whole
                // Whole / Yes/No
                if let _ = name.firstMatch(of: /Mount Point/) {
                    mountPoint = String(value)
                } else if let _ = name.firstMatch(of: /Media Read-Only/) {
                    readOnly = String(value)
                } else if let _ = name.firstMatch(of: /Volume Name/) {
                    volumeName = String(value)
                }
            }
        }
        self.volumes = ret
        return ret
    }

    func recordNetworkVolumeSizes() async throws -> ([NetworkVolume], NetworkVolumeRecords) {
        
        // list mounts available now
        let networkVolumes = try await readNetworkVolumes()
        let timestamp = Date().timeIntervalSince1970

        for volume in networkVolumes {
            // run a df actor on them
            print("FUCKING df'ing \(volume)")
            if let size = try await sizeOf(volume: volume, at: timestamp) {
                // add to list of network volume sizes

                print("FUCKING got size \(size) for \(volume)")

                if var existingList = networkVolumeSizes[volume.localMount] {
                    existingList.append(size)
                    networkVolumeSizes[volume.localMount] = existingList
                } else {
                    networkVolumeSizes[volume.localMount] = [size]
                }
            } else {
                print("FUCKING DIDN'T GET SIZE for \(volume)")
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
            //print("record size of \(volume.name)")
            if let sizeOfVolume = try self.sizeOf(volume: volume, at: timestamp) {
                if var existingList = localVolumeSizes[volume.name] {
                    //print("appending to volume list localVolumeSizes[\(volume.name)].count = \(localVolumeSizes[volume.name]?.count ?? -1)")

                    existingList.append(sizeOfVolume)  
                    localVolumeSizes[volume.name] = existingList
                    //print("appending to volume list localVolumeSizes[\(volume.name)].count = \(localVolumeSizes[volume.name]?.count ?? -1)")
                } else {
                    //print("NOT appending to volume list localVolumeSizes[\(volume.name)]")
                    localVolumeSizes[volume.name] = [sizeOfVolume]
                }
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
        if dfActors[volume] == nil {
            dfActors[volume] = ShellActor("df", arguments: ["-k", "'\(volume.localMount)'"])
        }
        guard let duActor = dfActors[volume]
        else { throw "no df actor found for volume \(volume.localMount)" }
        
        let output = try await duActor.execute()

        let outputLines = output.components(separatedBy: "\n") 
        for line in outputLines {
            if let ret = SizeInfo(dfOutput: output, timestamp: timestamp) {
                return ret
            }
        }

        return nil
    }
}


extension String: @retroactive Error { }
