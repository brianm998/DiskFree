import SwiftUI

/// The single main window's content. The model belongs to the app
/// (see DiskFreeApp), not to the window, so polling does not depend on it.
struct ContentView: View {
    let viewModel: ViewModel

    var body: some View {
        MainView()
          .environment(viewModel)
    }
}

#Preview {
    ContentView(viewModel: ViewModel(demo: true))
}
