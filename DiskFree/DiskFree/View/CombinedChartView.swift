import SwiftUI
import Charts

struct CombinedChartView: View {
    @Environment(ViewModel.self) var viewModel: ViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            CombinedChartPlot(showFree: viewModel.preferences.showFreeSpace,
                              showUsed: viewModel.preferences.showUsedSpace)
            CombinedChartLegendView()
        }
    }
}

// The chart itself.  Takes the two flags as plain inputs and never reads
// viewModel.preferences, so unrelated preference changes don't rebuild it.
struct CombinedChartPlot: View {
    @Environment(ViewModel.self) var viewModel: ViewModel
    let showFree: Bool
    let showUsed: Bool

    var body: some View {
        combinedChart
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
                if volumeView.isSelected && volumeView.isMounted {
                    let points = volumeView.chartSizes
                    let color = volumeView.lineColor
                    if showFree {
                        LinePlot(points,
                                 x: .value("time", \.date),
                                 y: .value("Gigabytes Free", \.gigsFree),
                                 series: .value("segment", \.segment))
                          .interpolationMethod(.catmullRom)
                          .foregroundStyle(color)
                          .lineStyle(StrokeStyle(lineWidth: 4,
                                                 lineCap: .round,
                                                 lineJoin: .round,
                                                 miterLimit: 0,
                                                 dash: [12],
                                                 dashPhase: 0))
                        if let first = points.first {
                            PointMark(x: .value("time", first.date),
                                      y: .value("Gigabytes Free", first.gigsFree))
                              .symbolSize(16)
                              .foregroundStyle(color)
                              .annotation(position: .leading, alignment: .bottom) {
                                  Text(volumeView.volume.mountPath)
                                    .font(.system(size: 22))
                                    .foregroundStyle(color)
                                    .frame(maxWidth: 50)
                              }
                        }
                        if let end = points.last {
                            if volumeView.isMostFull {
                                PointMark(x: .value("time", end.date),
                                          y: .value("Gigabytes Free", end.gigsFree))
                                  .symbolSize(16)
                                  .foregroundStyle(color)
                                  .annotation(position: .leading, alignment: .top) {
                                      Text(volumeView.volume.name)
                                        .font(.system(size: 22))
                                        .foregroundStyle(color)
                                  }
                            } else {
                                PointMark(x: .value("time", end.date),
                                          y: .value("Gigabytes Free", end.gigsFree))
                                  .symbolSize(16)
                                  .foregroundStyle(color)
                            }
                        }
                    }
                    if showUsed {
                        LinePlot(points,
                                 x: .value("time", \.date),
                                 y: .value("Gigabytes Used", \.gigsUsed),
                                 series: .value("segment", \.segment))
                          .interpolationMethod(.catmullRom)
                          .foregroundStyle(.red)
                    }
                }
            }
        }
          .chartXAxis {
              AxisMarks(preset: .aligned) // XXX doesn't help :(
          }
          .chartYScale(domain: viewModel.chartRange(showFree: showFree,
                                                    showUsed: showUsed))
          .chartYAxisLabel("Gigabytes")
    }
}
