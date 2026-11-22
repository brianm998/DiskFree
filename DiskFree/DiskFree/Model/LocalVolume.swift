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
    /// mounted read-only (NTFS without a driver, write-locked card, sealed system volume)
    let isReadOnly: Bool

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
                isReadOnly: Bool = false,
                size: SizeInfo? = nil)
    {
        self.name = name
        self.mountPoint = mountPoint
        self.userVisibleMountPoint = userVisibleMountPoint
        self.size = size
        self.isEjectable = isEjectable
        self.isInternal = isInternal
        self.uuid = uuid
        self.isReadOnly = isReadOnly
    }
    
    /// true for strings that are keys rather than volume names: a UUID or an absolute path
    static func looksLikeKey(_ s: String) -> Bool {
        s.hasPrefix("/") || UUID(uuidString: s) != nil
    }

    /// Decision 0139: list local, browsable volumes; read-only ones too, unless
    /// they are mounted disk images.  `/` is always listed when browsable.
    static func shouldList(isLocal: Bool, isBrowsable: Bool, isReadOnly: Bool,
                           isRoot: Bool, isDiskImage: Bool) -> Bool {
        guard isLocal, isBrowsable else { return false }
        if isRoot { return true }
        if isReadOnly && isDiskImage { return false }
        return true
    }

    static func == (lhs: LocalVolume, rhs: LocalVolume) -> Bool {
        lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.key)
    }
}

