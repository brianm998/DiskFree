
import SwiftUI

struct ContentView: View {
    var body: some View {
        MainView()
          .environment(ViewModel())
    }
}

#Preview {
    ContentView()
}
