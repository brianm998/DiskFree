import Foundation


public struct VolumeInfo: Sendable {

    let isRootFileSystem: Bool
    let isInternal: Bool
    let isEjectable: Bool
    let isBrowsable: Bool
    
    init(for path: String) throws {
        let fileURL = URL(fileURLWithPath: path)

        let keys: Set<URLResourceKey> =
          [
            .volumeIsRootFileSystemKey, //idenfies which volume is '/'
            .volumeIsInternalKey,       // seems to work as described
            .volumeIsEjectableKey, 
            .volumeIsBrowsableKey,      // used to filter out volumes user shouldn't see
          ]

        let values = try fileURL.resourceValues(forKeys: keys)

        if let volumeIsRootFileSystem = values.volumeIsRootFileSystem,
           let volumeIsInternal = values.volumeIsInternal,
           let volumeIsEjectable = values.volumeIsEjectable,
           let volumeIsBrowsable = values.volumeIsBrowsable
        {
            self.isRootFileSystem = volumeIsRootFileSystem
            self.isInternal = volumeIsInternal
            self.isEjectable = volumeIsEjectable
            self.isBrowsable = volumeIsBrowsable
        } else {
            throw "couldn't read data for volume \(path)" 
        }
    }
}


