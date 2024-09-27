import Foundation

/*

 An actor that keeps a record of volume sizes on file.

 */
public actor VolumeRecordKeeper {

    let recordFilename: String
    
    init?() {
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                             in: .userDomainMask).last
        {
            let fileURL = documentsDirectory.appendingPathComponent("VolumeRecords.json")
            self.recordFilename = fileURL.path
            print("starting with recordFilename \(recordFilename)")
        } else {
            return nil 
        }
    }
    
    func loadRecords() async throws -> VolumeRecords {
        if FileManager.default.fileExists(atPath: recordFilename) {
            let url = NSURL(fileURLWithPath: recordFilename, isDirectory: false) as URL
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
            let decoder = JSONDecoder()
            return try decoder.decode(VolumeRecords.self, from: data)
        } else {
            // no file found at path, return empty dict
            return [:]
        }
    }

    func save(records: VolumeRecords) async throws {
        if FileManager.default.fileExists(atPath: recordFilename) {
            // blow away any existing file
            try FileManager.default.removeItem(atPath: recordFilename)
        }

        // write out new file
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(records)
        FileManager.default.createFile(atPath: recordFilename,
                                       contents: jsonData,
                                       attributes: nil)
    }
}


