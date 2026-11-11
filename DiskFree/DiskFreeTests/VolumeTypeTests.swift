import Testing
import Foundation
@testable import DiskFree

struct VolumeTypeTests {
    static let smb = "//brian@nas.local/share on /Volumes/share (smbfs, nodev)"
    static let afp = "//admin@beast.local/root on /System/Volumes/Data/mnt/root (afpfs, nodev)"

    func net(_ line: String) throws -> NetworkVolume { try #require(NetworkVolume(from: line)) }
    func local(_ name: String) -> LocalVolume {
        LocalVolume(name: name, mountPoint: "/Volumes/\(name)",
                    userVisibleMountPoint: "/Volumes/\(name)",
                    isInternal: false, isEjectable: true)
    }

    @Test func equalityWithNetworkVolume() throws {
        let n = try net(Self.smb)
        #expect(VolumeType.network(n) == n)
        #expect(!(VolumeType.network(n) == (try net(Self.afp))))
        #expect(!(VolumeType.local(local("x")) == n))
    }

    @Test func equalityBetweenTypes() throws {
        let n = try net(Self.smb)
        #expect(VolumeType.network(n) == VolumeType.network(try net(Self.smb)))
        #expect(VolumeType.network(n) != VolumeType.network(try net(Self.afp)))
        #expect(VolumeType.local(local("x")) == VolumeType.local(local("x")))
        #expect(VolumeType.local(local("x")) != VolumeType.local(local("y")))
        #expect(VolumeType.local(local("x")) != VolumeType.network(n))
        #expect(VolumeType.network(n) != VolumeType.local(local("x")))
    }

    @Test func nameAndMountPath() throws {
        let n = VolumeType.network(try net(Self.afp))
        #expect(n.name == "/mnt/root")
        #expect(n.mountPath == "/mnt/root")
        let l = VolumeType.local(local("Disk"))
        #expect(l.name == "Disk")
        #expect(l.mountPath == "/Volumes/Disk")
    }

    @Test func orderingByName() throws {
        let a = VolumeType.local(local("Alpha"))
        let b = VolumeType.local(local("Beta"))
        let n = VolumeType.network(try net(Self.smb))   // "/Volumes/share"
        #expect(a < b)
        #expect(!(b < a))
        #expect(n < a)   // "/" sorts before letters
        #expect([b, n, a].sorted() == [n, a, b])
    }

    @Test func hashing() throws {
        let n1 = VolumeType.network(try net(Self.smb))
        let n2 = VolumeType.network(try net(Self.smb))
        #expect(n1.hashValue == n2.hashValue)
        #expect(Set([n1, n2, .local(local("x")), .local(local("x"))]).count == 2)
    }
}
