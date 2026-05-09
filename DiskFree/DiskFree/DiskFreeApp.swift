//
//  DiskFreeApp.swift
//  DiskFree
//
//  Created by Brian Martin on 9/24/24.
//

import SwiftUI

@main
struct DiskFreeApp: App {
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
