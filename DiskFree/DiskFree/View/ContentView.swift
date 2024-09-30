
import SwiftUI

struct ContentView: View {
    var body: some View {
        let viewModel = ViewModel()
        MainView()
          .environmentObject(viewModel)
    }
}

#Preview {
    ContentView()
}
