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
    @State var volumeViewModel: VolumeViewModel
    @Environment(ViewModel.self) var viewModel
    
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
              }
            
        }
    }
}


