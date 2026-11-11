import Testing
import Foundation
@testable import DiskFree

struct LegendLayoutTests {
    @Test func arrowSizeScalesWithFont() {
        #expect(CombinedChartLegendItemView.arrowSize(fontSize: 20) == 13)
        #expect(CombinedChartLegendItemView.arrowSize(fontSize: 40) == 26)
    }

    @Test func rateFontIsFraction() {
        #expect(CombinedChartLegendItemView.rateFontSize(fontSize: 20) == 8)
    }

    @Test func rateColumnWidthFixedAndScales() {
        let w1 = CombinedChartLegendItemView.rateColumnWidth(fontSize: 20)
        let w2 = CombinedChartLegendItemView.rateColumnWidth(fontSize: 40)
        #expect(w1 == 40)
        #expect(w2 == 2 * w1)
        #expect(w1 == CombinedChartLegendItemView.rateColumnWidth(fontSize: 20))
    }
}
