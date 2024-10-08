import SwiftUI
import Charts

struct CombinedChartView: View {
    @Environment(ViewModel.self) var viewModel: ViewModel

    var body: some View {
        HStack(alignment: .top) {
            combinedChart
            chartLegend
        }
    }

    func gradient(with color: Color) -> LinearGradient {
        LinearGradient(gradient: Gradient(colors: [color.opacity(0.3),
                                                   color.opacity(0.002)]),
                       startPoint: UnitPoint(x: 0, y: 0),
                       endPoint: UnitPoint(x: 0, y: 0.8))
    }

    var chartLegend: some View {
        Group {
            if viewModel.localVolumes.count > 0 {
                VStack(alignment: .leading) {
                    Text("Free Space")
                      .font(.system(size: viewModel.preferences.legendFontSize))
                    Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 0) {
                        ForEach(self.viewModel.localVolumesSortedByEmptyFirst) { volumeView in
                            if volumeView.isSelected {
                              GridRow(alignment: .lastTextBaseline) {
                                    Text(volumeView.volume.mountPath)
                                      .font(.system(size: viewModel.preferences.legendFontSize))
                                      .foregroundStyle(volumeView.lineColor)
                                    //.background(.red)

//                                    Spacer()
//                                      .frame(maxWidth: 5)
                                     
                                    Text(volumeView.chartFreeLineText)
                                      .font(.system(size: viewModel.preferences.legendFontSize))
                                      .foregroundStyle(volumeView.weightAdjustedColor)
                                      .blinking(if: volumeView.showLowSpaceWarning,
                                                  duration: 0.4)
                                      //.background(.blue)
//                                    Group {
                                        if volumeView.shouldShowChange {
                                            switch volumeView.direction {
                                            case .equal:
                                                HStack { Text("") }
//                                                  .background(.purple)
//                                                  .frame(minWidth: 120)
                                                  .frame(minWidth: 50)

                                            case .up:
                                                HStack(spacing: 0) {
                                                    Image(systemName: "arrow.up")
                                                      .resizable()
                                                      .aspectRatio(contentMode: .fit)
                                                      .foregroundColor(.green)
                                                      .frame(width: viewModel.preferences.legendFontSize*0.65,
                                                             height: viewModel.preferences.legendFontSize*0.65)
                                                    VStack(/*spacing: 0, */alignment: .leading) {
                                                        Text(volumeView.change)
                                                          .foregroundColor(.green)
                                                          .font(.system(size: viewModel.preferences.legendFontSize/2.5))
                                                        Text(volumeView.change2)
                                                          .foregroundColor(.green)
                                                          .font(.system(size: viewModel.preferences.legendFontSize/2.5))
                                                    }
                                                }
                                                  .animation(.easeInOut, value: volumeView.direction)
                                                  .frame(minWidth: 50)
                                                  //.background(.purple)
                                            case .down:
                                                HStack(spacing: 0) {
                                                    Image(systemName: "arrow.down")
                                                      .resizable()
                                                      .aspectRatio(contentMode: .fit)
                                                      .foregroundColor(.red)
                                                      .opacity(0.7)
                                                      .frame(width: viewModel.preferences.legendFontSize*0.65,
                                                             height: viewModel.preferences.legendFontSize*0.65)
                                                    VStack(/*spacing: 0, */alignment: .leading)  {
                                                        Text(volumeView.change)
                                                          .foregroundColor(.red)
                                                          .font(.system(size: viewModel.preferences.legendFontSize/2.5))
                                                        Text(volumeView.change2)
                                                          .foregroundColor(.red)
                                                          .font(.system(size: viewModel.preferences.legendFontSize/2.5))
                                                    }
                                                }
                                                  .animation(.easeInOut, value: volumeView.direction)
                                                //.animation(.easeInOut, value: volumeView.direction                                                  .frame(minWidth: 50))
                                                  //.background(.orange)
                                            }
                                        } else {
                                            HStack { Text("T") }
                                              .opacity(0)
                                              .frame(minWidth: 50)
                                              //.background(.purple)

                                        }
//                                    }
//                                      .frame(minWidth: 50)
                                      //.background(.yellow)
                                }
                                  .help(volumeView.helpText)
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

        Chart {
//            let lineWidth = 6
//            let dotSize = 24//lineWidth*4
            /*

             try exposing a list of volume view protocols from the view model,
             so we can both network and local volumes use the same view code,
             right now it's copied for each :(
             
             */
            ForEach(self.viewModel.localVolumes) { volumeView in
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
                                  Text(volumeView.volume.mountPath)
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
                                        .foregroundStyle(volumeView.weightAdjustedColor)
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
                        }
                    }
                }
            }

            // NETWORK STUFF HERE

            ForEach(self.viewModel.networkVolumes) { volumeView in
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
                                        .foregroundStyle(volumeView.weightAdjustedColor)
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
                        }
                    }
                }
            }
        }
          .chartXAxis {
              AxisMarks(preset: .aligned) // XXX doesn't help :(
          }
          .chartYScale(domain: viewModel.chartRange(showFree: viewModel.preferences.showFreeSpace,
                                                    showUsed: viewModel.preferences.showUsedSpace))
          .chartYAxisLabel("Gigabytes")
    }
}
