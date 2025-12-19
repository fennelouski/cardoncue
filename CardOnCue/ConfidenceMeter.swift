import SwiftUI

/// Live confidence indicator shown during scanning in rapid/batch mode
struct ConfidenceMeter: View {

    // MARK: - Properties

    let confidence: Float
    let autoSaveThreshold: Float

    // MARK: - Computed Properties

    /// Color based on confidence level
    private var color: Color {
        if confidence >= autoSaveThreshold {
            return .green
        } else if confidence >= 0.70 {
            return .yellow
        } else {
            return .red
        }
    }

    /// Status text
    private var statusText: String {
        if confidence >= autoSaveThreshold {
            return "Ready"
        } else if confidence >= 0.70 {
            return "Review"
        } else {
            return "Low"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 6) {
            // Progress bar
            ProgressView(value: Double(confidence))
                .tint(color)
                .frame(width: 70)

            // Percentage text
            HStack(spacing: 4) {
                Text("\(Int(confidence * 100))%")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(color)

                // Status indicator
                Text(statusText)
                    .font(.system(size: 9))
                    .foregroundColor(color.opacity(0.8))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview("High Confidence") {
    ZStack {
        Color.black
        ConfidenceMeter(confidence: 0.92, autoSaveThreshold: 0.85)
    }
}

#Preview("Medium Confidence") {
    ZStack {
        Color.black
        ConfidenceMeter(confidence: 0.75, autoSaveThreshold: 0.85)
    }
}

#Preview("Low Confidence") {
    ZStack {
        Color.black
        ConfidenceMeter(confidence: 0.45, autoSaveThreshold: 0.85)
    }
}
