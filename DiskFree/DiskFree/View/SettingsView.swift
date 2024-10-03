import SwiftUI



struct SettingsView: View {
    @State var viewModel: ViewModel

    var generalSettings: some View {
        VStack(alignment: .leading) {
            Text("General")
              .font(.system(size: 18))
              .foregroundColor(.gray)

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
            HStack {
                Text("Check Every")
                TextField("\(viewModel.preferences.pollIntervalSeconds)",
                          value: $viewModel.preferences.pollIntervalSeconds,
                          format: .number)
                  .frame(maxWidth: 22)
                Text("Seconds")
            }
        }
    }    

    var diskSettings: some View {
        VStack(alignment: .leading) {
            Text("Disks")
              .font(.system(size: 18))
              .foregroundColor(.gray)
            
            Text("DiskFree can show any of these")
              .font(.system(size: 10))
              .foregroundColor(.gray)

            ScrollView {
                VStack(alignment: .leading) {

                    ForEach(self.viewModel.volumes) { volumeView in
                        VolumeChoiceItemView(viewModel: viewModel,
                                             volumeViewModel: volumeView)
                    }
                }
            }
            HStack {
                Button(action: { viewModel.selectAll() }) {
                    Text("Select All")
                }
                Button(action: { viewModel.clearAll() }) {
                    Text("Clear All")
                }
            }
        }
    }
    
    var audioSettings: some View {
        VStack(alignment: .leading) {
            Text("Audio")
              .font(.system(size: 18))
              .foregroundColor(.gray)

            Text("DiskFree can speak when space runs too low.")
              .font(.system(size: 10))
              .foregroundColor(.gray)

            VStack(alignment: .leading) {
                Toggle(isOn: $viewModel.preferences.soundVoiceOnWarnings) {
                    Text("Say Warnings")
                }

                HStack {
                    Text("Below")
                    TextField("\(viewModel.preferences.lowSpaceWarningThresholdGigs)",
                              value: $viewModel.preferences.lowSpaceWarningThresholdGigs,
                              format: .number)
                      .disabled(!viewModel.preferences.soundVoiceOnWarnings)
                      .frame(maxWidth: 40)
                      .onChange(of: viewModel.preferences.lowSpaceWarningThresholdGigs) { _, _ in
                          viewModel.update()
                      }
                    
                    Text("Gigs")
                }
            VoiceChooserView(labelText: "Voice:",
                             voice: $viewModel.preferences.warningVoice)
              .frame(maxWidth: 180)
              .disabled(!viewModel.preferences.soundVoiceOnWarnings)
              .onChange(of: viewModel.preferences.warningVoice) { _, value in
                  viewModel.update()
              }
            }
              .padding()
              .background(.yellow.opacity(0.8))

            VStack(alignment: .leading) {
                Toggle(isOn: $viewModel.preferences.soundVoiceOnErrors) {
                    Text("Say Errors")
                }
                HStack {
                    Text("Below")
                    TextField("\(viewModel.preferences.lowSpaceErrorThresholdGigs)",
                              value: $viewModel.preferences.lowSpaceErrorThresholdGigs,
                              format: .number)
                      .frame(maxWidth: 40)
                      .disabled(!viewModel.preferences.soundVoiceOnErrors)
                      .onChange(of: viewModel.preferences.lowSpaceErrorThresholdGigs) { _, _ in
                          viewModel.update()
                      }
                    Text("Gigs")
                }
            
            VoiceChooserView(labelText: "Voice:",
                             voice: $viewModel.preferences.errorVoice)
              .frame(maxWidth: 180)
              .disabled(!viewModel.preferences.soundVoiceOnErrors)
              .onChange(of: viewModel.preferences.errorVoice) { _, value in
                  viewModel.update()
              }
            }
              .padding()
              .background(.red.opacity(0.8))
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: { viewModel.preferences.showSettingsView = false } ) {
                Image(systemName: "xmark")
            }
              .buttonStyle(BorderlessButtonStyle())

            VStack(alignment: .center) {
                Text("Settings")
                  .font(.system(size: 28))
                  .foregroundColor(.gray)
                Spacer()
                HStack(alignment: .top) {
                    generalSettings
                    diskSettings
                    audioSettings
                }
                  .frame(minWidth: 600)
            }
        }
          .padding()
    }
}
