import SwiftUI
import SwiftData
import CoreLocation

/// View that displays all locations for a brand/network where the card is accepted
struct CardLocationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.apiClient) private var apiClient
    @Environment(\.modelContext) private var modelContext

    let card: CardModel
    let networkId: String
    let networkName: String

    @State private var locations: [NetworkLocationWithDistance] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var userLocation: CLLocation?
    @State private var selectedLocationId: String?

    private let locationManager = CLLocationManager()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Finding locations...")
                            .font(.subheadline)
                            .foregroundColor(.appLightGray)
                    }
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text("Error Loading Locations")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.appLightGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button("Try Again") {
                            fetchLocations()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.appBlue)
                    }
                } else if locations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.appLightGray)
                        Text("No Locations Found")
                            .font(.headline)
                        Text("We couldn't find any \(networkName) locations nearby.")
                            .font(.subheadline)
                            .foregroundColor(.appLightGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            // Header
                            VStack(spacing: 8) {
                                Text("\(networkName) Locations")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.appBlue)

                                Text("\(locations.count) location\(locations.count == 1 ? "" : "s") found")
                                    .font(.subheadline)
                                    .foregroundColor(.appLightGray)
                            }
                            .padding(.top, 16)
                            .padding(.bottom, 8)

                            // Locations list
                            ForEach(locations) { location in
                                LocationRow(
                                    location: location,
                                    isSelected: selectedLocationId == location.id,
                                    isPrimary: card.locationLatitude == location.lat && card.locationLongitude == location.lon
                                ) {
                                    selectLocation(location)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appBlue)
                }
            }
            .onAppear {
                getUserLocation()
                fetchLocations()
            }
        }
    }

    private func getUserLocation() {
        if let location = locationManager.location {
            userLocation = location
        }
    }

    private func fetchLocations() {
        guard let apiClient = apiClient else {
            errorMessage = "API client not available"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                let near: (lat: Double, lon: Double)? = userLocation.map { (lat: $0.coordinate.latitude, lon: $0.coordinate.longitude) }

                let response = try await apiClient.getNetworkLocations(
                    networkId: networkId,
                    near: near,
                    limit: 100
                )

                await MainActor.run {
                    // Convert to locations with distance
                    locations = response.locations.map { location in
                        let distance = userLocation?.distance(from: CLLocation(
                            latitude: location.lat,
                            longitude: location.lon
                        ))

                        return NetworkLocationWithDistance(
                            id: location.id,
                            name: location.name,
                            lat: location.lat,
                            lon: location.lon,
                            radiusMeters: location.radiusMeters,
                            notes: location.notes,
                            distance: distance
                        )
                    }

                    // Sort by distance
                    locations.sort { ($0.distance ?? Double.infinity) < ($1.distance ?? Double.infinity) }

                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func selectLocation(_ location: NetworkLocationWithDistance) {
        selectedLocationId = location.id

        // Update card with selected location
        card.locationName = location.name
        card.locationLatitude = location.lat
        card.locationLongitude = location.lon
        card.locationRadius = location.radiusMeters

        if let address = location.notes {
            card.setMetadata(address, for: "locationAddress")
        }

        // Save changes
        try? modelContext.save()

        // Show confirmation
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        print("✅ Set primary location: \(location.name)")
    }
}

// MARK: - Location Row

struct LocationRow: View {
    let location: NetworkLocationWithDistance
    let isSelected: Bool
    let isPrimary: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(isPrimary ? Color.appGreen : Color.appBlue.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: isPrimary ? "star.fill" : "mappin.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isPrimary ? .white : .appBlue)
                }

                // Location info
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if let notes = location.notes {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.appLightGray)
                            .lineLimit(2)
                    }

                    // Distance badge
                    if let distance = location.distance {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text(formatDistance(distance))
                                .font(.caption)
                        }
                        .foregroundColor(.appBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appBlue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                Spacer()

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.appGreen)
                }
            }
            .padding(12)
            .background(isPrimary ? Color.appGreen.opacity(0.05) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isPrimary ? Color.appGreen : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m away"
        } else {
            let km = meters / 1000
            return String(format: "%.1fkm away", km)
        }
    }
}

// MARK: - Supporting Models

struct NetworkLocationWithDistance: Identifiable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let radiusMeters: Double
    let notes: String?
    let distance: Double?
}
