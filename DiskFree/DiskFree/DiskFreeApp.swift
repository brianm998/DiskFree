//
//  DiskFreeApp.swift
//  DiskFree
//
//  Created by Brian Martin on 9/24/24.
//

import SwiftUI

struct DiskFreeApp: App {
    init() {
        // Offscreen screenshot rendering: handled before any scene exists,
        // so no window is ever created, shown or activated.
        if let dir = ScreenshotRenderer.outputDirectory() {
            NSApplication.shared.setActivationPolicy(.prohibited)
            let ok = MainActor.assumeIsolated { ScreenshotRenderer.render(to: dir) }
            exit(ok ? 0 : 1)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

        Window("About Disk Free", id: "about") { // doesn't show up :(
            Text("About")
              .toolbarBackground(.hidden, for: .windowToolbar)
              .containerBackground(.thickMaterial, for: .window)
//              .windowMinimizeBehaviour(.disabled)
        }
        
    }
}

/// Minimal app used when the process only hosts unit tests: no window opens.
struct TestHostApp: App {
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
