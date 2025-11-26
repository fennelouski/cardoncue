import SwiftUI
import Clerk

struct MainView: View {
    @Environment(\.clerk) private var clerk
    @EnvironmentObject var onboardingService: OnboardingService
    @AppStorage("hasSkippedAuth") private var hasSkippedAuth = false

    var body: some View {
        Group {
            if clerk.user == nil && !hasSkippedAuth {
                // Show Clerk's prebuilt authentication view with skip option
                ClerkAuthView(hasSkippedAuth: $hasSkippedAuth)
            } else if !onboardingService.hasCompletedOnboarding {
                // Show onboarding
                OnboardingView()
            } else {
                // Show main app
                CardListView()
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
