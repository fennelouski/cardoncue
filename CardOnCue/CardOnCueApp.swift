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
                }
                .environmentObject(GeofenceManager.shared)
        }
        .modelContainer(modelContainer)
    }
}
