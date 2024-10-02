import SwiftUI

struct MainView: View {

    @State var viewModel: ViewModel
    
    var body: some View {
        VStack {
            HStack {
              ChartViews(viewModel: viewModel)
                if viewModel.preferences.showSettingsView {
                  SettingsView(viewModel: viewModel)
                }
            }
        }
          .toolbar {
              if viewModel.volumeRecordsTimeDurationSeconds != 0 {
                  ToolbarItem(placement: .principal) {
                      if viewModel.volumeRecordsTimeDurationSeconds < 60 {
                          let durationString = String(format: "%d", Int(viewModel.volumeRecordsTimeDurationSeconds))
                          Text("The last \(durationString) seconds of free space")
                      } else {
                          let durationString = String(format: "%d", Int(viewModel.volumeRecordsTimeDurationSeconds/60))
                          Text("The last \(durationString) minutes of free space")
                      }
                  }
              }
              ToolbarItem(placement: .primaryAction) {
                  Toggle(isOn: $viewModel.preferences.showSettingsView) {
                      if viewModel.preferences.showSettingsView {
                          Image(systemName: "chevron.right")
                      } else {
                          Image(systemName: "chevron.left")
                      }
                  }
                  .onChange(of: viewModel.preferences.showSettingsView) { _, value in
                      viewModel.update()
                  }
              }
          }
          .onAppear {
              viewModel.listVolumes()
          }
          .padding()
    }
}

