//
//  MasonryLayout.swift
//  CardOnCue
//
//  A simple staggered (Pinterest-style) masonry Layout: each subview is placed
//  into whichever column is currently shortest, using the subview's measured
//  height. Column count is derived from the available width.
//

import SwiftUI

/// ponytail: Layout renders all cells eagerly — fine for tens of cards (a
/// personal loyalty wallet). If libraries grow to hundreds, switch to two
/// LazyVStacks with a greedy height-estimated column split.
struct MasonryLayout: Layout {
    var minColumnWidth: CGFloat = 168
    var spacing: CGFloat = 12

    private func columnCount(for width: CGFloat) -> Int {
        guard width > 0 else { return 2 }
        // n columns fit when n*minColumnWidth + (n-1)*spacing <= width.
        let n = Int((width + spacing) / (minColumnWidth + spacing))
        return max(2, n)
    }

    private func columnWidth(for width: CGFloat, columns: Int) -> CGFloat {
        (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    private func shortestColumn(_ heights: [CGFloat]) -> Int {
        heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let columns = columnCount(for: width)
        let colWidth = columnWidth(for: width, columns: columns)
        var heights = Array(repeating: CGFloat(0), count: columns)

        for subview in subviews {
            let h = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil)).height
            let col = shortestColumn(heights)
            heights[col] += h + spacing
        }

        // Drop the trailing spacing that was added past the last cell in each column.
        let tallest = heights.map { max(0, $0 - spacing) }.max() ?? 0
        return CGSize(width: width, height: tallest)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let columns = columnCount(for: bounds.width)
        let colWidth = columnWidth(for: bounds.width, columns: columns)
        var heights = Array(repeating: CGFloat(0), count: columns)

        for subview in subviews {
            let h = subview.sizeThatFits(ProposedViewSize(width: colWidth, height: nil)).height
            let col = shortestColumn(heights)
            let x = bounds.minX + CGFloat(col) * (colWidth + spacing)
            let y = bounds.minY + heights[col]
            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: colWidth, height: h)
            )
            heights[col] += h + spacing
        }
    }
}
