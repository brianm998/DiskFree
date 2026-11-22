import Testing
import Foundation
@testable import DiskFree

@MainActor
struct LowSpaceAlertTests {
    func size(gigs: Int) -> SizeInfo {
        SizeInfo(importantCapacity: gigs * SizeInfo.oneGiga, opportunisticCapacity: 0,
                 totalCapacity: 1000 * SizeInfo.oneGiga, timestamp: 0)
    }

    func setup(selected: Bool = true) -> (ViewModel, VolumeViewModel, () -> [String]) {
        let vm = ViewModel()
        vm.preferences.soundVoiceOnWarnings = true
        vm.preferences.soundVoiceOnErrors = false
        vm.preferences.lowSpaceWarningThresholdGigs = 20
        let box = Box()
        vm.speak = { m, _ in box.said.append(m) }
        let n = NetworkVolume(username: "u", remoteHost: "h", remotePath: "/p", localMount: "/mnt/x", type: "smbfs")
        let v = VolumeViewModel(volume: n, color: .blue, preferences: vm.preferences)
        v.isSelected = selected
        return (vm, v, { box.said })
    }

    final class Box { var said: [String] = [] }

    func feed(_ vm: ViewModel, _ v: VolumeViewModel, _ gigs: [Int]) {
        var old = size(gigs: 100)
        for g in gigs {
            let new = size(gigs: g)
            vm.checkSpaceAlerts(for: v, oldSize: old, newSize: new)
            old = new
        }
    }

    @Test func networkCrossingAnnouncesOnce() {
        let (vm, v, said) = setup()
        feed(vm, v, [30, 19, 18, 17])
        #expect(said().count == 1)
        #expect(said()[0].contains("/mnt/x"))
    }

    @Test func oscillationAnnouncesLowOnly() {
        let (vm, v, said) = setup()
        feed(vm, v, [19, 21, 19, 21, 19, 21])
        #expect(said().count == 1)
        #expect(said()[0].contains("Low Disk Space Warning"))
    }

    @Test func recoveryAnnouncedOnce() {
        let (vm, v, said) = setup()
        feed(vm, v, [19, 21, 23, 30, 31])
        #expect(said().count == 2)
        #expect(said()[1].contains("no longer low"))
    }

    @Test func unselectedNeverAnnounces() {
        let (vm, v, said) = setup(selected: false)
        feed(vm, v, [30, 10, 40, 5])
        #expect(said().isEmpty)
    }
}
