import SwiftUI

enum ChartType: String,
                Codable,
                Sendable,
                CaseIterable,
                Identifiable,
                CustomStringConvertible
{
    case combined
    case separate

    var id: Self { self }
    
    var description: String {
        switch self {
        case .combined:
            return "Combined"
        case .separate:
            return "Separate"
        }
    }
}

