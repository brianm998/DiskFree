import Foundation


/*

 todo:

 - limit number of size records kept in gui
 - sort by free space
 - add select/clear all buttons on right
 - SANs?

 
 */
public actor Manager: Sendable {

    private var volumes: [Volume] = []
    private var dfActors: [Volume:ShellActor] = [:]

    private var volumeSizes: [String:[SizeInfo]] = [:]
    
    // keep track of volume sizes

    let diskUtilActor = ShellActor("diskutil", arguments: ["info", "-all"])

    func listVolumes() async throws -> [Volume] {
        let output = try await diskUtilActor.execute()
        let outputLines = output.components(separatedBy: "\n")

        var ret: [Volume]  = []
        
        var mountPoint: String?
        var readOnly: String?

        for line in outputLines {
            if line.starts(with: "*******") {

                if let mountPoint,
                   let readOnly,
                   readOnly == "No"
                {
                    ret.append(Volume(name: mountPoint))
                }
                mountPoint = nil
                readOnly = nil
            } else if let match = line.firstMatch(of: /^\s+([^:]+):\s+(.*)$/) {
                let name = match.1
                let value = match.2

                if let _ = name.firstMatch(of: /Mount Point/) {
                    mountPoint = String(value)
                } else if let _ = name.firstMatch(of: /Media Read-Only/) {
                    readOnly = String(value)
                }
            }
        }
        self.volumes = ret
        return ret
    }

    func recordVolumeSizes() async throws -> [String:[SizeInfo]] {
        print("record volume sizes volumes.count \(volumes.count)")
        for volume in volumes {
            print("record size of \(volume.name)")
            if let sizeOfVolume = try await self.sizeOf(volume: volume) {
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

    func sizeOf(volume: Volume) async throws -> SizeInfo? {
        if dfActors[volume] == nil {
            dfActors[volume] = ShellActor("df", arguments: ["-k", "'\(volume.name)'"])
        }
        guard let duActor = dfActors[volume]
        else { throw "no df actor found for volume \(volume.name)" }

        let output = try await duActor.execute()

        return SizeInfo(dfOutput: output) 
    }
}


extension String: @retroactive Error { }
