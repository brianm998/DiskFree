import Foundation

struct LocalVolume: Identifiable, Hashable {
  
    let name: String
    let mountPoint: String
    let userVisibleMountPoint: String
    let size: SizeInfo?
    let id = UUID()
    let isInternal: Bool
    let isEjectable: Bool

    public init(name: String,
                mountPoint: String,
                userVisibleMountPoint: String,
                isInternal: Bool,
                isEjectable: Bool,
                size: SizeInfo? = nil)
    {
        self.name = name
        self.mountPoint = mountPoint
        self.userVisibleMountPoint = userVisibleMountPoint
        self.size = size
        self.isEjectable = isEjectable
        self.isInternal = isInternal
    }
    
    static func == (lhs: LocalVolume, rhs: LocalVolume) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.name)
    }
}

