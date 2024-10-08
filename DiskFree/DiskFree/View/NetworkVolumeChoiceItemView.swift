import SwiftUI

struct NetworkVolumeChoiceItemView: View {
    @Environment(ViewModel.self) var viewModel: ViewModel
    @Binding var volumeViewModel: NetworkVolumeViewModel
    
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


