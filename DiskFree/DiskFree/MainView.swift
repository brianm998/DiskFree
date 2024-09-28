import SwiftUI
import Charts

struct MainView: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        VStack {
            HStack {
                VolumeActivityView()
                if viewModel.preferences.showSettingsView {
                    SettingsView()
                }
            }
        }
          .toolbar {
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

    func gradient(with color: Color) -> LinearGradient {
        LinearGradient(gradient: Gradient(colors: [color.opacity(0.3),
                                                   color.opacity(0.0001)]),
                       startPoint: .top,
                       endPoint: .bottom)
    }

        
    var body: some View {
      if viewModel.preferences.showMultipleCharts {
            self.multiCharts
        } else {
            self.combinedChartWithLegend
        }
    }

    
    var combinedChartWithLegend: some View {
        ZStack(alignment: .topLeading) {
            combinedChart
            legendForCombinedChart // XXX make this draggable
        }
    }

    private var volumesSortedByEmptyFirst: [Binding<VolumeViewModel>] {
        let list: [Binding<VolumeViewModel>] = $viewModel.volumes.list.map { $volume in return $volume }

        let ret = list.sorted { ($a: Binding<VolumeViewModel>, $b: Binding<VolumeViewModel>) in
            a.lastFreeSize() > b.lastFreeSize()
        }
        
        return ret
    }
    
    var legendForCombinedChart: some View {
        Group {
            if volumesSortedByEmptyFirst.count > 0 {
                VStack(alignment: .leading) {
                    Text("Free Space")
                    Grid(alignment: .leading) {
                        ForEach(volumesSortedByEmptyFirst) { $volumeView in
                            if volumeView.isSelected {
                                GridRow {
                                    Text(volumeView.volume.name)
                                      .foregroundStyle(volumeView.lineColor)
//                                      .foregroundStyle(.white)
//                                      .padding(2)
                            //          .background(volumeView.lineColor)
                                    Text(volumeView.chartFreeLineText)
                                      .foregroundStyle(volumeView.lineColor)
                                }
                            }
                        }
                    }
                    //        .frame(width: 50, height: 100)
                }
                  .padding(4)
                      .border(.black, width: 1)
                      .background(.white)
                      .opacity(0.8)
            }
        }
    }
    
    var combinedChart: some View {
        /*

         make a combined chart here
         
         */

        Chart {
            ForEach(viewModel.volumes.list) { volumeView in
                if volumeView.isSelected {
                    if viewModel.preferences.showFreeSpace {
                        ForEach(volumeView.sizes) { sizeData in
                            LineMark(
                              x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
		              y: .value("Gigabytes Free", sizeData.gigsFree),
                              series: .value(volumeView.volume.name,
                                             "\(volumeView.volume.name)1")
                            )
                              .interpolationMethod(.catmullRom)
                              .foregroundStyle(volumeView.lineColor)
                              .lineStyle(StrokeStyle(lineWidth: 6,
                                                     lineCap: .round, // .butt .square
                                                     lineJoin: .round, //.miter .bevel
                                                     miterLimit: 0,
                                                     dash: [12],
                                                     dashPhase: 0))

                            if volumeView.isMostEmpty {
                                AreaMark(
                                  x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
			          y: .value("free", sizeData.gigsFree),
                                  series: .value(volumeView.volume.name,
                                                 "\(volumeView.volume.name)1"),
                                  stacking: .unstacked
			        )
			          .lineStyle(StrokeStyle(lineWidth: 2))
			          .foregroundStyle(self.gradient(with: volumeView.lineColor))
                                  .interpolationMethod(.cardinal)
                            }
                        }
                        if volumeView.sizes.count > 0 {
                            let sizeData = volumeView.sizes[0]
                            PointMark(
                              x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
		              y: .value("Gigabytes Free", sizeData.gigsFree)
                            )
                              .symbolSize(24)
                              .foregroundStyle(volumeView.lineColor)
                              .annotation(position: .topTrailing, alignment: .bottomLeading) {
                                  Text(volumeView.volume.name)
                                    .foregroundStyle(volumeView.lineColor)
//                                    .padding(2)
                                    .background(Color(red: 236/255,
                                                      green: 235/255,
                                                      blue: 235/255))
                              } 
                        }
                        if let sizeData = volumeView.lastSize {
                            PointMark(
                              x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
		              y: .value("Gigabytes Free", sizeData.gigsFree)
                            )
                              .symbolSize(24)
                              .foregroundStyle(volumeView.lineColor)
                              .annotation(position: .topLeading, alignment: .bottomLeading) {
                                  Text(volumeView.volume.name)
                                    .foregroundStyle(volumeView.lineColor)
                                    .background(Color(red: 236/255,
                                                      green: 235/255,
                                                      blue: 235/255))
                              } 
                        }
                    }
                    if viewModel.preferences.showUsedSpace {
                        ForEach(volumeView.sizes) { sizeData in
                            LineMark(
                              x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
		              y: .value("Gigabytes Used", sizeData.gigsUsed),
                              series: .value(volumeView.volume.name,
                                             "\(volumeView.volume.name)2")
                            )
                              .interpolationMethod(.catmullRom)
			      .foregroundStyle(.red)
                        }/*
                        if let sizeData = volumeView.lastSize {
                            PointMark(
                              x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
		              y: .value("Gigabytes Used", sizeData.gigsUsed)
                            )
                              .symbolSize(2)
			      .foregroundStyle(.mint)
                              .annotation(position: .topLeading, alignment: .bottomLeading) {
                                  //Toggle(isOn: volumeView.isSelected) {
                                  Text(volumeView.chartUsedLineText)
                                  //}
                              } 
                        }*/
                    }
                }
            }
        }
          .chartYScale(domain: viewModel.minGigs(showFree: viewModel.preferences.showFreeSpace,
                                                 showUsed: viewModel.preferences.showUsedSpace)...viewModel.maxGigs(showFree: viewModel.preferences.showFreeSpace,
                                                                                                                     showUsed: viewModel.preferences.showUsedSpace)+20)

          .chartYAxisLabel("Gigabytes")
          .chartOverlay { (chartProxy: ChartProxy) in
              Color.clear
                .onContinuousHover { hoverPhase in
                    switch hoverPhase {
                    case .active(let location):
                        if let (foo, bar) = chartProxy.value(at: location,
                                                             as: (String, String).self) {
                            print("FUCKING foo \(foo) \(bar)")
                        }

                    case .ended:
                        break
                    }
                }
          }
    }
    
    var multiCharts: some View {
        VStack {
            ForEach(volumesSortedByEmptyFirst) { $volumeView in
                if volumeView.isSelected {
                    HStack {
                        Chart(volumeView.sizes) { sizeData in
                            if viewModel.preferences.showFreeSpace {
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
                            if viewModel.preferences.showUsedSpace {
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
                          .chartYScale(domain:volumeView.minGigs(showFree: viewModel.preferences.showFreeSpace,
                                                                 showUsed: viewModel.preferences.showUsedSpace)...volumeView.maxGigs(showFree: viewModel.preferences.showFreeSpace,
                                                                                                                                     showUsed: viewModel.preferences.showUsedSpace))
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

struct SettingsView: View {
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
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
            ForEach(viewModel.volumes.list) { volumeView in
                VolumeChoiceItemView(volumeViewModel: volumeView)
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
            
            Spacer()
              .frame(maxHeight: 20)
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
              .onChange(of: volumeViewModel.isSelected) { _, value in
                  viewModel.update(for: volumeViewModel)
                  viewModel.objectWillChange.send()
              }
            
        }
    }
}
