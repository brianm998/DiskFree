import SwiftUI
import AppKit

/// Offscreen App Store screenshot rendering, triggered by
/// `-renderScreenshots <dir>`.  Views are drawn with `ImageRenderer`; no
/// window is created, ordered front or activated.
enum ScreenshotRenderer {
    static let argument = "-renderScreenshots"
    static let layoutSize = CGSize(width: 1440, height: 900)
    static let scale: CGFloat = 2
    static let pixelSize = (width: 2880, height: 1800)

    static func outputDirectory(arguments: [String] = CommandLine.arguments) -> String? {
        guard let i = arguments.firstIndex(of: argument), i + 1 < arguments.count else { return nil }
        return arguments[i + 1]
    }

    /// file name -> view, built from demo data
    @MainActor
    static func screenshotViews() -> [(name: String, view: AnyView)] {
        func demo(_ type: ChartType, settings: Bool) -> ViewModel {
            let vm = ViewModel(demo: true)
            vm.preferences.chartType = type
            vm.preferences.showSettingsView = false
            _ = settings
            return vm
        }
        let combined = demo(.combined, settings: false)
        let separate = demo(.separate, settings: false)
        let settings = demo(.combined, settings: true)
        return [
            ("01-combined", AnyView(frame(MainView(), combined, title: true))),
            ("02-separate", AnyView(frame(MainView(), separate, title: true))),
            ("03-settings", AnyView(frame(SettingsView(), settings, title: false))),
        ]
    }

    @MainActor
    private static func frame<V: View>(_ content: V, _ vm: ViewModel, title: Bool) -> some View {
        VStack(spacing: 0) {
            if title {
                Text("The last \(Int(vm.volumeRecordsTimeDurationSeconds / 60)) minutes of free space")
                  .font(.headline)
                  .frame(maxWidth: .infinity, minHeight: 40)
            }
            content.environment(vm)
        }
        .frame(width: layoutSize.width, height: layoutSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, .light)
    }

    /// ImageRenderer cannot draw AppKit-backed controls (pickers, text fields),
    /// so the view is hosted in a borderless NSWindow that is never ordered
    /// front, and captured with cacheDisplay into an explicit 2880x1800 rep.
    @MainActor
    static func pngData(for view: AnyView) -> Data? {
        let rect = NSRect(origin: .zero, size: layoutSize)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = rect
        let window = NSWindow(contentRect: rect, styleMask: .borderless,
                              backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        // let SwiftUI finish its pending updates before capturing
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        hosting.layoutSubtreeIfNeeded()
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixelSize.width, pixelsHigh: pixelSize.height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = layoutSize
        hosting.cacheDisplay(in: rect, to: rep)
        return rep.representation(using: .png, properties: [:])
    }

    /// Renders everything into `directory`; returns false on any failure.
    @MainActor
    static func render(to directory: String) -> Bool {
        do {
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            for (name, view) in screenshotViews() {
                guard let data = pngData(for: view) else {
                    FileHandle.standardError.write(Data("failed to render \(name)\n".utf8))
                    return false
                }
                try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name + ".png"))
            }
            return true
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            return false
        }
    }
}
