import Foundation
import Combine

/// Service for managing user onboarding state
@MainActor
class OnboardingService: ObservableObject {
    @Published var hasCompletedOnboarding: Bool = false

    private let onboardingCompletedKey = "hasCompletedOnboarding"

    init() {
        // Load onboarding status from UserDefaults
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: onboardingCompletedKey)
    }

    /// Mark onboarding as completed
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: onboardingCompletedKey)
        UserDefaults.standard.synchronize()
    }

    /// Reset onboarding (useful for testing or user preference)
    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: onboardingCompletedKey)
        UserDefaults.standard.synchronize()
    }
}
