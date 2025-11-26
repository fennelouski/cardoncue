import SwiftUI
import CoreLocation

struct LocationPermissionView: View {
    @EnvironmentObject var geofenceManager: GeofenceManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed Header Section
                VStack(spacing: 16) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .cornerRadius(20)

                    Text("Location-Aware Cards")
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
                    ScrollView {
                        VStack(spacing: 16) {
                            Text("Get notified when you're near your saved locations")
                                .font(.title3)
                                .foregroundColor(.appGreen)
                                .multilineTextAlignment(.center)
                                .padding(.top, 16)

                            VStack(spacing: 12) {
                                FeatureRow(
                                    icon: "location.fill",
                                    title: "Smart Notifications",
                                    description: "Automatically shows cards when you arrive"
                                )

                                FeatureRow(
                                    icon: "battery.100",
                                    title: "Battery Efficient",
                                    description: "Uses minimal battery with smart monitoring"
                                )

                                FeatureRow(
                                    icon: "lock.fill",
                                    title: "Privacy First",
                                    description: "Location data stays on your device"
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
                        geofenceManager.requestLocationPermission()
                        // Dismiss after a delay to allow system dialog
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            dismiss()
                        }
                    } label: {
                        Text("Enable Location")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.appGreen)
                            .cornerRadius(12)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Maybe Later")
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
}

#Preview {
    LocationPermissionView()
        .environmentObject(GeofenceManager.shared)
}
