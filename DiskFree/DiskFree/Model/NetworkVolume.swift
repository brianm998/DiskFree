import Foundation

public struct NetworkVolume: Sendable,
                             Codable,
                             Identifiable,
                             Hashable,
                             Comparable
{
    public let username: String
    public let remoteHost: String
    public let remotePath: String
    public let localMount: String
    public let type: String
    public let id: UUID

    public var name: String { localMount }

    public init(username: String,
                remoteHost: String,
                remotePath: String,
                localMount: String,
                type: String)
    {
        self.id = UUID()
        self.username = username
        self.remoteHost = remoteHost
        self.remotePath = remotePath
        self.localMount = localMount
        self.type = type
    }

    // from statfs: f_mntfromname looks like //admin@beast.local/root,
    // f_mntonname like /System/Volumes/Data/mnt/root, f_fstypename like afpfs
    public init?(mountedFrom: String, onPath: String, fsType: String) {
        guard let match = mountedFrom.firstMatch(of: /^\/\/(?:([^@\s]+)@)?([^\/\s]+)(\/\S*)?$/)
        else { return nil }
        self.username = match.1.map(String.init) ?? ""
        self.remoteHost = String(match.2)
        self.remotePath = match.3.map(String.init) ?? ""
        self.id = UUID()
        let undesiredStartString = "/System/Volumes/Data"
        if onPath.starts(with: undesiredStartString + "/") {
            self.localMount = String(onPath.dropFirst(undesiredStartString.count))
        } else {
            self.localMount = onPath
        }
        self.type = fsType
    }

    public init?(statfs fs: statfs) {
        var fs = fs
        let from = withUnsafePointer(to: &fs.f_mntfromname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        let on = withUnsafePointer(to: &fs.f_mntonname) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
        }
        let type = withUnsafePointer(to: &fs.f_fstypename) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MFSTYPENAMELEN)) { String(cString: $0) }
        }
        self.init(mountedFrom: from, onPath: on, fsType: type)
    }

    // all currently mounted network filesystems; MNT_NOWAIT so a hung
    // mount cannot block the listing
    public static func mounted() -> [NetworkVolume] {
        let count = getfsstat(nil, 0, MNT_NOWAIT)
        guard count > 0 else { return [] }
        var buffer = Array(repeating: statfs(), count: Int(count))
        let size = Int32(MemoryLayout<statfs>.stride * buffer.count)
        let n = getfsstat(&buffer, size, MNT_NOWAIT)
        guard n > 0 else { return [] }
        return buffer.prefix(Int(n)).compactMap { NetworkVolume(statfs: $0) }
    }

  public static func == (lhs: NetworkVolume, rhs: NetworkVolume) -> Bool {
        lhs.username == rhs.username &&
        lhs.remoteHost == rhs.remoteHost &&
        lhs.remotePath == rhs.remotePath &&
        lhs.localMount == rhs.localMount &&
        lhs.type == rhs.type
    }

  public static func < (lhs: NetworkVolume, rhs: NetworkVolume) -> Bool {
      lhs.localMount < rhs.localMount
  }
  
  public func hash(into hasher: inout Hasher) {
        hasher.combine(username)
        hasher.combine(remoteHost)
        hasher.combine(remotePath)
        hasher.combine(localMount)
        hasher.combine(type)
    }
}

