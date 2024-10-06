import Foundation

/*

 todo:

 - support for SANs (make sure to not keep them always alive)
   - use DFSizeInfo, figure out how to list them, and see if they are alive wihtout waking them
   - only poll for size when they're alive, poll for alive or not otherwise
 - better handle multiple volumes on one physical unit (should be fixed with user visible flag)
   - have a double click pull down list that allows choosing what parts based upon crap
 - write release scripts
 - implement version number somewhere
 - allow removing items from chart?
 - add loading animation at start
 - missing visual error messages to user
 - show on chart where low space threshold is
   - allow changing it by dragging it
 - create app icon
 - add github link in app

 - look into this:
   diskutil info -plist /
 - and also this:
 https://developer.apple.com/documentation/foundation/urlresourcekey/checking_volume_storage_capacity

 - support synthetic.conf for mapping to root symlinks (show /sp, not /Volumes/sp)
 - show '/' instead of 'Macintosh HD - Data' for the root partition
 - allow toggle between showing important and Opportunistic Usage
 - find how to identify backup volumes
 */
public actor Manager: Sendable {

    private var volumes: [Volume] = []
    private var dfActors: [Volume:ShellActor] = [:]

    
    private var volumeSizes: VolumeRecords = [:] // keyed by volume.name

    public func loadStoredVolumeRecords() async {
        do {
            if let recordKeeper = VolumeRecordKeeper() {
                let initialSizes = try await recordKeeper.loadRecords()

                volumeSizes = initialSizes
                print("loaded stored records \(initialSizes.count)")
            } 
        } catch {
            print("error loading stored records: \(error)")
        }
    }
    
    // data older than this is discarded
    private var maxDataAgeMinutes: TimeInterval = 60
    
    // keep track of volume sizes

    let diskUtilActor = ShellActor("diskutil", arguments: ["info", "-all"])

    func set(maxDataAgeMinutes: TimeInterval) {
        self.maxDataAgeMinutes = maxDataAgeMinutes
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

        print("syntheticConfigOutput \(output)")
        
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
    
    func listVolumes() async throws -> [Volume] {

        let rootSymlinks = try await readRootSymlinks()
        
        let output = try await diskUtilActor.execute()
//        print(output)  // printing out the full diskutil output is EXTREMELY verbose
        let outputLines = output.components(separatedBy: "\n")

        var ret: [Volume]  = []
        
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
                            ret.append(Volume(name: volumeName,
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

    func recordVolumeSizes() async throws -> VolumeRecords {
        //print("record volume sizes volumes.count \(volumes.count)")
        // use the same timestamp for all of them,
        // instead of having them be very slightly different
        let timestamp = Date().timeIntervalSince1970
        for volume in volumes {
            //print("record size of \(volume.name)")
            if let sizeOfVolume = try self.sizeOf(volume: volume, at: timestamp) {
                if var existingList = volumeSizes[volume.name] {
                    //print("appending to volume list volumeSizes[\(volume.name)].count = \(volumeSizes[volume.name]?.count ?? -1)")

                    existingList.append(sizeOfVolume)  
                    volumeSizes[volume.name] = existingList
                    //print("appending to volume list volumeSizes[\(volume.name)].count = \(volumeSizes[volume.name]?.count ?? -1)")
                } else {
                    //print("NOT appending to volume list volumeSizes[\(volume.name)]")
                    volumeSizes[volume.name] = [sizeOfVolume]
                }
            }
        }

        // only keep newer entries 
        let maxOldAge = Date().timeIntervalSince1970 - maxDataAgeMinutes*60 - 60
        
        for (volume, sizes) in volumeSizes {
            var newEnough: [SizeInfo] = []
            for info in sizes {
                if info.timestamp > maxOldAge {
                    newEnough.append(info)
                }
            }
            volumeSizes[volume] = newEnough
        }
        
        return volumeSizes
    }


    func sizeOf(volume: Volume, at timestamp: TimeInterval) throws -> SizeInfo? {
        try SizeInfo(for: volume.mountPoint, timestamp: timestamp)
    }
    
    func dfSizeOf(volume: Volume, at timestamp: TimeInterval) async throws -> DFSizeInfo? {
        if dfActors[volume] == nil {
            dfActors[volume] = ShellActor("df", arguments: ["-k", "'\(volume.mountPoint)'"])
        }
        guard let duActor = dfActors[volume]
        else { throw "no df actor found for volume \(volume.name)" }

        let output = try await duActor.execute()

        return DFSizeInfo(dfOutput: output, timestamp: timestamp)
    }
}


extension String: @retroactive Error { }
