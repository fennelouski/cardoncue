import WidgetKit
import SwiftUI
import SwiftData
import CoreLocation

/// Widget that automatically shows the closest card's barcode based on location
struct ClosestCardWidget: Widget {
    let kind: String = "ClosestCardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClosestCardTimelineProvider()) { entry in
            ClosestCardWidgetView(entry: entry)
                .containerBackground(Color.appBackground, for: .widget)
        }
        .configurationDisplayName("Closest Card")
        .description("Automatically shows your membership card for the nearest location.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Timeline entry containing card data for the widget
struct ClosestCardEntry: TimelineEntry {
    let date: Date
    let card: WidgetCardData?
    let locationName: String?
    let distance: String?
    let error: String?
    
    var hasCard: Bool {
        card != nil && error == nil
    }
}

/// Simplified card data structure for widgets
struct WidgetCardData {
    let id: String
    let name: String
    let barcodeType: String
    let payload: String
    let locationName: String?
}

/// Timeline provider that finds the closest card
struct ClosestCardTimelineProvider: TimelineProvider {
    typealias Entry = ClosestCardEntry
    
    func placeholder(in context: Context) -> ClosestCardEntry {
        ClosestCardEntry(
            date: Date(),
            card: WidgetCardData(
                id: "placeholder",
                name: "Sample Card",
                barcodeType: "qr",
                payload: "1234567890",
                locationName: "Nearby Location"
            ),
            locationName: "Nearby Location",
            distance: "0.2 mi",
            error: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ClosestCardEntry) -> Void) {
        Task {
            let entry = await loadClosestCard()
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClosestCardEntry>) -> Void) {
        Task {
            let entry = await loadClosestCard()
            
            // Update every 15 minutes or when location changes significantly
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            
            completion(timeline)
        }
    }
    
    private func loadClosestCard() async -> ClosestCardEntry {
        do {
            // Access SwiftData model container
            // Try CloudKit first, fallback to local storage
            let schema = Schema([CardModel.self])
            let container: ModelContainer
            
            do {
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private("iCloud.com.cardoncue.app")
                )
                container = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
            } catch {
                // Fallback to local-only storage
                let localConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )
                container = try ModelContainer(
                    for: schema,
                    configurations: [localConfiguration]
                )
            }
            
            let context = container.mainContext
            
            // Fetch all active cards
            let descriptor = FetchDescriptor<CardModel>(
                predicate: #Predicate<CardModel> { card in
                    card.archivedAt == nil
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            
            let cards = try context.fetch(descriptor)
            
            // Get current location (from shared UserDefaults via App Group)
            let userDefaults = UserDefaults(suiteName: "group.com.cardoncue.app")
            let currentLat = userDefaults?.double(forKey: "lastKnownLatitude")
            let currentLon = userDefaults?.double(forKey: "lastKnownLongitude")
            
            guard let lat = currentLat, let lon = currentLon,
                  lat != 0, lon != 0 else {
                // No location available, return first card or error
                if let firstCard = cards.first {
                    return try await createEntry(from: firstCard, locationName: nil, distance: nil)
                }
                return ClosestCardEntry(
                    date: Date(),
                    card: nil,
                    locationName: nil,
                    distance: nil,
                    error: "Location unavailable"
                )
            }
            
            let currentLocation = CLLocation(latitude: lat, longitude: lon)
            
            // Find closest card with location data
            var closestCard: CardModel?
            var closestDistance: CLLocationDistance = Double.infinity
            var closestLocationName: String?
            
            for card in cards {
                guard let cardLat = card.locationLatitude,
                      let cardLon = card.locationLongitude else {
                    continue
                }
                
                let cardLocation = CLLocation(latitude: cardLat, longitude: cardLon)
                let distance = currentLocation.distance(from: cardLocation)
                
                if distance < closestDistance {
                    closestDistance = distance
                    closestCard = card
                    closestLocationName = card.locationName
                }
            }
            
            // If no card with location, use first card
            guard let card = closestCard ?? cards.first else {
                return ClosestCardEntry(
                    date: Date(),
                    card: nil,
                    locationName: nil,
                    distance: nil,
                    error: "No cards available"
                )
            }
            
            let distanceString = formatDistance(closestDistance)
            return try await createEntry(
                from: card,
                locationName: closestLocationName,
                distance: distanceString
            )
            
        } catch {
            print("⚠️ Widget error: \(error)")
            return ClosestCardEntry(
                date: Date(),
                card: nil,
                locationName: nil,
                distance: nil,
                error: "Unable to load cards"
            )
        }
    }
    
    private func createEntry(from card: CardModel, locationName: String?, distance: String?) async throws -> ClosestCardEntry {
        // Decrypt payload
        let keychainService = KeychainService()
        guard let masterKey = try keychainService.getMasterKey() else {
            return ClosestCardEntry(
                date: Date(),
                card: nil,
                locationName: locationName,
                distance: distance,
                error: "Encryption key unavailable"
            )
        }
        
        let payload: String
        do {
            payload = try card.decryptPayload(masterKey: masterKey)
        } catch {
            return ClosestCardEntry(
                date: Date(),
                card: nil,
                locationName: locationName,
                distance: distance,
                error: "Unable to decrypt card"
            )
        }
        
        let widgetCard = WidgetCardData(
            id: card.id,
            name: card.name,
            barcodeType: card.barcodeType.rawValue,
            payload: payload,
            locationName: locationName
        )
        
        return ClosestCardEntry(
            date: Date(),
            card: widgetCard,
            locationName: locationName,
            distance: distance,
            error: nil
        )
    }
    
    private func formatDistance(_ meters: CLLocationDistance) -> String? {
        if meters == Double.infinity {
            return nil
        }
        
        let miles = meters / 1609.34
        if miles < 0.1 {
            return "< 0.1 mi"
        } else if miles < 1 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
}

/// Widget view displaying the closest card
struct ClosestCardWidgetView: View {
    var entry: ClosestCardEntry
    
    var body: some View {
        Group {
            if entry.hasCard, let card = entry.card {
                cardContent(card: card)
            } else {
                errorContent
            }
        }
    }
    
    @ViewBuilder
    private func cardContent(card: WidgetCardData) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Header with location info
                headerView(card: card)
                
                // Barcode display
                barcodeView(card: card, size: geometry.size)
                
                // Footer
                footerView(card: card)
            }
        }
    }
    
    @ViewBuilder
    private func headerView(card: WidgetCardData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let locationName = entry.locationName {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.appPrimary)
                    Text(locationName)
                        .font(.caption2)
                        .foregroundColor(.appLightGray)
                        .lineLimit(1)
                }
            }
            
            Text(card.name)
                .font(.headline)
                .foregroundColor(.appBlue)
                .lineLimit(2)
            
            if let distance = entry.distance {
                Text(distance)
                    .font(.caption2)
                    .foregroundColor(.appLightGray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private func barcodeView(card: WidgetCardData, size: CGSize) -> some View {
        let barcodeHeight = size.height * 0.5
        
        ZStack {
            Rectangle()
                .fill(Color.white)
            
            if let image = generateBarcodeImage(
                payload: card.payload,
                type: card.barcodeType,
                size: CGSize(width: size.width - 24, height: barcodeHeight)
            ) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(8)
            } else {
                VStack(spacing: 4) {
                    Image(systemName: barcodeIcon(for: card.barcodeType))
                        .font(.system(size: 24))
                        .foregroundColor(.appLightGray)
                    Text("Unable to generate barcode")
                        .font(.caption2)
                        .foregroundColor(.appLightGray)
                }
            }
        }
        .cornerRadius(8)
        .padding(.horizontal, 12)
    }
    
    @ViewBuilder
    private func footerView(card: WidgetCardData) -> some View {
        HStack {
            Text(card.barcodeType.uppercased())
                .font(.caption2)
                .foregroundColor(.appLightGray)
            
            Spacer()
            
            Text("Updated \(entry.date, style: .relative)")
                .font(.caption2)
                .foregroundColor(.appLightGray)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
    
    private var errorContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(.appLightGray)
            
            Text(entry.error ?? "Unable to load card")
                .font(.caption)
                .foregroundColor(.appLightGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func generateBarcodeImage(payload: String, type: String, size: CGSize) -> UIImage? {
        let renderer = BarcodeRenderer()
        let barcodeTypeEnum = mapBarcodeType(type)
        
        do {
            return try renderer.render(
                payload: payload,
                type: barcodeTypeEnum,
                size: size
            )
        } catch {
            print("Error generating barcode: \(error)")
            return nil
        }
    }
    
    private func mapBarcodeType(_ type: String) -> BarcodeType {
        switch type.lowercased() {
        case "qr":
            return .qr
        case "code128":
            return .code128
        case "pdf417":
            return .pdf417
        case "aztec":
            return .aztec
        case "ean13":
            return .ean13
        case "upc_a":
            return .upcA
        case "code39":
            return .code39
        case "itf":
            return .itf
        default:
            return .qr
        }
    }
    
    private func barcodeIcon(for type: String) -> String {
        switch type.lowercased() {
        case "qr":
            return "qrcode"
        case "pdf417":
            return "doc.text"
        case "aztec":
            return "square.grid.2x2"
        default:
            return "barcode"
        }
    }
}

#Preview(as: .systemSmall) {
    ClosestCardWidget()
} timeline: {
    ClosestCardEntry(
        date: Date(),
        card: WidgetCardData(
            id: "preview",
            name: "Costco Membership",
            barcodeType: "qr",
            payload: "1234567890",
            locationName: "Costco - Main St"
        ),
        locationName: "Costco - Main St",
        distance: "0.3 mi",
        error: nil
    )
}

