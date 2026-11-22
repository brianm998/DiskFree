import Foundation

/*

 An actor that keeps a record of volume sizes on file.

 */
public actor NetworkVolumeRecordKeeper {

    let recordFilename: String
    
    /// number of completed writes (for tests)
    private(set) var saveCount = 0

    /// `directory` defaults to the user's Documents folder.
    init?(directory: URL? = nil) {
        guard let dir = directory ?? FileManager.default.urls(for: .documentDirectory,
                                                              in: .userDomainMask).last
        else { return nil }
        self.recordFilename = dir.appendingPathComponent("NetworkVolumeRecords.json").path
    }

    func loadRecords() async throws -> NetworkVolumeRecords {
        if FileManager.default.fileExists(atPath: recordFilename) {
            let data = try Data(contentsOf: URL(fileURLWithPath: recordFilename))
            let decoder = JSONDecoder()
            return try decoder.decode(NetworkVolumeRecords.self, from: data)
        } else {
            // no file found at path, return empty dict
            return [:]
        }
    }

    func save(records: NetworkVolumeRecords) async throws {
        let jsonData = try JSONEncoder().encode(records)
        try jsonData.write(to: URL(fileURLWithPath: recordFilename), options: [.atomic])
        saveCount += 1
    }

    // known shares, persisted so idle automounted shares are probed after a relaunch
    var knownFilename: String {
        URL(fileURLWithPath: recordFilename).deletingLastPathComponent()
            .appendingPathComponent("NetworkVolumesKnown.json").path
    }

    func loadKnown() async throws -> [KnownNetworkVolume] {
        guard FileManager.default.fileExists(atPath: knownFilename) else { return [] }
        let data = try Data(contentsOf: URL(fileURLWithPath: knownFilename))
        return try JSONDecoder().decode([KnownNetworkVolume].self, from: data)
    }

    func save(known: [KnownNetworkVolume]) async throws {
        let data = try JSONEncoder().encode(known)
        try data.write(to: URL(fileURLWithPath: knownFilename), options: [.atomic])
    }
}

/// A share remembered across runs, with when it last produced a sample
struct KnownNetworkVolume: Codable, Sendable, Equatable {
    var volume: NetworkVolume
    var lastSample: TimeInterval
}
