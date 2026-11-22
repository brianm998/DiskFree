import Testing
import Foundation
import SwiftUI
@testable import DiskFree

/// Offscreen render timing of CombinedChartPlot (ImageRenderer, never a window).
/// Prints the timings; only asserts that an image came out.
struct ChartRenderTimingTests {
    @MainActor
    func render(volumes: Int, samples: Int) -> (ms: Double, ok: Bool) {
        let vm = ViewModel(demo: true)
        let now = Date().timeIntervalSince1970
        let g = SizeInfo.oneGiga
        vm.localVolumes = (0..<volumes).map { i in
            let lv = LocalVolume(name: "v\(i)", mountPoint: "/Volumes/v\(i)",
                                 userVisibleMountPoint: "/Volumes/v\(i)",
                                 isInternal: true, isEjectable: false)
            let m = VolumeViewModel(volume: lv, color: .blue, preferences: Preferences())
            let sizes = (0..<samples).map { s in
                SizeInfo(importantCapacity: (200 + i * 50 + (s * 7) % 40) * g,
                         opportunisticCapacity: (500 - (s % 30)) * g,
                         totalCapacity: 1000 * g,
                         timestamp: now - Double(samples - s) * 4)
            }
            m.sizes = sizes
            m.lastSize = sizes.last
            return m
        }
        let view = CombinedChartPlot(showFree: true, showUsed: false)
            .environment(vm)
            .frame(width: 1440, height: 900)
        let r = ImageRenderer(content: view)
        r.scale = 2
        _ = r.cgImage   // warm up
        let start = Date()
        let img = r.cgImage
        return (Date().timeIntervalSince(start) * 1000, img != nil)
    }

    @Test @MainActor func timeCombinedChartPlot() {
        for n in [6, 10] {
            let (ms, ok) = render(volumes: n, samples: 900)
            print("TIMING CombinedChartPlot \(n) volumes x 900 samples: \(Int(ms)) ms")
            #expect(ok)
        }
    }
}
