import SwiftUI
import MapKit
import CoreLocation
import SwiftData

/// A pin the user has dropped/searched this session but not yet saved.
private struct PendingPin: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Interactive map for adding many card locations in one session. Tap the map to
/// drop a pin (reverse-geocoded for a name) or search for a named place. "Save all"
/// writes every pin to `card.locations`, which feeds GeofenceManager automatically.
struct AddLocationsOnMapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.apiClient) private var apiClient

    let card: CardModel

    private let keychainService = KeychainService()

    @StateObject private var search = LocationSearchService()
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var pending: [PendingPin] = []
    @State private var searchText: String = ""
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                mapLayer
                searchOverlay
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationTitle("Add Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { search.modelContext = modelContext }
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        MapReader { proxy in
            Map(position: $camera) {
                UserAnnotation()
                ForEach(pending) { pin in
                    Marker(pin.name, systemImage: "mappin", coordinate: pin.coordinate)
                        .tint(Color.appBlue)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .onTapGesture { screenPoint in
                if let coord = proxy.convert(screenPoint, from: .local) {
                    dropPin(at: coord)
                    searchFocused = false
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Search

    private var searchOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search a place…", text: $searchText)
                    .autocorrectionDisabled()
                    .focused($searchFocused)
                    .onChange(of: searchText) { _, newValue in
                        search.searchQuery = newValue
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        search.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(.regularMaterial)
            .cornerRadius(12)

            if searchFocused && !search.suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(search.suggestions.prefix(6)), id: \.self) { suggestion in
                        Button {
                            selectSuggestion(suggestion)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.appBlue)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(.primary).lineLimit(1)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(.caption).foregroundColor(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 44)
                    }
                }
                .background(.regularMaterial)
                .cornerRadius(12)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if !pending.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(pending) { pin in
                            Button {
                                pending.removeAll { $0.id == pin.id }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(pin.name).lineLimit(1)
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .font(.caption)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.appBlue.opacity(0.12))
                                .foregroundColor(.appBlue)
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            HStack {
                Text("\(pending.count) added")
                    .font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Button {
                    saveAll()
                } label: {
                    Text("Save all")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(pending.isEmpty ? Color.gray : Color.appBlue)
                        .cornerRadius(10)
                }
                .disabled(pending.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func dropPin(at coord: CLLocationCoordinate2D) {
        let pin = PendingPin(name: "Dropped Pin", address: nil,
                             latitude: coord.latitude, longitude: coord.longitude)
        pending.append(pin)
        // Reverse-geocode for a friendlier name (native, no dependency).
        CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        ) { placemarks, _ in
            guard let mark = placemarks?.first else { return }
            let name = mark.name ?? mark.thoroughfare ?? "Dropped Pin"
            let address = [mark.thoroughfare, mark.locality, mark.administrativeArea]
                .compactMap { $0 }.joined(separator: ", ")
            DispatchQueue.main.async {
                if let idx = pending.firstIndex(where: { $0.id == pin.id }) {
                    pending[idx].name = name
                    pending[idx].address = address.isEmpty ? nil : address
                }
            }
        }
    }

    private func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        let name = search.selectLocation(suggestion)
        searchText = ""
        search.searchQuery = ""
        searchFocused = false
        // MKLocalSearch resolves coordinates asynchronously; mirror LocationSearchField's delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let coord = search.selectedCoordinate else { return }
            pending.append(PendingPin(name: name, address: search.selectedAddress,
                                      latitude: coord.latitude, longitude: coord.longitude))
            camera = .region(MKCoordinateRegion(center: coord,
                                                latitudinalMeters: 800, longitudinalMeters: 800))
        }
    }

    private func saveAll() {
        guard !pending.isEmpty else { return }
        let saved = pending

        for (index, pin) in saved.enumerated() {
            let loc = CardLocation(latitude: pin.latitude, longitude: pin.longitude,
                                   name: pin.name, address: pin.address)
            modelContext.insert(loc)
            loc.card = card
            // First location on a card with no primary becomes the primary.
            if index == 0, card.locationLatitude == nil {
                card.locationName = pin.name
                card.locationLatitude = pin.latitude
                card.locationLongitude = pin.longitude
                card.locationRadius = 100.0
            }
        }
        card.updatedAt = Date()
        PersistenceHelper.save(modelContext, label: "AddLocationsOnMapView.saveAll")

        // Best-effort submit to the crowdsource pipeline (non-fatal; mirrors AddPlaceViewForCardModel).
        if let client = apiClient {
            Task {
                do {
                    let serverCardId = try await CardServerSync.ensureServerCardId(
                        card: card, apiClient: client, keychainService: keychainService)
                    for pin in saved {
                        _ = try? await client.reportCardLocation(
                            cardId: serverCardId, locationName: pin.name, address: pin.address,
                            latitude: pin.latitude, longitude: pin.longitude,
                            notes: nil, source: "add_place")
                    }
                } catch {
                    print("⚠️ Map location submit failed (saved locally): \(error)")
                }
            }
        }

        dismiss()
    }
}
