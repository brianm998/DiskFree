import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        VStack {
            HStack {
                ChartViews()
                if viewModel.preferences.showSettingsView {
                    SettingsView()
                }
            }
        }
          .toolbar {
              if viewModel.volumeRecordsTimeDurationSeconds != 0 {
                  ToolbarItem(placement: .principal) {
                      if viewModel.volumeRecordsTimeDurationSeconds < 60 {
                          let durationString = String(format: "%d", Int(viewModel.volumeRecordsTimeDurationSeconds))
                          Text("The last \(durationString) seconds of free space")
                      } else if viewModel.volumeRecordsTimeDurationSeconds < 60*60 {
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
                      viewModel.objectWillChange.send()
                  }
              }
          }
          .onAppear {
              viewModel.listVolumes()
          }
          .padding()
    }
}


struct VolumeChoiceItemView: View {
    @ObservedObject var volumeViewModel: VolumeViewModel
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        HStack {
            Toggle(isOn: $volumeViewModel.isSelected) {
                if let lastSize = volumeViewModel.lastSize {
                    Text("\(lastSize.totalSize) \(volumeViewModel.volume.name)")
                } else {
                    Text("\(volumeViewModel.volume.name)")
                }
            }
              .toggleStyle(.checkbox)
              .onChange(of: volumeViewModel.isSelected) { _, value in
                  viewModel.update(for: volumeViewModel)
                  viewModel.objectWillChange.send()
              }
            
        }
    }
}


