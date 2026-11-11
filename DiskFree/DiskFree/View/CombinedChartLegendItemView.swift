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
    
    // size helpers: independent of direction / shouldShowChange so the
    // legend grid columns never resize
    static func arrowSize(fontSize: Double) -> Double {
        fontSize * 0.65
    }

    static func rateFontSize(fontSize: Double) -> Double {
        fontSize / 2.5
    }

    // wide enough for four digits plus "mb/s" at the rate font size
    static func rateColumnWidth(fontSize: Double) -> Double {
        rateFontSize(fontSize: fontSize) * 5.0
    }

    var changeColor: Color {
        volumeView.direction == .down ? .red : .green
    }

    var showsChange: Bool {
        volumeView.shouldShowChange && volumeView.direction != .equal
    }

    var changeArrow: some View {
        let size = Self.arrowSize(fontSize: viewModel.preferences.legendFontSize)
        return Image(systemName: volumeView.direction == .down ? "arrow.down" : "arrow.up")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .foregroundColor(changeColor)
          .opacity(showsChange ? (volumeView.direction == .down ? 0.7 : 1) : 0)
          .frame(width: size, height: size)
    }

    var volumeChange: some View {
        let fs = viewModel.preferences.legendFontSize
        let font = Font.system(size: Self.rateFontSize(fontSize: fs)).monospacedDigit()
        return VStack(alignment: .leading) {
            Text(showsChange ? volumeView.change : "0000")
              .font(font)
            Text(showsChange ? volumeView.change2 : "mb/s")
              .font(font)
        }
          .foregroundColor(changeColor)
          .opacity(showsChange ? 1 : 0)
          .frame(width: Self.rateColumnWidth(fontSize: fs), alignment: .leading)
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
