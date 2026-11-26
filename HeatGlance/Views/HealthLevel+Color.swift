import SwiftUI

import HeatGlanceCore

extension HealthLevel {
    var color: Color {
        switch self {
        case .normal:
            return .green
        case .elevated:
            return .orange
        case .critical:
            return .red
        }
    }
}
