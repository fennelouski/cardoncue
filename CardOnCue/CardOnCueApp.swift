//
//  CardOnCueApp.swift
//  CardOnCue
//
//  Created by Nathan Fennel on 11/22/25.
//

import SwiftUI
import SwiftData
import Clerk

@main
struct CardOnCueApp: App {
    // App Delegate for notification handling
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Clerk authentication (official SDK)
    @State private var clerk = Clerk.shared

    // Services
    @StateObject private var onboardingService = OnboardingService()

    // SwiftData ModelContainer with CloudKit sync
    let modelContainer: ModelContainer

    init() {
        do {
            // Configure SwiftData with CloudKit
            let schema = Schema([CardModel.self])

            // Try CloudKit configuration first
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private("iCloud.com.cardoncue.app")
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
                let schema = Schema([CardModel.self])
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
                .environment(\.clerk, clerk)
                .environmentObject(onboardingService)
                .task {
                    // Configure Clerk with publishable key
                    clerk.configure(publishableKey: "pk_test_Z3VpZGluZy13cmVuLTk0LmNsZXJrLmFjY291bnRzLmRldiQ")

                    // Load Clerk session
                    try? await clerk.load()

                    // Configure geofence manager with model context (synchronous operation)
                    GeofenceManager.shared.configure(modelContext: modelContainer.mainContext)
                }
                .environmentObject(GeofenceManager.shared)
        }
        .modelContainer(modelContainer)
    }
}
