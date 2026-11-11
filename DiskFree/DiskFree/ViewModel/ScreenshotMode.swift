import SwiftUI

/// Demo data for App Store screenshots.  Only active when the app is launched
/// with the `-screenshotMode` argument (see scripts/screenshots.sh); normal
/// launches never touch any of this.
///
/// Optional extra arguments:
///   -screenshotLayout combined|separate   chart layout to show
///   -screenshotSettings                   show the settings sheet
enum ScreenshotMode {
    static let argument = "-screenshotMode"

    static func isEnabled(arguments: [String] = CommandLine.arguments) -> Bool {
        arguments.contains(argument)
    }

    static func chartType(arguments: [String] = CommandLine.arguments) -> ChartType {
        if let i = arguments.firstIndex(of: "-screenshotLayout"),
           i + 1 < arguments.count,
           arguments[i + 1].lowercased() == "separate"
        {
            return .separate
        }
        return .combined
    }

    static func showsSettings(arguments: [String] = CommandLine.arguments) -> Bool {
        arguments.contains("-screenshotSettings")
    }

    private struct DemoSpec {
        let name: String
        let totalGB: Int
        let startFreeGB: Double
        let endFreeGB: Double
        let wobbleGB: Double
        let phase: Double
        let isInternal: Bool
    }

    private static let localSpecs: [DemoSpec] = [
        DemoSpec(name: "Macintosh HD", totalGB: 1000, startFreeGB: 420, endFreeGB: 355, wobbleGB: 6, phase: 0.0, isInternal: true),
        DemoSpec(name: "Projects SSD", totalGB: 2000, startFreeGB: 1250, endFreeGB: 1310, wobbleGB: 10, phase: 1.3, isInternal: false),
        DemoSpec(name: "Backup", totalGB: 4000, startFreeGB: 900, endFreeGB: 760, wobbleGB: 4, phase: 2.1, isInternal: false),
        DemoSpec(name: "Scratch", totalGB: 500, startFreeGB: 240, endFreeGB: 85, wobbleGB: 8, phase: 0.7, isInternal: false),
    ]

    private static let networkSpecs: [(DemoSpec, String)] = [
        (DemoSpec(name: "/Volumes/Media", totalGB: 8000, startFreeGB: 3100, endFreeGB: 3050, wobbleGB: 3, phase: 0.4, isInternal: false), "nas.local"),
    ]

    private static func records(for spec: DemoSpec, endingAt end: TimeInterval) -> [SizeInfo] {
        let count = 120
        let step = 30.0         // 60 minutes of history
        let giga = SizeInfo.oneGiga
        return (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            let free = spec.startFreeGB + (spec.endFreeGB - spec.startFreeGB) * t
              + spec.wobbleGB * sin(t * 9 + spec.phase)
            let freeBytes = Int(free * Double(giga))
            return SizeInfo(importantCapacity: freeBytes,
                            opportunisticCapacity: freeBytes,
                            totalCapacity: spec.totalGB * giga,
                            timestamp: end - Double(count - 1 - i) * step)
        }
    }

    @MainActor
    static func populate(_ viewModel: ViewModel, arguments: [String] = CommandLine.arguments) {
        let now = Date().timeIntervalSince1970
        var prefs = viewModel.preferences
        prefs.chartType = chartType(arguments: arguments)
        prefs.showSettingsView = showsSettings(arguments: arguments)
        prefs.soundVoiceOnWarnings = false
        prefs.soundVoiceOnErrors = false

        let colors: [Color] = [.blue, .cyan, .indigo, .brown, .purple]
        var local: [VolumeViewModel] = []
        for (i, spec) in localSpecs.enumerated() {
            let volume = LocalVolume(name: spec.name,
                                     mountPoint: "/Volumes/\(spec.name)",
                                     userVisibleMountPoint: "/Volumes/\(spec.name)",
                                     isInternal: spec.isInternal,
                                     isEjectable: !spec.isInternal)
            let vm = VolumeViewModel(volume: volume, color: colors[i], preferences: prefs)
            let sizes = records(for: spec, endingAt: now)
            vm.sizes = sizes
            vm.lastSize = sizes.last
            vm.isSelected = true
            local.append(vm)
        }
        var network: [VolumeViewModel] = []
        for (spec, host) in networkSpecs {
            let volume = NetworkVolume(username: "demo", remoteHost: host, remotePath: "/media",
                                       localMount: spec.name, type: "smbfs")
            let vm = VolumeViewModel(volume: volume, color: .purple, preferences: prefs)
            let sizes = records(for: spec, endingAt: now)
            vm.sizes = sizes
            vm.lastSize = sizes.last
            vm.isSelected = true
            network.append(vm)
        }
        prefs.localVolumesToShow = Set(local.map { $0.volume.name })
        viewModel.preferences = prefs
        viewModel.localVolumes = local
        viewModel.networkVolumes = network
        viewModel.volumeRecordsTimeDurationSeconds = 3570
        viewModel.applyDemoColors()
    }
}
