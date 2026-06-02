import SwiftUI
import CoreLocation

struct MainView: View {
    @EnvironmentObject var onboardingService: OnboardingService
    @EnvironmentObject var geofenceManager: GeofenceManager
    @AppStorage("hasSeenLocationPrompt") private var hasSeenLocationPrompt = false
    @AppStorage("hasSeenNotificationPrompt") private var hasSeenNotificationPrompt = false
    @State private var showLocationPermission = false
    @State private var showNotificationEducation = false

    var body: some View {
        Group {
            if !onboardingService.hasCompletedOnboarding {
                // Show onboarding
                OnboardingView()
            } else {
                // Show main app
                CardListView()
            }
        }
        .sheet(isPresented: $showLocationPermission) {
            LocationPermissionView()
        }
        .sheet(isPresented: $showNotificationEducation) {
            NotificationEducationView {
                hasSeenNotificationPrompt = true
            }
        }
        .onChange(of: onboardingService.hasCompletedOnboarding) { _, completed in
            if completed && !hasSeenLocationPrompt && geofenceManager.authorizationStatus == .notDetermined {
                // Show location permission prompt after onboarding
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showLocationPermission = true
                    hasSeenLocationPrompt = true
                }
            }
        }
        .onChange(of: geofenceManager.authorizationStatus) { _, status in
            // After location permission is granted, show notification education
            if (status == .authorizedWhenInUse || status == .authorizedAlways) && !hasSeenNotificationPrompt {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showNotificationEducation = true
                }
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(OnboardingService())
}
