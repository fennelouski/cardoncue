import Foundation
import MapKit
import Combine
import SwiftData
import CoreLocation

class LocationSearchService: NSObject, ObservableObject {
    @Published var searchQuery = ""
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var cachedSuggestions: [SavedLocation] = []
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    @Published var selectedAddress: String?
    @Published var selectedPhoneNumber: String?
    @Published var selectedWebsite: String?
    @Published var selectedEmail: String?
    @Published var selectedCachedLocation: SavedLocation?  // Track when a cached location is selected
    @Published var isLoadingDetails = false

    private let completer: MKLocalSearchCompleter
    private var cancellables = Set<AnyCancellable>()
    var modelContext: ModelContext?
    var userLocation: CLLocationCoordinate2D?

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()

        completer.delegate = self
        completer.resultTypes = [.pointOfInterest, .address]

        // Debounce search query updates
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                if query.isEmpty {
                    self?.suggestions = []
                    self?.cachedSuggestions = []
                } else {
                    // Fetch cached locations
                    self?.fetchCachedLocations(for: query)

                    // Fetch MapKit suggestions
                    self?.completer.queryFragment = query
                }
            }
            .store(in: &cancellables)
    }

    func selectLocation(_ completion: MKLocalSearchCompletion) -> String {
        // Clear cached location since this is a new search result
        selectedCachedLocation = nil

        // Return the full location name
        let title = completion.title
        let subtitle = completion.subtitle

        let fullName = subtitle.isEmpty ? title : "\(title), \(subtitle)"

        // Perform MKLocalSearch to get full details including coordinates
        fetchLocationDetails(for: completion)

        return fullName
    }

    /// Fetch full location details including coordinates
    private func fetchLocationDetails(for completion: MKLocalSearchCompletion) {
        isLoadingDetails = true

        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)

        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isLoadingDetails = false

                guard let response = response, error == nil else {
                    print("Error fetching location details: \(error?.localizedDescription ?? "Unknown")")
                    return
                }

                // Get the first result (usually the most relevant)
                if let mapItem = response.mapItems.first {
                    self?.selectedCoordinate = mapItem.placemark.coordinate

                    // Build full address string
                    var addressComponents: [String] = []
                    if let thoroughfare = mapItem.placemark.thoroughfare {
                        addressComponents.append(thoroughfare)
                    }
                    if let locality = mapItem.placemark.locality {
                        addressComponents.append(locality)
                    }
                    if let administrativeArea = mapItem.placemark.administrativeArea {
                        addressComponents.append(administrativeArea)
                    }
                    if let postalCode = mapItem.placemark.postalCode {
                        addressComponents.append(postalCode)
                    }

                    self?.selectedAddress = addressComponents.joined(separator: ", ")

                    // Extract business metadata from MKMapItem
                    self?.selectedPhoneNumber = mapItem.phoneNumber
                    self?.selectedWebsite = mapItem.url?.absoluteString
                    // Email is not directly available from MKMapItem
                    self?.selectedEmail = nil
                }
            }
        }
    }

    /// Fetch cached locations matching the search query
    private func fetchCachedLocations(for query: String) {
        guard let modelContext = modelContext else {
            cachedSuggestions = []
            return
        }

        let matches = LocationCacheService.shared.findMatches(
            for: query,
            address: nil,
            userLocation: userLocation,
            context: modelContext
        )

        // Limit to top 3 cached results to avoid overwhelming the UI
        cachedSuggestions = Array(matches.prefix(3))
    }

    /// Select a cached location
    func selectCachedLocation(_ location: SavedLocation) -> String {
        // Store the selected cached location for icon reuse
        selectedCachedLocation = location

        // Update coordinates and address immediately
        selectedCoordinate = location.coordinate
        selectedAddress = location.address

        // Update business metadata
        selectedPhoneNumber = location.phoneNumber
        selectedWebsite = location.website
        selectedEmail = location.email

        // Update usage statistics
        if let modelContext = modelContext {
            LocationCacheService.shared.updateUsage(for: location, context: modelContext)
        }

        return location.displayName
    }
}

extension LocationSearchService: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Location search error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.suggestions = []
        }
    }
}
