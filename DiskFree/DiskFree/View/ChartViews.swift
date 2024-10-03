import SwiftUI
import Charts

struct ChartViews: View {
    @State var viewModel: ViewModel

    var body: some View {
        switch viewModel.preferences.chartType {
        case .combined:
            CombinedChartView(viewModel: viewModel)
        case .separate:
            MultiChartView(viewModel: viewModel)
        }
    }
}
