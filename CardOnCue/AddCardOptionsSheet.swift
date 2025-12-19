import SwiftUI

struct AddCardOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    var onScanCard: () -> Void
    var onAddManually: () -> Void
    var onImportPhoto: () -> Void
    var canScan: Bool

    private var pageCount: Int {
        canScan ? 3 : 2
    }

    private var currentOptionLabel: String {
        if canScan {
            switch currentPage {
            case 0: return "Scan Camera"
            case 1: return "Import Photo"
            case 2: return "Enter Manually"
            default: return ""
            }
        } else {
            switch currentPage {
            case 0: return "Import Photo"
            case 1: return "Enter Manually"
            default: return ""
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .padding()
            }

            // Title
            Text("Choose Import Method")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 8)

            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    if index < pageCount {
                        Circle()
                            .fill(currentPage == index ? Color.appPrimary : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
            }
            .padding(.bottom, 16)

            // Navigation buttons
            HStack(spacing: 20) {
                // Previous button
                Button(action: {
                    withAnimation {
                        if currentPage > 0 {
                            currentPage -= 1
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Previous")
                    }
                    .font(.subheadline)
                    .foregroundColor(currentPage > 0 ? .appPrimary : .gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(currentPage > 0 ? Color.appPrimary.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(currentPage == 0)

                Spacer()

                // Current option label
                Text(currentOptionLabel)
                    .font(.headline)
                    .foregroundColor(.appPrimary)

                Spacer()

                // Next button
                Button(action: {
                    withAnimation {
                        if currentPage < pageCount - 1 {
                            currentPage += 1
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(currentPage < pageCount - 1 ? .appPrimary : .gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(currentPage < pageCount - 1 ? Color.appPrimary.opacity(0.1) : Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(currentPage == pageCount - 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // Swipeable pages
            TabView(selection: $currentPage) {
                // Scan Card Option - only show if camera is available
                if canScan {
                    OptionPage(
                        icon: "camera.viewfinder",
                        title: NSLocalizedString("scan_camera_title", comment: "Scan with camera feature title"),
                        description: NSLocalizedString("scan_camera_description", comment: "Scan with camera feature description"),
                        buttonTitle: NSLocalizedString("scan_card", comment: "Scan card button"),
                        buttonAction: {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onScanCard()
                            }
                        },
                        isDisabled: false
                    )
                    .tag(0)
                }

                // Import Photo Option
                OptionPage(
                    icon: "photo.fill",
                    title: NSLocalizedString("import_photo_title", comment: "Import from photo feature title"),
                    description: NSLocalizedString("import_photo_description", comment: "Import from photo feature description"),
                    buttonTitle: NSLocalizedString("import_photo", comment: "Import photo button"),
                    buttonAction: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onImportPhoto()
                        }
                    },
                    isDisabled: false
                )
                .tag(canScan ? 1 : 0)

                // Manual Entry Option
                OptionPage(
                    icon: "keyboard.fill",
                    title: NSLocalizedString("enter_manually_title", comment: "Enter manually feature title"),
                    description: NSLocalizedString("enter_manually_description", comment: "Enter manually feature description"),
                    buttonTitle: NSLocalizedString("add_manually", comment: "Add manually button"),
                    buttonAction: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onAddManually()
                        }
                    },
                    isDisabled: false
                )
                .tag(canScan ? 2 : 1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

struct OptionPage: View {
    let icon: String
    let title: String
    let description: String
    let buttonTitle: String
    let buttonAction: () -> Void
    let isDisabled: Bool
    var disabledMessage: String = ""

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundColor(isDisabled ? .gray : .appPrimary)
                .padding(.bottom, 8)

            // Title and description
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(isDisabled ? .gray : .primary)
                    .multilineTextAlignment(.center)

                Text(description)
                    .font(.body)
                    .foregroundColor(isDisabled ? .gray : .secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if isDisabled && !disabledMessage.isEmpty {
                    Text(disabledMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }
            }

            Spacer()

            // Action button
            Button(action: buttonAction) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isDisabled ? Color.gray : Color.appPrimary)
                    .cornerRadius(12)
            }
            .disabled(isDisabled)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}

#Preview {
    AddCardOptionsSheet(
        onScanCard: {},
        onAddManually: {},
        onImportPhoto: {},
        canScan: true
    )
}
