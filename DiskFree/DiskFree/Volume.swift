import Foundation

struct Volume: Identifiable, Hashable {
    let name: String
    var id: String { name }
}

