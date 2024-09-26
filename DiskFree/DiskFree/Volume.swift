import Foundation

struct Volume: Identifiable, Hashable {
  
    let name: String
    let size: SizeInfo?
    let id = UUID()

    public init(name: String,
                size: SizeInfo? = nil)
    {
        self.name = name
        self.size = size
    }
    
    static func == (lhs: Volume, rhs: Volume) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.name)
    }
}

