import SwiftUI
import MapKit
import CoreLocation
import SwiftData

/// Reusable location search component with autocomplete functionality
struct LocationSearchField: View {
    @Binding var locationName: String
    var latitude: Binding<Double?>? = nil
    var longitude: Binding<Double?>? = nil
    var address: Binding<String?>? = nil
    var phoneNumber: Binding<String?>? = nil
    var website: Binding<String?>? = nil
    var email: Binding<String?>? = nil

    var userLocation: CLLocation? = nil
    var placeholder: String = "Search for a location"
    var isAutoPopulated: Bool = false
    var modelContext: ModelContext? = nil

    // Internal bindings with defaults
    private var latitudeBinding: Binding<Double?> {
        latitude ?? .constant(nil)
    }

    private var longitudeBinding: Binding<Double?> {
        longitude ?? .constant(nil)
    }

    private var addressBinding: Binding<String?> {
        address ?? .constant(nil)
    }

    private var phoneNumberBinding: Binding<String?> {
        phoneNumber ?? .constant(nil)
    }

    private var websiteBinding: Binding<String?> {
        website ?? .constant(nil)
    }

    private var emailBinding: Binding<String?> {
        email ?? .constant(nil)
    }

    @StateObject private var locationSearchService = LocationSearchService()
    @FocusState private var isFocused: Bool
    @State private var showingSuggestions: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Text field
            TextField(placeholder, text: $locationName)
                .textFieldStyle(
                    LocationTextFieldStyle(
                        isAutoPopulated: isAutoPopulated,
                        isFocused: isFocused
                    )
                )
                .autocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isFocused)
                .onChange(of: locationName) { oldValue, newValue in
                    locationSearchService.searchQuery = newValue
                    showingSuggestions = !newValue.isEmpty && isFocused
                }
                .onChange(of: isFocused) { oldValue, newValue in
                    if newValue && !locationName.isEmpty {
                        showingSuggestions = true
                    } else {
                        showingSuggestions = false
                    }
                }

            // Suggestions dropdown
            if showingSuggestions && (!locationSearchService.cachedSuggestions.isEmpty || !locationSearchService.suggestions.isEmpty) {
                VStack(spacing: 0) {
                    // Cached locations section
                    if !locationSearchService.cachedSuggestions.isEmpty {
                        // Section header
                        Text("Recent Locations")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(locationSearchService.cachedSuggestions, id: \.id) { location in
                            Button(action: {
                                selectCachedLocation(location)
                            }) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.green)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(location.displayName)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        if let address = location.address, !address.isEmpty {
                                            Text(address)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        } else if location.coordinate != nil {
                                            if let distance = location.distance(from: userLocation?.coordinate) {
                                                Text(String(format: "%.1f km away", distance / 1000))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if location != locationSearchService.cachedSuggestions.last {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }

                        // Divider between sections if both exist
                        if !locationSearchService.suggestions.isEmpty {
                            Divider()
                                .padding(.vertical, 8)
                        }
                    }

                    // MapKit search results section
                    if !locationSearchService.suggestions.isEmpty {
                        // Section header (only if cached results also exist)
                        if !locationSearchService.cachedSuggestions.isEmpty {
                            Text("Search Results")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 4)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ForEach(locationSearchService.suggestions.prefix(5), id: \.self) { suggestion in
                            Button(action: {
                                selectSuggestion(suggestion)
                            }) {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.appBlue)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)

                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if suggestion != locationSearchService.suggestions.prefix(5).last {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 8, y: 4)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingSuggestions)
        .onAppear {
            // Configure location search service with model context and user location
            locationSearchService.modelContext = modelContext
            locationSearchService.userLocation = userLocation?.coordinate
        }
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        locationName = locationSearchService.selectLocation(suggestion)
        showingSuggestions = false
        isFocused = false

        // Wait briefly for location details to be fetched, then update bindings
        // The MKLocalSearch call is asynchronous, so we observe the published properties
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let coordinate = locationSearchService.selectedCoordinate {
                latitudeBinding.wrappedValue = coordinate.latitude
                longitudeBinding.wrappedValue = coordinate.longitude
            }
            addressBinding.wrappedValue = locationSearchService.selectedAddress
            phoneNumberBinding.wrappedValue = locationSearchService.selectedPhoneNumber
            websiteBinding.wrappedValue = locationSearchService.selectedWebsite
            emailBinding.wrappedValue = locationSearchService.selectedEmail
        }
    }

    private func selectCachedLocation(_ location: SavedLocation) {
        locationName = locationSearchService.selectCachedLocation(location)
        showingSuggestions = false
        isFocused = false

        // Update bindings immediately (cached locations have all data already)
        if let coordinate = locationSearchService.selectedCoordinate {
            latitudeBinding.wrappedValue = coordinate.latitude
            longitudeBinding.wrappedValue = coordinate.longitude
        }
        addressBinding.wrappedValue = locationSearchService.selectedAddress
        phoneNumberBinding.wrappedValue = locationSearchService.selectedPhoneNumber
        websiteBinding.wrappedValue = locationSearchService.selectedWebsite
        emailBinding.wrappedValue = locationSearchService.selectedEmail
    }
}

/// Custom text field style for location search
private struct LocationTextFieldStyle: TextFieldStyle {
    let isAutoPopulated: Bool
    let isFocused: Bool

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                isAutoPopulated && !isFocused
                    ? Color.appBlue.opacity(0.05)
                    : Color.white
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isFocused
                            ? Color.appBlue.opacity(0.5)
                            : (isAutoPopulated ? Color.appBlue.opacity(0.3) : Color.clear),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .cornerRadius(12)
            .appLightTextFieldContent()
    }
}

#Preview {
    VStack(spacing: 20) {
        FormSection(title: "Location", icon: "location.fill") {
            LocationSearchField(
                locationName: .constant(""),
                placeholder: "Search for a location"
            )
        }

        FormSection(title: "Location (Auto-populated)", icon: "location.fill") {
            LocationSearchField(
                locationName: .constant("Costco Wholesale"),
                isAutoPopulated: true
            )
        }
    }
    .padding()
    .background(Color.appBackground)
}
