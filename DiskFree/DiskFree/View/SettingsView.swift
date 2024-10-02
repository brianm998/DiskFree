import SwiftUI

struct SettingsView: View {
    @State var viewModel: ViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Settings")
                Toggle(isOn: $viewModel.preferences.showUsedSpace) {
                    Text("show used space")
                }
                  .onChange(of: viewModel.preferences.showUsedSpace) { _, value in
                      viewModel.update()
                  }

                Toggle(isOn: $viewModel.preferences.showFreeSpace) {
                    Text("show free space")
                }
                  .onChange(of: viewModel.preferences.showFreeSpace) { _, value in
                      viewModel.update()
                  }

                Toggle(isOn: $viewModel.preferences.showMultipleCharts) {
                    Text("show multiple charts")
                }
                  .onChange(of: viewModel.preferences.showMultipleCharts) { _, value in
                      viewModel.update()
                  }

                Spacer()
                  .frame(maxHeight: 100)
                Text("select which disks to monitor")
                HStack {
                    Button(action: { viewModel.selectAll() }) {
                        Text("Select All")
                    }
                    Button(action: { viewModel.clearAll() }) {
                        Text("Clear All")
                    }
                }
                ForEach(self.viewModel.volumes) { volumeView in
                    VolumeChoiceItemView(viewModel: viewModel,
                                         volumeViewModel: volumeView)
                }
                Spacer()
                  .frame(maxHeight: 100)

                Toggle(isOn: $viewModel.preferences.soundVoiceOnErrors) {
                    Text("Sound Voice on Errors")
                }
                
                VoiceChooserView(labelText: "Error Voice:",
                                 voice: $viewModel.preferences.errorVoice)
                  .frame(maxWidth: 180)
                  .disabled(!viewModel.preferences.soundVoiceOnErrors)
                  .onChange(of: viewModel.preferences.errorVoice) { _, value in
                      viewModel.update()
                  }
                
                Spacer()
                  .frame(maxHeight: 20)
            }
        }
    }
}
