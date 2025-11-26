import SwiftUI
import UserNotifications

struct NotificationEducationView: View {
    @Environment(\.dismiss) private var dismiss
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed Header Section
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.appPrimary.opacity(0.1))
                            .frame(width: 120, height: 120)

                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.appPrimary)
                    }

                    Text("Stay Informed")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.appBlue)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                .padding(.horizontal, 32)
                .background(Color.appBackground)

                // Scrollable Content Section with Fade Gradients
                ZStack {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 16) {
                            Text("Get notified when you're near your favorite stores")
                                .font(.title3)
                                .foregroundColor(.appGreen)
                                .multilineTextAlignment(.center)
                                .padding(.top, 16)

                            VStack(spacing: 12) {
                                FeatureRow(
                                    icon: "mappin.circle.fill",
                                    title: "Location-Based Alerts",
                                    description: "Receive timely reminders when you arrive at stores"
                                )

                                FeatureRow(
                                    icon: "creditcard.fill",
                                    title: "Never Miss Rewards",
                                    description: "Always have your membership card ready to scan"
                                )

                                FeatureRow(
                                    icon: "moon.fill",
                                    title: "Smart & Respectful",
                                    description: "Only notifies when relevant, respects Do Not Disturb"
                                )

                                FeatureRow(
                                    icon: "hand.raised.fill",
                                    title: "You're in Control",
                                    description: "Disable anytime in Settings"
                                )
                            }
                            .padding(.vertical, 8)
                            .padding(.bottom, 16)
                        }
                        .padding(.horizontal, 32)
                    }

                    // Top fade gradient
                    VStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.appBackground.opacity(1),
                                Color.appBackground.opacity(0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 8)

                        Spacer()

                        // Bottom fade gradient
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.appBackground.opacity(0),
                                Color.appBackground.opacity(1)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 8)
                    }
                    .allowsHitTesting(false)
                }

                // Fixed Action Buttons Section
                VStack(spacing: 16) {
                    Button {
                        requestNotificationPermission()
                    } label: {
                        Text("Enable Notifications")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.appPrimary)
                            .cornerRadius(12)
                    }

                    Button {
                        // User chose to skip, just dismiss
                        dismiss()
                        onComplete()
                    } label: {
                        Text("Not Now")
                            .font(.subheadline)
                            .foregroundColor(.appLightGray)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .background(Color.appBackground)
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("⚠️ Notification permission denied")
                }
                // Dismiss and call completion regardless of result
                dismiss()
                onComplete()
            }
        }
    }
}

#Preview {
    NotificationEducationView(onComplete: {})
}
