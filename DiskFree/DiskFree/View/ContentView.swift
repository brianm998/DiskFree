import SwiftUI

struct ContentView: View {
    var body: some View {
        if ScreenshotMode.isEnabled() {
            DemoContentView()
        } else {
            LiveContentView()
        }
    }
}

/// Holds the live model in @State so it is created once per window,
/// not on every evaluation of ContentView.body
private struct LiveContentView: View {
    @State private var viewModel = ViewModel()

    var body: some View {
        MainView()
          .environment(viewModel)
    }
}

/// App Store screenshot launches only (-screenshotMode)
private struct DemoContentView: View {
    @State private var viewModel = ViewModel(demo: true)

    var body: some View {
        MainView()
          .environment(viewModel)
    }
}

#Preview {
    ContentView()
}
