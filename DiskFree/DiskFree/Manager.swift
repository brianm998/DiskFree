import Foundation


/*

 todo:

 - limit number of size records kept
 - limit number of size records shown in gui
 - write files into app bundle
   - a json file of volume sizes every time we check
   - a preferences file to keep track of:
     - what volumes to show
     - how to show them
     - other stuff
 - allow chaging query rate in gui somewhere
 - support for SANs (make sure to not keep them always alive)
 - better handle multiple volumes on one physical unit
   - have a double click pull down list that allows choosing what parts based upon crap
 - keep json config file of changes user has made
 - write release scripts
 - implement version number somewhere
 - allow removing items from chart?
 - overallping annotations :(
 
 */
public actor Manager: Sendable {

    private var volumes: [Volume] = []
    private var dfActors: [Volume:ShellActor] = [:]

    private var volumeSizes: [String:[SizeInfo]] = [:]
    
    // keep track of volume sizes

    let diskUtilActor = ShellActor("diskutil", arguments: ["info", "-all"])

    func listVolumes() async throws -> [Volume] {
        let output = try await diskUtilActor.execute()
        print(output)
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

    func recordVolumeSizes() async throws -> [String:[SizeInfo]] {
        print("record volume sizes volumes.count \(volumes.count)")
        // use the same timestamp for all of them,
        // instead of having them be very slightly different
        let timestamp = Date().timeIntervalSince1970
        for volume in volumes {
            print("record size of \(volume.name)")
            if let sizeOfVolume = try await self.sizeOf(volume: volume, at: timestamp) {
                if var existingList = volumeSizes[volume.name] {
                    print("appending to volume list volumeSizes[\(volume.name)].count = \(volumeSizes[volume.name]?.count ?? -1)")

                    existingList.append(sizeOfVolume)  
                    volumeSizes[volume.name] = existingList
                    print("appending to volume list volumeSizes[\(volume.name)].count = \(volumeSizes[volume.name]?.count ?? -1)")
                } else {
                    print("NOT appending to volume list volumeSizes[\(volume.name)]")
                    volumeSizes[volume.name] = [sizeOfVolume]
                }
            }
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
