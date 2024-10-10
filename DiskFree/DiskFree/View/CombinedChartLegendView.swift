import SwiftUI
import Charts

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

