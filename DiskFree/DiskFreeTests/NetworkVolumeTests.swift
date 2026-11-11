import Testing
import Foundation
@testable import DiskFree

struct NetworkVolumeTests {
    static let afp = (from: "//admin@beast.local/root", on: "/System/Volumes/Data/mnt/root", type: "afpfs")
    static let smb = (from: "//brian@nas.local/share", on: "/Volumes/share", type: "smbfs")

    @Test func afpLine() throws {
        let v = try #require(NetworkVolume(from: Self.afp.from, on: Self.afp.on, type: Self.afp.type))
        #expect(v.username == "admin")
        #expect(v.remoteHost == "beast.local")
        #expect(v.remotePath == "/root")
        #expect(v.localMount == "/mnt/root")   // /System/Volumes/Data stripped
        #expect(v.name == "/mnt/root")
        #expect(v.type == "afpfs")
    }

    @Test func smbLine() throws {
        let v = try #require(NetworkVolume(from: Self.smb.from, on: Self.smb.on, type: Self.smb.type))
        #expect(v.username == "brian")
        #expect(v.remoteHost == "nas.local")
        #expect(v.remotePath == "/share")
        #expect(v.localMount == "/Volumes/share")
        #expect(v.type == "smbfs")
    }

    @Test func lineWithoutUsername() throws {
        let v = try #require(NetworkVolume(from: "//nas.local/share", on: "/Volumes/share", type: "smbfs"))
        #expect(v.username == "")
        #expect(v.remoteHost == "nas.local")
        #expect(v.remotePath == "/share")
        #expect(v.localMount == "/Volumes/share")
    }

    @Test func hyphenatedHost() throws {
        let v = try #require(NetworkVolume(from: "//admin@my-nas-2.local/data", on: "/Volumes/data", type: "smbfs"))
        #expect(v.username == "admin")
        #expect(v.remoteHost == "my-nas-2.local")
        #expect(v.remotePath == "/data")
    }

    @Test func percentEncodedShare() throws {
        let v = try #require(NetworkVolume(from: "//brian@nas.local/My%20Share", on: "/Volumes/My Share", type: "smbfs"))
        #expect(v.remotePath == "/My%20Share")
        #expect(v.localMount == "/Volumes/My Share")
    }

    @Test func remountedPathWithSuffix() throws {
        let v = try #require(NetworkVolume(from: "//brian@nas.local/share", on: "/Volumes/share-1", type: "smbfs"))
        #expect(v.localMount == "/Volumes/share-1")
        #expect(v.type == "smbfs")
    }

    @Test func localMountWithSpace() throws {
        let v = try #require(NetworkVolume(from: "//admin@beast.local/root", on: "/System/Volumes/Data/mnt/my root", type: "afpfs"))
        #expect(v.localMount == "/mnt/my root")
        #expect(v.type == "afpfs")
    }

    @Test func localLineIsNil() {
        #expect(NetworkVolume(from: "/dev/disk3s1s1", on: "/", type: "apfs") == nil)
        #expect(NetworkVolume(from: "map auto_home", on: "/System/Volumes/Data/home", type: "autofs") == nil)
        #expect(NetworkVolume(from: "", on: "", type: "") == nil)
    }

    @Test func equalityIgnoresId() throws {
        let a = try #require(NetworkVolume(from: Self.smb.from, on: Self.smb.on, type: Self.smb.type))
        let b = try #require(NetworkVolume(from: Self.smb.from, on: Self.smb.on, type: Self.smb.type))
        let c = try #require(NetworkVolume(from: Self.afp.from, on: Self.afp.on, type: Self.afp.type))
        #expect(a.id != b.id)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func ordersByLocalMount() throws {
        let a = try #require(NetworkVolume(from: Self.smb.from, on: Self.smb.on, type: Self.smb.type))   // /Volumes/share
        let c = try #require(NetworkVolume(from: Self.afp.from, on: Self.afp.on, type: Self.afp.type))   // /mnt/root
        #expect(a < c)
        #expect(!(c < a))
        #expect([c, a].sorted() == [a, c])
    }

    @Test func hashing() throws {
        let a = try #require(NetworkVolume(from: Self.smb.from, on: Self.smb.on, type: Self.smb.type))
        let b = try #require(NetworkVolume(from: Self.smb.from, on: Self.smb.on, type: Self.smb.type))
        let c = try #require(NetworkVolume(from: Self.afp.from, on: Self.afp.on, type: Self.afp.type))
        #expect(a.hashValue == b.hashValue)
        #expect(Set([a, b, c]).count == 2)
    }
}

extension NetworkVolume {
    // fixture helper: builds from the (from, on, fstype) triple statfs reports
    init?(from from_: String, on: String, type: String) {
        self.init(mountedFrom: from_, onPath: on, fsType: type)
    }
}

struct NetworkVolumeStatfsTests {
    @Test func realStatfsStruct() throws {
        var fs = statfs()
        func put<T>(_ field: inout T, _ str: String) {
            withUnsafeMutableBytes(of: &field) { buf in
                for (i, b) in str.utf8.enumerated() { buf[i] = b }
            }
        }
        put(&fs.f_mntfromname, "//floof@mammoth/mammoth")
        put(&fs.f_mntonname, "/System/Volumes/Data/mammoth")
        put(&fs.f_fstypename, "smbfs")
        let v = try #require(NetworkVolume(statfs: fs))
        #expect(v.username == "floof")
        #expect(v.remoteHost == "mammoth")
        #expect(v.remotePath == "/mammoth")
        #expect(v.localMount == "/mammoth")
        #expect(v.type == "smbfs")
        put(&fs.f_mntfromname, "map auto_home")
        #expect(NetworkVolume(statfs: fs) == nil)
    }
}
