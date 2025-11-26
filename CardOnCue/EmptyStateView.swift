import SwiftUI

struct EmptyStateView: View {
    var onScanCard: () -> Void
    var onAddManually: () -> Void
    var canScan: Bool = true

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Fixed top section - Logo
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 160, height: 160)
                    .cornerRadius(30)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                // Fixed title and subtitle
                VStack(spacing: 8) {
                    Text(NSLocalizedString("no_cards_title", comment: "No cards empty state title"))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.appBlue)

                    Text(NSLocalizedString("no_cards_subtitle", comment: "No cards empty state subtitle"))
                        .font(.title3)
                        .foregroundColor(.appGreen)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 16)

                // Scrollable content with gradients
                ZStack {
                    ScrollView(.vertical, showsIndicators: false) {
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
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                    }

                    // Top gradient
                    VStack {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.appBackground.opacity(1.0),
                                Color.appBackground.opacity(0.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 8)
                        .allowsHitTesting(false)

                        Spacer()
                    }

                    // Bottom gradient
                    VStack {
                        Spacer()

                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.appBackground.opacity(0.0),
                                Color.appBackground.opacity(1.0)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 8)
                        .allowsHitTesting(false)
                    }
                }

                // Fixed bottom section - Action buttons
                VStack(spacing: 16) {
                    if canScan {
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

                        Button(action: onAddManually) {
                            Text(NSLocalizedString("add_manually", comment: "Add manually button"))
                                .font(.subheadline)
                                .foregroundColor(.appBlue)
                                .padding(.vertical, 12)
                        }
                    } else {
                        // Only show manual entry if camera is denied
                        Button(action: onAddManually) {
                            HStack {
                                Image(systemName: "keyboard")
                                    .font(.headline)
                                Text(NSLocalizedString("add_manually", comment: "Add manually button"))
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.appPrimary)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    EmptyStateView(onScanCard: {}, onAddManually: {}, canScan: true)
}
