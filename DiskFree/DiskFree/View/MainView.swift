import SwiftUI

struct MainView: View {

    @Environment(ViewModel.self) var viewModel: ViewModel
    
    var body: some View {
        @Bindable var viewModel = viewModel

        return ChartViews()
          .sheet(isPresented: $viewModel.preferences.showSettingsView) {
              SettingsView()
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
                      Image(systemName: "gearshape")
                        .help("Show Settings")
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

