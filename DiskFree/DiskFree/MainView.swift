import SwiftUI
import Charts

struct MainView: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        VStack {
            TopView()
            HStack {
                // XXX add more shit here
                VolumeActivityView()
                VolumeChoiceView()
            }
        }
          .onAppear {
              viewModel.listVolumes()
          }
          .padding()
    }
}
struct TopView: View {
    @EnvironmentObject var viewModel: ViewModel
    var body: some View {
        HStack {
            Toggle(isOn: $viewModel.showUsedSpace) {
                Text("show used space")
            }
            Toggle(isOn: $viewModel.showFreeSpace) {
                Text("show free space")
            }
            Toggle(isOn: $viewModel.showMultipleCharts) {
                Text("show multiple charts")
            }
        }
    }
}
struct VolumeActivityView: View {
    @EnvironmentObject var viewModel: ViewModel

    var redGradientColor: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [Color.red.opacity(0.8),
                                                   Color.red.opacity(0.01)]),
                       startPoint: .top,
                       endPoint: .bottom)
    }
    
    var greenGradientColor: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [Color.green.opacity(0.8),
                                                   Color.green.opacity(0.01)]),
                       startPoint: .top,
                       endPoint: .bottom)
    }

    
    
    var body: some View {
        if viewModel.showMultipleCharts {
            self.multiCharts
        } else {
            self.combinedChart
        }
    }

    let colors: [Color] =
      [.mint,
       .green,
       .blue,
       .brown,
       .cyan,
       .indigo,
       .orange,
       .pink,
       .purple,
       .red,
       .teal,
       .white,
       .yellow]

    var combinedChart: some View {
        /*

         make a combined chart here
         
         */

        return Chart {
            ForEach(viewModel.volumesSortedEmptyFirst) { volumeView in
                if volumeView.isSelected {
                    if viewModel.showFreeSpace {
                        ForEach(volumeView.sizes) { sizeData in
                            LineMark(
                              x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
		              y: .value("free", sizeData.gigsFree),
                              series: .value(volumeView.volume.name,
                                             "\(volumeView.volume.name)1")
                            )
			      .foregroundStyle(.green)
                              .annotation(position: .overlay, alignment: .bottom) {
                                  Text(volumeView.volume.name)
                              }
                        }
                    }
                    if viewModel.showUsedSpace {
                        ForEach(volumeView.sizes) { sizeData in
                            LineMark(
                              x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
		              y: .value("free", sizeData.gigsUsed),
                              series: .value(volumeView.volume.name,
                                             "\(volumeView.volume.name)2")
                            )
			      .foregroundStyle(.red)
                              .annotation(position: .overlay, alignment: .bottom) {
                                  Text(volumeView.volume.name)
                              }
                        }
                    }
                }
            }
        }
    }
    
    var multiCharts: some View {
        VStack {
            ForEach(viewModel.volumesSortedEmptyFirst) { volumeView in
                if volumeView.isSelected {
                    HStack {
                        Chart(volumeView.sizes) { sizeData in
                            if viewModel.showFreeSpace {
                                AreaMark(
                                  x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
			          y: .value("free", sizeData.gigsFree),
                                  series: .value("G", "b"),
                                  stacking: .unstacked
			        )
			          .lineStyle(StrokeStyle(lineWidth: 2))
			          .foregroundStyle(greenGradientColor)
			          .interpolationMethod(.cardinal)
                            }
                            if viewModel.showUsedSpace {
                                AreaMark(
                                  x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
			          y: .value("used", sizeData.gigsUsed),
                                  series: .value("f", "a"),
                                  stacking: .unstacked
			        )
			          .lineStyle(StrokeStyle(lineWidth: 2))
			          .foregroundStyle(redGradientColor)
			          .interpolationMethod(.cardinal)
                            }
                        }
                          .chartYScale(domain:0...volumeView.maxGigs(showFree: viewModel.showFreeSpace,
                                                                     showUsed: viewModel.showUsedSpace))
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
}

struct VolumeChoiceView: View {
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        VStack {
            Text("select which disks to monitor")
            HStack {
                Button(action: { viewModel.selectAll() }) {
                    Text("Select All")
                }
                Button(action: { viewModel.clearAll() }) {
                    Text("Clear All")
                }
            }
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
                if let lastSize = volumeViewModel.lastSize {
                    Text("\(lastSize.totalSize) \(volumeViewModel.volume.name)")
                } else {
                    Text("\(volumeViewModel.volume.name)")
                }
            }
              .toggleStyle(.checkbox)
              .onChange(of: volumeViewModel.isSelected) {
                  viewModel.objectWillChange.send()
              }
            
        }
    }
}
