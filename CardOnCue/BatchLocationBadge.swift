import SwiftUI

/// Badge displayed during batch scanning showing the selected location
struct BatchLocationBadge: View {

    // MARK: - Properties

    let locationName: String
    let cardCount: Int
    let onChangeLocation: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 8) {
            // Location icon
            Image(systemName: "mappin.circle.fill")
                .font(.subheadline)
                .foregroundColor(.blue)

            // Location name
            Text(locationName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)

            // Card count
            if cardCount > 0 {
                Text("(\(cardCount) card\(cardCount == 1 ? "" : "s"))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Edit button
            Button(action: onChangeLocation) {
                Image(systemName: "pencil.circle")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview

#Preview("With Cards") {
    ZStack {
        Color.black
        VStack {
            BatchLocationBadge(
                locationName: "Chuck E. Cheese",
                cardCount: 3,
                onChangeLocation: { print("Change location") }
            )
        }
    }
}

#Preview("No Cards Yet") {
    ZStack {
        Color.black
        VStack {
            BatchLocationBadge(
                locationName: "Louisville Public Library",
                cardCount: 0,
                onChangeLocation: { print("Change location") }
            )
        }
    }
}

#Preview("Long Name") {
    ZStack {
        Color.black
        VStack {
            BatchLocationBadge(
                locationName: "Denver Museum of Nature & Science",
                cardCount: 5,
                onChangeLocation: { print("Change location") }
            )
            .frame(maxWidth: 300)
        }
    }
}
