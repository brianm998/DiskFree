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
              if !viewModel.toolbarDurationText.isEmpty {
                  ToolbarItem(placement: .principal) {
                      Text(viewModel.toolbarDurationText)
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
              if viewModel.isDemo { return }
              viewModel.listLocalVolumes()
              viewModel.listNetworkVolumes()
          }
          .onDisappear {
              if viewModel.isDemo { return }
              viewModel.stopPolling()
          }
          .padding()
    }
}

