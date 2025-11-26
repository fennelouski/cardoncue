import SwiftUI

struct EmptyStateView: View {
    var onScanCard: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Illustration
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.1))
                        .frame(width: 160, height: 160)

                    Image(systemName: "creditcard.viewfinder")
                        .font(.system(size: 64))
                        .foregroundColor(.appPrimary)
                }

                // Content
                VStack(spacing: 16) {
                    Text(NSLocalizedString("no_cards_title", comment: "No cards empty state title"))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.appBlue)

                    Text(NSLocalizedString("no_cards_subtitle", comment: "No cards empty state subtitle"))
                        .font(.title3)
                        .foregroundColor(.appGreen)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 12) {
                        FeatureRow(
                            icon: "camera.fill",
                            title: NSLocalizedString("scan_camera_title", comment: "Scan with camera feature title"),
                            description: NSLocalizedString("scan_camera_description", comment: "Scan with camera feature description")
                        )

                        FeatureRow(
                            icon: "keyboard.fill",
                            title: NSLocalizedString("enter_manually_title", comment: "Enter manually feature title"),
                            description: NSLocalizedString("enter_manually_description", comment: "Enter manually feature description")
                        )

                        FeatureRow(
                            icon: "lock.fill",
                            title: NSLocalizedString("secure_private_title", comment: "Secure & private feature title"),
                            description: NSLocalizedString("secure_private_description", comment: "Secure & private feature description")
                        )
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    Button(action: onScanCard) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .font(.headline)
                            Text(NSLocalizedString("scan_first_card", comment: "Scan first card button"))
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.appPrimary)
                        .cornerRadius(12)
                    }

                    Button(action: {
                        // Show manual entry option
                        // This could open a sheet or navigate to a manual entry view
                    }) {
                        Text(NSLocalizedString("add_manually", comment: "Add manually button"))
                            .font(.subheadline)
                            .foregroundColor(.appBlue)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appLightGray.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .foregroundColor(.appBlue)
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.appBlue)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.appLightGray)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    EmptyStateView(onScanCard: {})
}
