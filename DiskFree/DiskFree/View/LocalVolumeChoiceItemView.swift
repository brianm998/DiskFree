import SwiftUI

struct LocalVolumeChoiceItemView: View {
    @Environment(ViewModel.self) var viewModel: ViewModel
    @Binding var volumeViewModel: VolumeViewModel
    
    var body: some View {
        HStack {
            Toggle(isOn: $volumeViewModel.isSelected) {
                if let lastSize = volumeViewModel.lastSize {
                    Text("\(lastSize.totalSize) \(volumeViewModel.volume.name)")
                } else {
                    Text("\(volumeViewModel.volume.name)")
                }
            }
              .opacity(volumeViewModel.isMounted ? 1 : 0.5)
              .toggleStyle(.checkbox)
              .onChange(of: volumeViewModel.isSelected) { _, value in
                  viewModel.update(for: volumeViewModel)
              }
            if !volumeViewModel.isMounted {
                Text("not connected")
                  .font(.caption)
                  .foregroundStyle(.secondary)
            }
            
        }
    }
}


