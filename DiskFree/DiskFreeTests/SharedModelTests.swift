import Testing
import Foundation
@testable import DiskFree

@MainActor
struct SharedModelTests {
    @Test func startPollingTwiceKeepsOneSetOfLoops() async {
        let vm = ViewModel()
        vm.persistsToDisk = false
        vm.networkPollIntervalOverride = 3600
        vm.localPollIntervalOverride = 3600
        await vm.manager.setOverrides(mountListing: { [] }, networkSize: nil)
        #expect(!vm.isPolling)
        vm.startPolling()
        #expect(vm.isPolling)
        vm.startPolling() // e.g. a second window appearing
        #expect(vm.isPolling)
        await vm.stopPollingAndWait()
        #expect(!vm.isPolling)
    }

    @Test func demoModelNeverPolls() {
        let vm = ViewModel(demo: true)
        vm.startPolling()
        #expect(!vm.isPolling)
    }

    @Test func aboutInfoPointsAtRepository() {
        #expect(AboutInfo.repositoryURL.absoluteString == "https://github.com/brianm998/DiskFree")
        #expect(!AboutInfo.version().isEmpty)
    }
}
