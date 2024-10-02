import SwiftUI
import Charts

// split this up
struct ChartViews: View {
    @State var viewModel: ViewModel

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
                                                   color.opacity(0.002)]),
                       startPoint: UnitPoint(x: 0, y: 0),
                       endPoint: UnitPoint(x: 0, y: 0.8))
    }

        
    var body: some View {
      if viewModel.preferences.showMultipleCharts {
            self.multiCharts
        } else {
            self.combinedChartWithLegend
        }
    }

    
    var combinedChartWithLegend: some View {
        HStack(alignment: .top) {
            combinedChart
            legendForCombinedChart
        }
    }

    private var volumesSortedByEmptyFirst: [VolumeViewModel] {
        let list: [VolumeViewModel] = viewModel.volumes.list

        let ret = list.sorted { (a: VolumeViewModel, b: VolumeViewModel) in
            a.lastFreeSize() > b.lastFreeSize()
        }
        
        return ret
    }
    
    var legendForCombinedChart: some View {
        Group {
            if viewModel.volumes.list.count > 0 {
                    VStack(alignment: .leading) {
                        Text("Free Space")
                          .font(.system(size: viewModel.preferences.legendFontSize))
                        Grid(alignment: .leading) {
                            ForEach($viewModel.volumes.list) { $volumeView in
                                if volumeView.isSelected {
                                    GridRow {
                                        Text(volumeView.volume.name)
                                          .font(.system(size: viewModel.preferences.legendFontSize))
                                          .foregroundStyle(volumeView.lineColor)
                                        //                                      .foregroundStyle(.white)
                                        //                                      .padding(2)
                                        //          .background(volumeView.lineColor)
                                        Text(volumeView.chartFreeLineText)
                                          .font(.system(size: viewModel.preferences.legendFontSize))
                                          .foregroundStyle(volumeView.showLowSpaceWarning ? .red : volumeView.lineColor)
                                          .blinking(if: volumeView.showLowSpaceWarning,
                                                      duration: 0.4)
                                        
                                        // never ends :(                .animation(Animation.easeInOut(duration:0.4).repeatForever(autoreverses:true))
                                        
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                      .frame(maxHeight: .infinity)
                      .overlay(
                        HStack {
                            Button(action: { viewModel.decreaseFontSize() }) {
                                Image(systemName: "minus.square")
                                  .resizable()
                                  .frame(width: 20, height: 20)
                            }
                              .buttonStyle(BorderlessButtonStyle())
                            Button(action: { viewModel.increaseFontSize() }) {
                                Image(systemName: "plus.square")
                                  .resizable()
                                  .frame(width: 20, height: 20)
                            }
                              .buttonStyle(BorderlessButtonStyle())
                        },
                        alignment: .bottomTrailing)
                    

            }
        }
    }
    
    var combinedChart: some View {
        /*

         make a combined chart here
         
         */

        Chart {
            let lineWidth = 6
            let dotSize = 24//lineWidth*4
            ForEach(self.volumesSortedByEmptyFirst) { volumeView in
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
                              .lineStyle(StrokeStyle(lineWidth: 4,
                                                     lineCap: .round, // .butt .square
                                                     lineJoin: .round, //.miter .bevel
                                                     miterLimit: 0,
                                                     dash: [12],
                                                     dashPhase: 0))

                            if volumeView.isMostFull {
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
                              .symbolSize(16)
                              .foregroundStyle(volumeView.lineColor)
                              .annotation(position: .leading, alignment: .bottom) {
                                  Text(volumeView.volume.name)
                                    .font(.system(size: 22))
                                    .foregroundStyle(volumeView.lineColor)
                                    .frame(maxWidth: 50)
                                    .blinking(if: volumeView.showLowSpaceWarning,
                                                duration: 0.4)
                              } 
                        }
                        if let sizeData = volumeView.lastSize {
                            if volumeView.isMostFull {
                                PointMark(
                                  x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
		                  y: .value("Gigabytes Free", sizeData.gigsFree)
                                )
                                  .symbolSize(16)
                                  .foregroundStyle(volumeView.lineColor)
                                  .annotation(position: .leading, alignment: .top) {
                                      Text(volumeView.volume.name)
                                        .font(.system(size: 22))
                                        .foregroundStyle(volumeView.lineColor)
                                        .blinking(if: volumeView.showLowSpaceWarning,
                                                    duration: 0.4)
                                  } 

                            } else {
                                PointMark(
                                  x: .value("time", Date(timeIntervalSince1970: sizeData.timestamp)),
		                  y: .value("Gigabytes Free", sizeData.gigsFree)
                                )
                                  .symbolSize(16)
                                  .foregroundStyle(volumeView.lineColor)
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
          .chartXAxis {
              AxisMarks(preset: .aligned) // XXX doesn't help :(
          }
          .chartYScale(domain: viewModel.minGigs(showFree: viewModel.preferences.showFreeSpace,
                                                 showUsed: viewModel.preferences.showUsedSpace)...viewModel.maxGigs(showFree: viewModel.preferences.showFreeSpace,
                                                                                                                     showUsed: viewModel.preferences.showUsedSpace)+20)

          .chartYAxisLabel("Gigabytes")
        /* XXX doesn't work :(
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
          }*/
    }
    
    var multiCharts: some View {
        VStack {
            ForEach(volumesSortedByEmptyFirst) { volumeView in
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
