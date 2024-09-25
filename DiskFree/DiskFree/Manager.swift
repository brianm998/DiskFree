import Foundation

public actor Manager: Sendable {

    let listVolumesActor = ShellActor("ls", arguments: ["/Volumes"])

    private var volumes: [Volume] = []
    private var dfActors: [Volume:ShellActor] = [:]
    
    func listVolumes() async throws -> [Volume] {
        let output = try await listVolumesActor.execute()
        self.volumes = output.components(separatedBy: "\n").map { Volume(name: $0) }
        return self.volumes
    }

    func recordVolumeSizes() async throws -> [Volume:SizeInfo] {
        var volumeSizeInfo: [Volume:SizeInfo] = [:]
        for volume in volumes {
            if let sizeOfVolume = try await self.sizeOf(volume: volume) {
                print("getting size of \(volume) - \(sizeOfVolume)")
                volumeSizeInfo[volume] = sizeOfVolume
            }
        }
        return volumeSizeInfo
    }
    
    func sizeOf(volume: Volume) async throws -> SizeInfo? {
        if dfActors[volume] == nil {
            dfActors[volume] = ShellActor("df", arguments: ["-k", "'/Volumes/\(volume.name)'"])
        }
        guard let duActor = dfActors[volume]
        else { throw "no df actor found for volume \(volume.name)" }

        let output = try await duActor.execute()

        return SizeInfo(dfOutput: output) 
    }
}


extension String: @retroactive Error { }
