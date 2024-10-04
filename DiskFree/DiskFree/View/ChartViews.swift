import SwiftUI
import Charts

struct ChartViews: View {
    @Environment(ViewModel.self) var viewModel: ViewModel

    var body: some View {
        switch viewModel.preferences.chartType {
        case .combined:
            CombinedChartView()
        case .separate:
            MultiChartView()
        }
    }
}
