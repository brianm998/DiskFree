import Testing
import Foundation
@testable import DiskFree

@MainActor
struct SelectionTests {
    func vol(_ name: String) -> LocalVolume {
        LocalVolume(name: name, mountPoint: "/Volumes/\(name)", userVisibleMountPoint: "/Volumes/\(name)",
                    isInternal: true, isEjectable: false)
    }

    func net(_ mount: String) -> NetworkVolume {
        NetworkVolume(username: "u", remoteHost: "h", remotePath: "/p", localMount: mount, type: "smbfs")
    }

    func roundTrip(_ p: Preferences) throws -> Preferences {
        try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(p))
    }

    @Test func hiddenDecidesSelection() {
        let vm = ViewModel()
        vm.preferences.localVolumesHidden = ["/Volumes/B"]
        vm.reconcileLocalVolumes(with: [vol("A"), vol("B"), vol("rp")])
        #expect(vm.localVolumes.map { $0.isSelected } == [true, false, true])
    }

    @Test func networkToggleUsesNetworkSet() {
        let vm = ViewModel()
        let n = VolumeViewModel(volume: net("/mnt/x"), color: .purple, preferences: vm.preferences)
        n.isSelected = false
        vm.update(for: n)
        #expect(vm.preferences.networkVolumesHidden == ["/mnt/x"])
        #expect(vm.preferences.localVolumesHidden.isEmpty)
        n.isSelected = true
        vm.update(for: n)
        #expect(vm.preferences.networkVolumesHidden.isEmpty)
    }

    @Test func clearAllSurvivesRoundTrip() throws {
        let vm = ViewModel()
        vm.reconcileLocalVolumes(with: [vol("A"), vol("B")])
        vm.clearAll()
        let q = try roundTrip(vm.preferences)
        #expect(q.localVolumesHidden == ["/Volumes/A", "/Volumes/B"])
        vm.selectAll()
        #expect(vm.preferences.localVolumesHidden.isEmpty)
    }

    @Test func migrationFromShowSet() async throws {
        var old = Preferences()
        old.localVolumesToShow = ["A"]
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as! [String: Any]
        json.removeValue(forKey: "localVolumesHidden")
        json.removeValue(forKey: "networkVolumesHidden")
        let loaded = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(loaded.legacyLocalVolumesToShow == ["A"])
        let vm = ViewModel(preferenceLoader: { loaded })
        _ = try await vm.discoverLocalVolumes(listing: { [self] in [vol("A"), vol("B")] })
        #expect(vm.localVolumes.map { $0.isSelected } == [true, false])
        #expect(vm.preferences.localVolumesHidden == ["/Volumes/B"])
        #expect(vm.preferences.legacyLocalVolumesToShow == nil)
        let written = try JSONSerialization.jsonObject(with: JSONEncoder().encode(vm.preferences)) as! [String: Any]
        #expect(written["localVolumesHidden"] != nil)
    }

    @Test func slowLoaderIsAwaitedBeforeDiscovery() async throws {
        var p = Preferences()
        p.localVolumesHidden = ["/Volumes/B"]
        let loaded = p
        let vm = ViewModel(preferenceLoader: {
            try? await Task.sleep(nanoseconds: 300_000_000)
            return loaded
        })
        _ = try await vm.discoverLocalVolumes(listing: { [self] in [vol("A"), vol("B")] })
        #expect(vm.localVolumes.map { $0.isSelected } == [true, false])
    }
}
