import SwiftUI
import Charts

struct MainView: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        HStack {
            // XXX add more shit here
            VolumeActivityView()
            VolumeChoiceView()
        }
          .onAppear {
              viewModel.listVolumes()
          }
//          .padding()
    }
}

struct VolumeActivityView: View {
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        List(viewModel.volumes.list) { volumeView in
            //ForEach(viewModel.volumes.list) { volumeView in
            if volumeView.isSelected {
                HStack {
                    Chart(volumeView.sizes) {
                        LineMark(
                          x: .value("time", Date(timeIntervalSince1970: $0.timestamp)),
			  y: .value("used", $0.gigsUsed)
			)

			.lineStyle(StrokeStyle(lineWidth: 2))
			.foregroundStyle(.blue)
			.interpolationMethod(.cardinal)
//			.symbol(Circle().strokeBorder(lineWidth: 4))
			.symbolSize(60)
                    }
                    VStack(alignment: .leading) {
                        Text(volumeView.volume.name)
                        if let volumeSize = volumeView.lastSize {
                            Text("\(volumeSize.totalSize) total")
                            Text("\(volumeSize.freeSize) free")
                            Text("\(volumeSize.usedSize) used")
                        }
                    }
                      .frame(minWidth: 100)
//                    Text("\(volumeView.sizes.count) sizes \(volumeView.counter) counter")
                }
            }
        }
    }
}

struct VolumeChoiceView: View {
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        VStack {
            Text("Set your Disks Free! \(viewModel.volumes.list.count) volumes on iteration \(viewModel.counter)")
            VStack(alignment: .leading) {
//                List(viewModel.volumes.list) { volumeView in
                ForEach(viewModel.volumes.list) { volumeView in
                    VolumeChoiceItemView(volumeViewModel: volumeView)
                }
            }
        }
    }
}

struct VolumeChoiceItemView: View {
    @ObservedObject var volumeViewModel: VolumeViewModel
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        HStack {
            Toggle(isOn: $volumeViewModel.isSelected) {
                
            }
              .toggleStyle(.checkbox)
              .onChange(of: volumeViewModel.isSelected) {                   viewModel.objectWillChange.send()
              }
               
            if let lastSize = volumeViewModel.lastSize {
                
                Text("\(volumeViewModel.volume.name) \(lastSize.totalSize) \(volumeViewModel.sizes.count) sizes \(volumeViewModel.counter) counter")
            } else {
                Text("\(volumeViewModel.volume.name)")
            }
        }
    }
}
