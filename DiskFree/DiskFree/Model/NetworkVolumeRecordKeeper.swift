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
}
