import SwiftUI

struct ContentView: View {
    var body: some View {
        if ScreenshotMode.isEnabled() {
            DemoContentView()
        } else {
            MainView()
              .environment(ViewModel())
        }
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
