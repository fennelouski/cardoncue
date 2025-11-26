import SwiftUI
import AVFoundation

struct CameraPermissionPromptView: View {
    @Environment(\.dismiss) private var dismiss

    var onPermissionGranted: () -> Void
    var onPermissionDenied: () -> Void

    @State private var isRequesting = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Fixed top section - Icon and Title
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.appBlue.opacity(0.1))
                                .frame(width: 120, height: 120)

                            Image(systemName: "camera.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.appBlue)
                        }
                        .padding(.top, 24)

                        Text("Camera Access Needed")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.appBlue)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.bottom, 16)

                    // Scrollable content with gradients
                    ZStack {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 16) {
                                Text("CardOnCue needs access to your camera to scan barcodes on your membership and loyalty cards.")
                                    .font(.body)
                                    .foregroundColor(.appLightGray)
                                    .multilineTextAlignment(.center)

                                // Benefits list
                                VStack(alignment: .leading, spacing: 12) {
                                    BenefitRow(
                                        icon: "qrcode.viewfinder",
                                        text: "Quickly scan any barcode type"
                                    )

                                    BenefitRow(
                                        icon: "lock.shield.fill",
                                        text: "Your photos are never saved"
                                    )

                                    BenefitRow(
                                        icon: "bolt.fill",
                                        text: "Faster than manual entry"
                                    )
                                }
                                .padding(.vertical, 8)
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
                    VStack(spacing: 12) {
                        Button(action: requestCameraPermission) {
                            HStack {
                                if isRequesting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "camera.fill")
                                        .font(.headline)
                                    Text("Allow Camera Access")
                                        .font(.headline)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.appPrimary)
                            .cornerRadius(12)
                        }
                        .disabled(isRequesting)

                        Button(action: {
                            onPermissionDenied()
                            dismiss()
                        }) {
                            Text("Enter Manually Instead")
                                .font(.subheadline)
                                .foregroundColor(.appBlue)
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onPermissionDenied()
                        dismiss()
                    }
                    .foregroundColor(.appBlue)
                }
            }
        }
    }

    private func requestCameraPermission() {
        isRequesting = true

        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                isRequesting = false

                if granted {
                    onPermissionGranted()
                    dismiss()
                } else {
                    onPermissionDenied()
                    dismiss()
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.appGreen)
                .font(.system(size: 16))
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.appBlue)

            Spacer()
        }
    }
}

#Preview {
    CameraPermissionPromptView(
        onPermissionGranted: {},
        onPermissionDenied: {}
    )
}
