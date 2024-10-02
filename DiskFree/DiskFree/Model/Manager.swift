import Foundation


/*

 todo:

 - limit number of size records kept
 - allow chaging query rate in gui somewhere
 - support for SANs (make sure to not keep them always alive)
 - better handle multiple volumes on one physical unit
   - have a double click pull down list that allows choosing what parts based upon crap
 - write release scripts
 - implement version number somewhere
 - allow removing items from chart?
 - add loading animation at start
 - missing visual error messages to user
 - show on chart where low space threshold is
   - allow changing it by dragging it
 - allow hover over tool tips for free space entries
 - display volume tragectory (up/down/static)    
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
    private var maxDataAgeSeconds: TimeInterval = 60*60
    
    // keep track of volume sizes

    let diskUtilActor = ShellActor("diskutil", arguments: ["info", "-all"])

    func set(maxDataAgeSeconds: TimeInterval) {
        self.maxDataAgeSeconds = maxDataAgeSeconds
    }
    
    func listVolumes() async throws -> [Volume] {
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
                    ret.append(Volume(name: volumeName, mountPoint: mountPoint))
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
            if let sizeOfVolume = try await self.sizeOf(volume: volume, at: timestamp) {
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
        let maxOldAge = Date().timeIntervalSince1970 - maxDataAgeSeconds
        
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

    func sizeOf(volume: Volume, at timestamp: TimeInterval) async throws -> SizeInfo? {
        if dfActors[volume] == nil {
            dfActors[volume] = ShellActor("df", arguments: ["-k", "'\(volume.mountPoint)'"])
        }
        guard let duActor = dfActors[volume]
        else { throw "no df actor found for volume \(volume.name)" }

        let output = try await duActor.execute()

        return SizeInfo(dfOutput: output, timestamp: timestamp) 
    }
}


extension String: @retroactive Error { }
