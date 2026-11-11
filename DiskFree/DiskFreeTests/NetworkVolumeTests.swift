import Testing
import Foundation
@testable import DiskFree

struct NetworkVolumeTests {
    static let afp = "//admin@beast.local/root on /System/Volumes/Data/mnt/root (afpfs, nodev, nosuid, automounted, nobrowse, mounted by brian)"
    static let smb = "//brian@nas.local/share on /Volumes/share (smbfs, nodev, nosuid, mounted by brian)"

    @Test func afpLine() throws {
        let v = try #require(NetworkVolume(from: Self.afp))
        #expect(v.username == "admin")
        #expect(v.remoteHost == "beast.local")
        #expect(v.remotePath == "/root")
        #expect(v.localMount == "/mnt/root")   // /System/Volumes/Data stripped
        #expect(v.name == "/mnt/root")
        #expect(v.type == "afpfs")
    }

    @Test func smbLine() throws {
        let v = try #require(NetworkVolume(from: Self.smb))
        #expect(v.username == "brian")
        #expect(v.remoteHost == "nas.local")
        #expect(v.remotePath == "/share")
        #expect(v.localMount == "/Volumes/share")
        #expect(v.type == "smbfs")
    }

    @Test func lineWithoutUsernameIsNil() {
        #expect(NetworkVolume(from: "//nas.local/share on /Volumes/share (smbfs, nodev)") == nil)
    }

    @Test func localLineIsNil() {
        #expect(NetworkVolume(from: "/dev/disk3s1s1 on / (apfs, sealed, local, read-only, journaled)") == nil)
        #expect(NetworkVolume(from: "map auto_home on /System/Volumes/Data/home (autofs, automounted, nobrowse)") == nil)
        #expect(NetworkVolume(from: "") == nil)
    }

    @Test func equalityIgnoresId() throws {
        let a = try #require(NetworkVolume(from: Self.smb))
        let b = try #require(NetworkVolume(from: Self.smb))
        let c = try #require(NetworkVolume(from: Self.afp))
        #expect(a.id != b.id)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func ordersByLocalMount() throws {
        let a = try #require(NetworkVolume(from: Self.smb))   // /Volumes/share
        let c = try #require(NetworkVolume(from: Self.afp))   // /mnt/root
        #expect(a < c)
        #expect(!(c < a))
        #expect([c, a].sorted() == [a, c])
    }

    @Test func hashing() throws {
        let a = try #require(NetworkVolume(from: Self.smb))
        let b = try #require(NetworkVolume(from: Self.smb))
        let c = try #require(NetworkVolume(from: Self.afp))
        #expect(a.hashValue == b.hashValue)
        #expect(Set([a, b, c]).count == 2)
    }
}
