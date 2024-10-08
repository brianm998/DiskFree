import SwiftUI
import Charts

struct CombinedChartView: View {
    @Environment(ViewModel.self) var viewModel: ViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            combinedChart
            CombinedChartLegendView()
        }
    }

    func gradient(with color: Color) -> LinearGradient {
        LinearGradient(gradient: Gradient(colors: [color.opacity(0.3),
                                                   color.opacity(0.002)]),
                       startPoint: UnitPoint(x: 0, y: 0),
                       endPoint: UnitPoint(x: 0, y: 0.8))
    }

    var combinedChart: some View {

        Chart {
//            let lineWidth = 6
//            let dotSize = 24//lineWidth*4
            ForEach(self.viewModel.allVolumes) { volumeView in
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
        }
          .chartXAxis {
              AxisMarks(preset: .aligned) // XXX doesn't help :(
          }
          .chartYScale(domain: viewModel.chartRange(showFree: viewModel.preferences.showFreeSpace,
                                                    showUsed: viewModel.preferences.showUsedSpace))
          .chartYAxisLabel("Gigabytes")
    }
}
