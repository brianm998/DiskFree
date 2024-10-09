import SwiftUI
import Charts

// each row in the combind chart legend
struct CombinedChartLegendItemView: View {
    @Environment(ViewModel.self) var viewModel: ViewModel
    @State var volumeView: VolumeViewModel

    var volumeIcon: some View {
        if volumeView.isNetwork {
            Image(systemName: "server.rack")
              .resizable()
              .frame(width: viewModel.preferences.legendFontSize*0.6,
                     height: viewModel.preferences.legendFontSize*0.6)
              .opacity(0.6)
        } else if volumeView.isInternal {
            Image(systemName: "internaldrive")
              .resizable()
              .frame(width: viewModel.preferences.legendFontSize*0.6,
                     height: viewModel.preferences.legendFontSize*0.6)
              .opacity(0.6)
        } else {
            Image(systemName: "externaldrive")
              .resizable()
              .frame(width: viewModel.preferences.legendFontSize*0.6,
                     height: viewModel.preferences.legendFontSize*0.6)
              .opacity(0.6)
        }
    }
    
    var changeArrow: some View {
        Group {
            if volumeView.shouldShowChange {
                switch volumeView.direction {
                case .equal:
                    HStack { Text("") }
                      .frame(minWidth: 50)

                case .up:
                    Image(systemName: "arrow.up")
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .foregroundColor(.green)
                      .frame(width: viewModel.preferences.legendFontSize*0.65,
                             height: viewModel.preferences.legendFontSize*0.65)
                      .frame(minWidth: 50)
                case .down:
                    Image(systemName: "arrow.down")
                      .resizable()
                      .aspectRatio(contentMode: .fit)
                      .foregroundColor(.red)
                      .opacity(0.7)
                      .frame(width: viewModel.preferences.legendFontSize*0.65,
                             height: viewModel.preferences.legendFontSize*0.65)
                }
            } else {
                HStack { Text("") }
                  .frame(minWidth: viewModel.preferences.legendFontSize*0.65)
            }
        }
    }
    
    var volumeChange: some View {
        Group {
            if volumeView.shouldShowChange {
                switch volumeView.direction {
                case .equal:
                    HStack { Text("") }
                      .frame(minWidth: 50)
                    
                case .up:
                    VStack(alignment: .leading) {
                        Text(volumeView.change)
                          .foregroundColor(.green)
                          .font(.system(size: viewModel.preferences.legendFontSize/2.5))
                        Text(volumeView.change2)
                          .foregroundColor(.green)
                          .font(.system(size: viewModel.preferences.legendFontSize/2.5))
                    }
                    
                      .animation(.easeInOut, value: volumeView.direction)
                      .frame(minWidth: 50)
                case .down:
                    VStack(alignment: .leading)  {
                        Text(volumeView.change)
                          .foregroundColor(.red)
                          .font(.system(size: viewModel.preferences.legendFontSize/2.5))
                        Text(volumeView.change2)
                          .foregroundColor(.red)
                          .font(.system(size: viewModel.preferences.legendFontSize/2.5))
                    }
                      .animation(.easeInOut, value: volumeView.direction)
                }
            } else {
                HStack { Text("") }
                  .frame(minWidth: 30)
            }
        }
    }

    var percentFullVisual: some View {
        // XXX make a cool little graph here
        GeometryReader { geometry in
            if let amountFull = volumeView.amountFull,
               let amountEmpty = volumeView.amountEmpty
            {
                VStack(spacing: 0) {
                    Rectangle()
                      .fill(.green)
                      .frame(height: geometry.size.height*amountEmpty)
//                      .border(.blue)
                    Rectangle()
                      .fill(.red)
                      .frame(height: geometry.size.height*amountFull)
//                      .border(.blue)
                }
                  .border(.gray)
            } else {
                Text("?")
                  .foregroundColor(.yellow)
            }
        }
    }
    
    var body: some View {
        GridRow(alignment: .lastTextBaseline) {

            // icon for local / network
            self.volumeIcon

            // text for where volume is mounted
            Text(volumeView.volume.mountPath)
              .font(.system(size: viewModel.preferences.legendFontSize))
              .foregroundStyle(volumeView.lineColor)

            // text for free space available
            Text(volumeView.chartFreeLineText)
              .font(.system(size: viewModel.preferences.legendFontSize))
              .foregroundStyle(volumeView.weightAdjustedColor)
              .blinking(if: volumeView.showLowSpaceWarning,
                          duration: 0.4)



            // battery like visual of amount left
            self.percentFullVisual
              .frame(width: viewModel.preferences.legendFontSize/3,
                     height: viewModel.preferences.legendFontSize)
              .blinking(if: volumeView.showLowSpaceWarning,
                          duration: 0.4)

            if let amountEmpty = volumeView.amountEmpty {
                // text for free space available
                Text(String(format: "%d%%", Int(amountEmpty*100)))
                  .font(.system(size: viewModel.preferences.legendFontSize*0.8))
                       .foregroundStyle(volumeView.weightAdjustedColor)
                       .blinking(if: volumeView.showLowSpaceWarning,
                                   duration: 0.4)
            }
            
            
            // description of how much (if any) this volume has changed recently
            self.changeArrow
            self.volumeChange
        }
          .help(volumeView.helpText) // could be better
//        Spacer()

    }
}

struct CombinedChartLegendView: View {
    @Environment(ViewModel.self) var viewModel: ViewModel
    
    var body: some View {
        Group {
            if viewModel.allVolumes.count > 0 {
                VStack(alignment: .leading) {
                    ScrollView {
                        Text("Free Space")
                          .font(.system(size: viewModel.preferences.legendFontSize))
                        Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 0) {
                            ForEach(self.viewModel.allVolumes) { volumeView in
                                if volumeView.isSelected {
                                    CombinedChartLegendItemView(volumeView: volumeView)
                                }
                            }
                        }
                    }
                    Spacer()
                      .frame(height: 20)
                }
            }
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
