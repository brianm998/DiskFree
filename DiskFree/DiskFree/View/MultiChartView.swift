import SwiftUI
import Charts

struct MultiChartView: View {
    @Environment(ViewModel.self) var viewModel: ViewModel

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
         VStack {
            ScrollView {
                ForEach(viewModel.volumesSortedByEmptyFirst) { volumeView in
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

