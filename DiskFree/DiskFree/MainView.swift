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
        List(viewModel.volumesSortedEmptyFirst) { volumeView in
            //ForEach(viewModel.volumes.list) { volumeView in
            if volumeView.isSelected {
                HStack {
                    Chart(volumeView.sizes) {
                        LineMark(
                          x: .value("time", Date(timeIntervalSince1970: $0.timestamp)),
			  y: .value("used", $0.gigsUsed),
                          series: .value("f", "a")
			)
			  .lineStyle(StrokeStyle(lineWidth: 2))
			  .foregroundStyle(.blue)
			  .interpolationMethod(.cardinal)
                        LineMark(
                          x: .value("time", Date(timeIntervalSince1970: $0.timestamp)),
			  y: .value("free", $0.gigsFree),
                          series: .value("f", "b")
			)
			  .lineStyle(StrokeStyle(lineWidth: 2))
			  .foregroundStyle(.green)
			  .interpolationMethod(.cardinal)
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
              .onChange(of: volumeViewModel.isSelected) {
                  viewModel.objectWillChange.send()
              }
               
            if let lastSize = volumeViewModel.lastSize {
                Text("\(lastSize.totalSize) \(volumeViewModel.volume.name)")
            } else {
                Text("\(volumeViewModel.volume.name)")
            }
        }
    }
}
