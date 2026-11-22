import Foundation

struct LocalVolume: Identifiable, Hashable {
  
    let name: String
    let mountPoint: String
    let userVisibleMountPoint: String
    let size: SizeInfo?
    let id = UUID()
    let isInternal: Bool
    let isEjectable: Bool
    /// the file system's volume UUID, when it has one
    let uuid: String?

    /// Stable identity: the UUID string when available, otherwise the real
    /// mount point.  Survives renames; distinguishes same-named drives.
    var key: String {
        if let uuid, !uuid.isEmpty { return uuid }
        return mountPoint
    }

    public init(name: String,
                mountPoint: String,
                userVisibleMountPoint: String,
                isInternal: Bool,
                isEjectable: Bool,
                uuid: String? = nil,
                size: SizeInfo? = nil)
    {
        self.name = name
        self.mountPoint = mountPoint
        self.userVisibleMountPoint = userVisibleMountPoint
        self.size = size
        self.isEjectable = isEjectable
        self.isInternal = isInternal
        self.uuid = uuid
    }
    
    /// true for strings that are keys rather than volume names: a UUID or an absolute path
    static func looksLikeKey(_ s: String) -> Bool {
        s.hasPrefix("/") || UUID(uuidString: s) != nil
    }

    static func == (lhs: LocalVolume, rhs: LocalVolume) -> Bool {
        lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.key)
    }
}

