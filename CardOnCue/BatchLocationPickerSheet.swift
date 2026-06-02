import SwiftUI
import SwiftData
import MapKit

/// Sheet for selecting a location before batch scanning
struct BatchLocationPickerSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Bindings

    @Binding var selectedLocation: BatchLocationContext?

    // MARK: - State

    @StateObject private var searchService = LocationSearchService()
    @State private var recentLocations: [SavedLocation] = []
    @State private var isLoadingRecent = true

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Search field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Search for a location")
                            .font(.headline)
                            .foregroundColor(.primary)

                        TextField("Business name or address", text: $searchService.searchQuery)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Search results (MapKit)
                    if !searchService.suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Search Results")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.bottom, 8)

                            ForEach(searchService.suggestions, id: \.self) { suggestion in
                                LocationRow(
                                    title: suggestion.title,
                                    subtitle: suggestion.subtitle,
                                    icon: "magnifyingglass",
                                    iconColor: .blue
                                ) {
                                    selectMapKitLocation(suggestion)
                                }
                            }
                        }
                    }

                    // Cached search results
                    if !searchService.cachedSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Recent Matches")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.bottom, 8)

                            ForEach(searchService.cachedSuggestions) { location in
                                CachedLocationRow(
                                    location: location
                                ) {
                                    selectCachedLocation(location)
                                }
                            }
                        }
                    }

                    // Recent locations (when not searching)
                    if searchService.searchQuery.isEmpty && !recentLocations.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text("Recent Locations")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("Tap to select")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)

                            ForEach(recentLocations.prefix(10)) { location in
                                CachedLocationRow(
                                    location: location
                                ) {
                                    selectCachedLocation(location)
                                }
                            }
                        }
                    }

                    // Empty state
                    if searchService.searchQuery.isEmpty && recentLocations.isEmpty && !isLoadingRecent {
                        VStack(spacing: 12) {
                            Image(systemName: "mappin.circle")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)

                            Text("No recent locations")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text("Search for a location to begin batch scanning")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                searchService.modelContext = modelContext
                loadRecentLocations()
            }
        }
    }

    // MARK: - Methods

    /// Load recent locations from SwiftData
    private func loadRecentLocations() {
        let descriptor = FetchDescriptor<SavedLocation>(
            sortBy: [
                SortDescriptor(\.lastUsedDate, order: .reverse)
            ]
        )

        do {
            recentLocations = try modelContext.fetch(descriptor)
            isLoadingRecent = false
        } catch {
            print("Error loading recent locations: \(error)")
            recentLocations = []
            isLoadingRecent = false
        }
    }

    /// Select a location from MapKit search results
    private func selectMapKitLocation(_ suggestion: MKLocalSearchCompletion) {
        let locationName = searchService.selectLocation(suggestion)

        // Wait for details to load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            selectedLocation = BatchLocationContext(
                locationName: locationName,
                latitude: searchService.selectedCoordinate?.latitude,
                longitude: searchService.selectedCoordinate?.longitude,
                address: searchService.selectedAddress,
                icon: nil,  // Will be fetched later
                phoneNumber: searchService.selectedPhoneNumber,
                website: searchService.selectedWebsite,
                email: searchService.selectedEmail
            )

            dismiss()
        }
    }

    /// Select a cached location
    private func selectCachedLocation(_ location: SavedLocation) {
        selectedLocation = BatchLocationContext.from(location)

        // Update usage stats
        location.lastUsedDate = Date()
        location.usageCount += 1
        PersistenceHelper.save(modelContext, label: "BatchLocationPickerSheet")

        dismiss()
    }
}

// MARK: - Location Row

/// Row for displaying MapKit search results
struct LocationRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cached Location Row

/// Row for displaying cached/recent locations
struct CachedLocationRow: View {
    let location: SavedLocation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon
                if let icon = location.cardIcon {
                    CardIconView(icon: icon, size: 30)
                } else {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .frame(width: 30)
                }

                // Location info
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        if let address = location.address {
                            Text(address)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        if location.usageCount > 1 {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("\(location.usageCount) cards")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Icon View Helper

/// Helper view to display CardIcon
struct CardIconView: View {
    let icon: CardIcon
    let size: CGFloat

    var body: some View {
        Group {
            switch icon.type {
            case .sfSymbol:
                Image(systemName: icon.value)
                    .font(.system(size: size * 0.6))
                    .foregroundColor(icon.colorHex.flatMap { Color.fromHex($0) } ?? .blue)

            case .emoji:
                Text(icon.value)
                    .font(.system(size: size * 0.7))

            case .image, .drawing:
                if let image = loadImage(from: icon.value) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                }

            case .text:
                Text(icon.value.prefix(2))
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundColor(.white)

            case .automatic:
                Image(systemName: "creditcard.fill")
                    .font(.system(size: size * 0.6))
                    .foregroundColor(.blue)
            }
        }
        .frame(width: size, height: size)
    }

    private func loadImage(from path: String) -> UIImage? {
        // Load from documents directory
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(path)

        if fileManager.fileExists(atPath: fileURL.path) {
            return UIImage(contentsOfFile: fileURL.path)
        }
        return nil
    }
}

// MARK: - Preview

#Preview {
    BatchLocationPickerSheet(selectedLocation: .constant(nil))
        .modelContainer(for: SavedLocation.self, inMemory: true)
}
