import SwiftUI

// MARK: - Add Card Flow Environment

private struct IsInAddCardFlowKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isInAddCardFlow: Bool {
        get { self[IsInAddCardFlowKey.self] }
        set { self[IsInAddCardFlowKey.self] = newValue }
    }
}

// MARK: - Shared Header Metrics

enum AddCardFlowMetrics {
    static let navigationRowHeight: CGFloat = 44
    static let segmentRowHeight: CGFloat = 36
    static let modeSelectorRowHeight: CGFloat = 52
    static let rowSpacing: CGFloat = 8

    static let lastTabUserDefaultsKey = "lastAddCardTabIndex"

    static func headerHeight(hasModeSelector: Bool) -> CGFloat {
        var height = navigationRowHeight + rowSpacing + segmentRowHeight
        if hasModeSelector {
            height += rowSpacing + modeSelectorRowHeight
        }
        return height
    }
}
