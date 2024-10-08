import Foundation

enum VolumeType: Equatable,
                 Comparable,
                 Hashable
{
    case network(NetworkVolume)
    case local(LocalVolume)

    // XXX expose switched vars here for info about this crap

    var mountPath: String {
        switch self {
        case .network(let volume):
            return volume.localMount
        case .local(let volume):
            return volume.userVisibleMountPoint
        }
    }
    
    var name: String {
        switch self {
        case .network(let volume):
            return volume.localMount
        case .local(let volume):
            return volume.name
        }
    }

    static func == (lhs: VolumeType, rhs: NetworkVolume) -> Bool {
        switch lhs {
        case .network(let lhsVolume):
            return lhsVolume == rhs
        case .local(let lhsVolume):
            return false
        }
    }

    static func == (lhs: VolumeType, rhs: VolumeType) -> Bool {
        switch lhs {
        case .network(let lhsVolume):
            switch rhs {
            case .network(let rhsVolume):
                return lhsVolume == rhsVolume
            case .local(let rhsVolume):
                return false
            }
        case .local(let lhsVolume):
            switch rhs {
            case .network(let rhsVolume):
                return false
            case .local(let rhsVolume):
                return lhsVolume == rhsVolume
            }
        }
    }

    static func < (lhs: VolumeType, rhs: VolumeType) -> Bool {
        lhs.name < rhs.name
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .network(let volume):
            hasher.combine(volume)
        case .local(let volume):
            hasher.combine(volume)
        }
    }    
}
