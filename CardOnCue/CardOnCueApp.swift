//
//  CardOnCueApp.swift
//  CardOnCue
//
//  Created by Nathan Fennel on 11/22/25.
//

import SwiftUI
import SwiftData

@main
struct CardOnCueApp: App {
    // App Delegate for notification handling
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Services
    @StateObject private var onboardingService = OnboardingService()
    @State private var apiClient: APIClient?

    // SwiftData ModelContainer with CloudKit sync
    let modelContainer: ModelContainer

    init() {
        do {
            // Configure SwiftData with CloudKit
            let schema = Schema([
                CardModel.self,
                CardLocation.self,
                SavedLocation.self
            ])

            // Use CloudKit automatically when the iCloud entitlement/container
            // is present; otherwise SwiftData stays local. Forcing
            // .private(...) without the entitlement crashes CloudKit mirroring
            // asynchronously at launch, so .automatic is the safe choice.
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )

            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            print("✅ ModelContainer initialized with CloudKit sync")
        } catch {
            // Fallback to local-only storage if CloudKit fails
            print("⚠️ CloudKit initialization failed: \(error)")
            print("⚠️ Falling back to local-only storage")

            do {
                let schema = Schema([
                    CardModel.self,
                    CardLocation.self,
                    SavedLocation.self
                ])
                let localConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )

                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [localConfiguration]
                )

                print("✅ ModelContainer initialized with local storage only")
            } catch {
                fatalError("Failed to create ModelContainer even with local storage: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(\.apiClient, apiClient)
                .environmentObject(onboardingService)
                .task {
                    // Initialize API client. Base URL is overridable via the
                    // API_BASE_URL Info.plist key (per build config); otherwise
                    // it uses the production default.
                    let keychainService = KeychainService()
                    let configuredBaseURL = (Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String)
                        .flatMap { $0.isEmpty ? nil : $0 } ?? APIClient.defaultBaseURL
                    let client = APIClient(
                        baseURL: configuredBaseURL,
                        keychainService: keychainService
                    )
                    apiClient = client

                    // Configure geofence manager with model context (synchronous operation)
                    GeofenceManager.shared.configure(modelContext: modelContainer.mainContext)

                    #if DEBUG
                    // Populate a realistic card set for App Store screenshots.
                    // Opt-in only — see DemoDataSeeder.isRequested.
                    if DemoDataSeeder.isRequested {
                        DemoDataSeeder.seed(into: modelContainer.mainContext)
                        // Land directly on the populated card list: suppress onboarding and
                        // the post-onboarding location/notification permission sheets so the
                        // screenshot shows content, not a system-style prompt.
                        UserDefaults.standard.set(true, forKey: "hasSeenLocationPrompt")
                        UserDefaults.standard.set(true, forKey: "hasSeenNotificationPrompt")
                        onboardingService.completeOnboarding()
                    }
                    #endif
                }
                .environmentObject(GeofenceManager.shared)
        }
        .modelContainer(modelContainer)
    }
}

#if DEBUG
/// Seeds a realistic set of cards so App Store screenshots show a populated app.
///
/// DEBUG-only and opt-in — it never runs in a Release build and never runs unless the
/// `--seed-demo-data` launch argument is passed:
///
///     xcrun simctl launch <udid> com.nathanfennel.CardOnCue --seed-demo-data
///
/// Seeding is idempotent: existing cards are cleared first, so repeat launches produce
/// the same screenshots.
enum DemoDataSeeder {

    /// Accepts any of three triggers, because `simctl launch` forwards neither
    /// `--`-prefixed arguments nor `SIMCTL_CHILD_` environment variables reliably
    /// across Xcode versions. The defaults key is the one that always works:
    ///
    ///     xcrun simctl spawn <udid> defaults write com.nathanfennel.CardOnCue \
    ///         CardOnCueSeedDemoData -bool YES
    static var isRequested: Bool {
        let info = ProcessInfo.processInfo
        return info.arguments.contains("--seed-demo-data")
            || info.environment["CARDONCUE_SEED_DEMO"] == "1"
            || UserDefaults.standard.bool(forKey: "CardOnCueSeedDemoData")
    }

    /// Records the outcome where the host can read it:
    /// `<app data container>/Documents/demo-seed-result.txt`
    private static func writeMarker(_ text: String) {
        guard let dir = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first else { return }
        try? text.write(
            to: dir.appendingPathComponent("demo-seed-result.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    private struct Spec {
        let name: String
        let type: BarcodeType
        let payload: String
        let icon: String
        let locationName: String?
        let latitude: Double?
        let longitude: Double?
        var tags: [String] = []
        var oneTime: Bool = false
        var validTo: Date? = nil
        var daysAgo: Int = 0
    }

    // Coordinates are real Seattle-area storefronts so the map/location UI looks plausible.
    private static let specs: [Spec] = [
        Spec(name: "Costco Wholesale", type: .code128, payload: "111790500123",
             icon: "cart.fill", locationName: "Costco – Seattle, WA",
             latitude: 47.6205, longitude: -122.3493, tags: ["Warehouse"], daysAgo: 42),
        Spec(name: "Seattle Public Library", type: .code39, payload: "29223001234567",
             icon: "books.vertical.fill", locationName: "Central Library",
             latitude: 47.6067, longitude: -122.3325, tags: ["Library"], daysAgo: 31),
        Spec(name: "LA Fitness", type: .qr, payload: "LAF-8842-1193-0027",
             icon: "figure.run", locationName: "LA Fitness – Ballard",
             latitude: 47.6684, longitude: -122.3843, tags: ["Gym"], daysAgo: 24),
        Spec(name: "Safeway Club", type: .ean13, payload: "4006381333931",
             icon: "basket.fill", locationName: "Safeway – Queen Anne",
             latitude: 47.6370, longitude: -122.3570, tags: ["Grocery"], daysAgo: 18),
        Spec(name: "Starbucks Rewards", type: .qr, payload: "SBUX-9921-4410-8830",
             icon: "cup.and.saucer.fill", locationName: "Starbucks – Pike Place",
             latitude: 47.6100, longitude: -122.3420, tags: ["Coffee"], daysAgo: 11),
        Spec(name: "REI Co-op", type: .code128, payload: "1520998877341",
             icon: "tent.fill", locationName: "REI – Seattle Flagship",
             latitude: 47.6216, longitude: -122.3376, tags: ["Outdoors"], daysAgo: 7),
        Spec(name: "AMC Stubs", type: .code128, payload: "6045220198877",
             icon: "popcorn.fill", locationName: "AMC Pacific Place 11",
             latitude: 47.6118, longitude: -122.3360, tags: ["Movies"], daysAgo: 4),
        Spec(name: "Amazon Return", type: .qr, payload: "AMZN-RET-7788-2291",
             icon: "shippingbox.fill", locationName: "Whole Foods – Interbay",
             latitude: 47.6480, longitude: -122.3800, tags: ["One-time"],
             oneTime: true, validTo: Date().addingTimeInterval(60 * 60 * 48), daysAgo: 1)
    ]

    @MainActor
    static func seed(into context: ModelContext) {
        do {
            // Clear first so repeated launches are idempotent.
            try context.delete(model: CardModel.self)

            let keychain = KeychainService()
            let masterKey = try keychain.getMasterKey() ?? keychain.generateAndStoreMasterKey()

            for spec in specs {
                let card = try CardModel.createWithEncryptedPayload(
                    userId: AppUser.id,
                    name: spec.name,
                    barcodeType: spec.type,
                    payload: spec.payload,
                    masterKey: masterKey,
                    tags: spec.tags,
                    validTo: spec.validTo,
                    oneTime: spec.oneTime,
                    iconName: spec.icon
                )

                card.locationName = spec.locationName
                card.locationLatitude = spec.latitude
                card.locationLongitude = spec.longitude

                // Stagger dates so "recently added" ordering looks natural.
                let created = Date().addingTimeInterval(-Double(spec.daysAgo) * 86_400)
                card.createdAt = created
                card.updatedAt = created

                context.insert(card)
            }

            _ = PersistenceHelper.save(context, label: "DemoDataSeeder")

            let count = (try? context.fetchCount(FetchDescriptor<CardModel>())) ?? -1
            writeMarker("ok: inserted \(specs.count), store now has \(count)")
            print("✅ Seeded \(specs.count) demo cards for screenshots")
        } catch {
            writeMarker("error: \(error)")
            print("⚠️ Demo data seeding failed: \(error)")
        }
    }
}
#endif
