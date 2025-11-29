import SwiftUI
import Clerk

struct MainView: View {
    @Environment(\.clerk) private var clerk
    @EnvironmentObject var onboardingService: OnboardingService
    @StateObject private var storageService = StorageService()
    @StateObject private var geofenceActivityCoordinator: GeofenceActivityCoordinator
    @AppStorage("hasSkippedAuth") private var hasSkippedAuth = false

    init() {
        // Initialize coordinator with storageService
        let storage = StorageService()
        _storageService = StateObject(wrappedValue: storage)
        _geofenceActivityCoordinator = StateObject(wrappedValue: GeofenceActivityCoordinator(storageService: storage))
    }

    var body: some View {
        Group {
            if clerk.user == nil && !hasSkippedAuth {
                // Show Clerk's prebuilt authentication view with skip option
                ClerkAuthView(hasSkippedAuth: $hasSkippedAuth)
            } else if !onboardingService.hasCompletedOnboarding {
                // Show onboarding
                OnboardingView()
            } else {
                // Show main app with tab navigation
                MainTabView()
                    .environmentObject(storageService)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var storageService: StorageService
    @State private var selectedTab = 0
    @State private var showingCardDetail = false
    @State private var showingCardSelector = false
    @State private var selectedCardId: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            CardListView()
                .tabItem {
                    Label("Cards", systemImage: "creditcard")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(1)
                .badge(storageService.deletedCardsCount > 0 ? storageService.deletedCardsCount : nil)
        }
        .tint(.appPrimary)
        .sheet(isPresented: $showingCardDetail) {
            if let cardId = selectedCardId,
               let card = storageService.getCard(by: cardId) {
                CardDetailView(card: card)
            }
        }
        .sheet(isPresented: $showingCardSelector) {
            LocationCardSelectorView(locationCardService: LocationCardService.shared)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCardFromNotification"))) { notification in
            if let cardId = notification.userInfo?["cardId"] as? String {
                selectedCardId = cardId
                selectedTab = 0 // Switch to Cards tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showingCardDetail = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowCardSelectorFromNotification"))) { _ in
            selectedTab = 0 // Switch to Cards tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingCardSelector = true
            }
        }
    }
}

// Wrapper view for Clerk's prebuilt AuthView
struct ClerkAuthView: View {
    @Binding var hasSkippedAuth: Bool
    @State private var isAuthPresented = false

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App logo/branding
                VStack(spacing: 16) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .cornerRadius(20)

                    Text("CardOnCue")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.appBlue)

                    Text("Your digital membership card wallet")
                        .font(.subheadline)
                        .foregroundColor(.appLightGray)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 16) {
                    // Sign in button
                    Button("Sign In") {
                        isAuthPresented = true
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .padding(8) // Minimum 8-point padding around button
                    .background(Color.appPrimary)
                    .cornerRadius(12)

                    // Skip button
                    Button("Continue without signing in") {
                        hasSkippedAuth = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.appLightGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .padding(8) // Minimum 8-point padding around button
                    .background(Color.appBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.appLightGray.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(12)
                }

                Spacer()
            }
            .padding(.vertical, 40)
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $isAuthPresented) {
            // Clerk's prebuilt AuthView handles sign-in/sign-up
            AuthView()
                .environment(\.clerk, Clerk.shared)
        }
    }
}

#Preview {
    MainView()
        .environmentObject(OnboardingService())
        .environment(\.clerk, Clerk.shared)
}
