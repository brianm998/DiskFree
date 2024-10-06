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
            if viewModel.volumes.count > 0 {
                VStack(alignment: .leading) {
                    Text("Free Space")
                      .font(.system(size: viewModel.preferences.legendFontSize))
                    Grid(alignment: .leading) {
                        ForEach(self.viewModel.volumesSortedByEmptyFirst) { volumeView in
                            if volumeView.isSelected {
                                GridRow {
                                    Text(volumeView.volume.userVisibleMountPoint)
                                      .font(.system(size: viewModel.preferences.legendFontSize))
                                      .foregroundStyle(volumeView.lineColor)
                                    Text(volumeView.chartFreeLineText)
                                      .font(.system(size: viewModel.preferences.legendFontSize))
                                      .foregroundStyle(volumeView.weightAdjustedColor)
                                      .blinking(if: volumeView.showLowSpaceWarning,
                                                  duration: 0.4)

                                    switch volumeView.direction {
                                    case .equal:
                                        Group { }

                                    case .up:
                                        Image(systemName: "arrow.up")
                                          .resizable()
                                          .aspectRatio(contentMode: .fit)
                                          .foregroundColor(.green)
                                          .frame(width: viewModel.preferences.legendFontSize*0.66,
                                                 height: viewModel.preferences.legendFontSize*0.66)
                                    case .down:
                                        Image(systemName: "arrow.down")
                                          .resizable()
                                          .aspectRatio(contentMode: .fit)
                                          .foregroundColor(.red)
                                          .frame(width: viewModel.preferences.legendFontSize*0.66,
                                                 height: viewModel.preferences.legendFontSize*0.66)
                                    }
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
          ForEach(self.viewModel.volumes) { volumeView in
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
                                  Text(volumeView.volume.userVisibleMountPoint)
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

          .chartYScale(domain: viewModel.chartRange(showFree: viewModel.preferences.showFreeSpace,
                                                    showUsed: viewModel.preferences.showUsedSpace))
          .chartYAxisLabel("Gigabytes")
    }
}
