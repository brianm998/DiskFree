import SwiftUI
import Charts

struct ChartViews: View {
    @State var viewModel: ViewModel

    var body: some View {
        if viewModel.preferences.showMultipleCharts {
            MultiChartView(viewModel: viewModel)
        } else {
            CombinedChartView(viewModel: viewModel)
        }
    }
}
