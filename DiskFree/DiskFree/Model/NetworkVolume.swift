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

    static let networkTypes: Set<String> = ["smbfs", "afpfs", "nfs", "webdav", "cifs"]
    static let excludedTypes: Set<String> = ["autofs", "devfs"]
    static let dataVolumePrefix = "/System/Volumes/Data"

    /// mount path as users see it: without the Data volume firmlink prefix
    static func normalizedMountPath(_ onPath: String) -> String {
        if onPath.starts(with: dataVolumePrefix + "/") {
            return String(onPath.dropFirst(dataVolumePrefix.count))
        }
        return onPath
    }

    // Pure selection and parsing over what statfs reports:
    // f_mntfromname, f_mntonname, f_fstypename and f_flags.
    // Examples: //admin@beast.local/root (afpfs), mammoth.local:/volume1/mammoth (nfs),
    // https://host/path (webdav). Local mounts, autofs and devfs are not network volumes.
    public init?(mountedFrom: String, onPath: String, fsType: String, flags: UInt32 = 0) {
        guard !mountedFrom.isEmpty, !onPath.isEmpty,
              flags & UInt32(MNT_LOCAL) == 0,
              !Self.excludedTypes.contains(fsType),
              !mountedFrom.starts(with: "/dev/")
        else { return nil }
        let user: String
        let host: String
        let path: String
        switch fsType {
        case "smbfs", "afpfs", "cifs":
            guard let m = mountedFrom.firstMatch(of: /^\/\/(?:([^@\s]+)@)?([^\/\s]+)(\/\S*)?$/)
            else { return nil }
            user = m.1.map(String.init) ?? ""
            host = String(m.2)
            path = m.3.map(String.init) ?? ""
        case "nfs":
            guard let m = mountedFrom.firstMatch(of: /^([^:\s]+):(\/\S*)$/)
            else { return nil }
            user = ""
            host = String(m.1)
            path = String(m.2)
        case "webdav":
            guard let url = URL(string: mountedFrom), let h = url.host(percentEncoded: false), !h.isEmpty
            else { return nil }
            user = url.user(percentEncoded: false) ?? ""
            host = h
            path = url.path(percentEncoded: false)
        default:
            // unknown non-local type: keep it, raw source as the host
            user = ""
            host = mountedFrom
            path = ""
        }
        self.username = user
        self.remoteHost = host
        self.remotePath = path
        self.id = UUID()
        self.localMount = Self.normalizedMountPath(onPath)
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
        self.init(mountedFrom: from, onPath: on, fsType: type, flags: fs.f_flags)
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

