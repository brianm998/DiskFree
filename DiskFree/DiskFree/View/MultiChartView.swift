import SwiftUI
import Charts

struct MultiChartView: View {
    @Environment(ViewModel.self) var viewModel: ViewModel

    var body: some View {
         VStack {
            ScrollView {
                ForEach(viewModel.localVolumesSortedByEmptyFirst) { volumeView in
                    if volumeView.isSelected {
                        HStack {
                            MultiChartPlot(sizes: volumeView.chartSizes,
                                           showFree: viewModel.preferences.showFreeSpace,
                                           showUsed: viewModel.preferences.showUsedSpace)
                              .equatable()
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
}


// One volume's chart.  Plain inputs only, no viewModel.preferences reads.
struct MultiChartPlot: View, Equatable {
    let sizes: [VolumeViewModel.ChartPoint]
    let showFree: Bool
    let showUsed: Bool

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
        Chart {
            if showFree {
                AreaPlot(sizes,
                         x: .value("time", \.date),
                         y: .value("free", \.gigsFree),
                         series: .value("G", \.segment),
                         stacking: .unstacked)
                  .lineStyle(StrokeStyle(lineWidth: 2))
                  .foregroundStyle(greenGradientColor)
                  .interpolationMethod(.cardinal)
            }
            if showUsed {
                AreaPlot(sizes,
                         x: .value("time", \.date),
                         y: .value("used", \.gigsUsed),
                         series: .value("f", \.segment),
                         stacking: .unstacked)
                  .lineStyle(StrokeStyle(lineWidth: 2))
                  .foregroundStyle(redGradientColor)
                  .interpolationMethod(.cardinal)
            }
        }
    }
}
