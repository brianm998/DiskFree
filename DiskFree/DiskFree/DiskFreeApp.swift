//
//  DiskFreeApp.swift
//  DiskFree
//
//  Created by Brian Martin on 9/24/24.
//

import SwiftUI

/// Closing the main window quits the app: with no window there is nothing to
/// show, and one model owning the polling means no second writer of the files.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

enum AboutInfo {
    static let repositoryURL = URL(string: "https://github.com/brianm998/DiskFree")!

    static func version(_ bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    static func copyright(_ bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String ?? ""
    }

    @MainActor static func show() {
        let credits = NSMutableAttributedString(
            string: "Source code: ",
            attributes: [.font: NSFont.systemFont(ofSize: 11),
                         .foregroundColor: NSColor.labelColor])
        credits.append(NSAttributedString(
            string: repositoryURL.absoluteString,
            attributes: [.font: NSFont.systemFont(ofSize: 11), .link: repositoryURL]))
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationVersion: version(),
            .version: "",
            .credits: credits,
        ])
    }
}

struct DiskFreeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    /// One model for the whole app; it owns the polling loops.
    @State private var viewModel: ViewModel

    init() {
        // Offscreen screenshot rendering: handled before any scene exists,
        // so no window is ever created, shown or activated.
        if let dir = ScreenshotRenderer.outputDirectory() {
            NSApplication.shared.setActivationPolicy(.prohibited)
            let ok = MainActor.assumeIsolated { ScreenshotRenderer.render(to: dir) }
            exit(ok ? 0 : 1)
        }
        let model = ScreenshotMode.isEnabled() ? ViewModel(demo: true) : ViewModel()
        model.startPolling()
        _viewModel = State(initialValue: model)
    }

    var body: some Scene {
        Window("Disk Free", id: "main") {
            ContentView(viewModel: viewModel)
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Disk Free") { AboutInfo.show() }
            }
        }
    }
}

/// SwiftUI startup can reset the activation policy after `main()` sets it, so
/// reassert `.prohibited` at each launch callback.
final class TestHostDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.prohibited)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.prohibited)
    }
}

/// Minimal app used when the process only hosts unit tests: no window opens.
struct TestHostApp: App {
    @NSApplicationDelegateAdaptor(TestHostDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@main
enum DiskFreeLauncher {
    static func main() {
        if TestHost.isActive {
            NSApplication.shared.setActivationPolicy(.prohibited)
            TestHostApp.main()
        } else {
            DiskFreeApp.main()
        }
    }
}
