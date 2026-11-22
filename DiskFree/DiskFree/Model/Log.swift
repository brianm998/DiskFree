import Foundation
import os

/// App-wide loggers. Mount paths and volume names are logged `privacy: .public`
/// so the owner can read them in Console.
enum Log {
    static let subsystem = "com.DiskFree"
    static let volumes = Logger(subsystem: subsystem, category: "volumes")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let speech = Logger(subsystem: subsystem, category: "speech")
}

enum DiskFreeError: Error, CustomStringConvertible, Equatable {
    case probeTimedOut(path: String)
    case probeStillInFlight(path: String)
    case unreadableVolumeSize(path: String)

    var description: String {
        switch self {
        case .probeTimedOut(let path): "timed out reading \(path)"
        case .probeStillInFlight(let path): "previous probe of \(path) still blocked"
        case .unreadableVolumeSize(let path): "couldn't read size data for volume \(path)"
        }
    }
}
