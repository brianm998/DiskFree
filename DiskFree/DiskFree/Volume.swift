import Foundation

struct Volume: Identifiable, Hashable {
  
    let name: String
    let mountPoint: String
    let size: SizeInfo?
    let id = UUID()

    public init(name: String,
                mountPoint: String,
                size: SizeInfo? = nil)
    {
        self.name = name
        self.mountPoint = mountPoint
        self.size = size
    }
    
    static func == (lhs: Volume, rhs: Volume) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.name)
    }
}

