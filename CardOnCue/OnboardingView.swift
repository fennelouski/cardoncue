import SwiftUI
import CoreLocation
import UserNotifications

/// Welcome tour. The location and notification pages ask for permission in context,
/// so the user sees why before the system prompt appears.
struct OnboardingView: View {
    @EnvironmentObject var onboardingService: OnboardingService
    @EnvironmentObject var geofenceManager: GeofenceManager
    @AppStorage("hasSeenLocationPrompt") private var hasSeenLocationPrompt = false
    @AppStorage("hasSeenNotificationPrompt") private var hasSeenNotificationPrompt = false

    @State private var currentPage = 0
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private enum Step { case info, location, notifications }

    private struct Page {
        let step: Step
        let title: String
        let subtitle: String
        let description: String
        let image: String
        let color: Color
        var isCustomImage = false
    }

    private let pages: [Page] = [
        Page(step: .info,
             title: NSLocalizedString("welcome_title", comment: "Welcome screen title"),
             subtitle: NSLocalizedString("welcome_subtitle", comment: "Welcome screen subtitle"),
             description: NSLocalizedString("welcome_description", comment: "Welcome screen description"),
             image: "AppLogo", color: .appPrimary, isCustomImage: true),
        Page(step: .info,
             title: NSLocalizedString("scan_store_title", comment: "Scan & Store screen title"),
             subtitle: NSLocalizedString("scan_store_subtitle", comment: "Scan & Store screen subtitle"),
             description: NSLocalizedString("scan_store_description", comment: "Scan & Store screen description")
                + (CardIntelligence.status == .available
                   ? "\n\n" + NSLocalizedString("scan_store_ai", value: "Apple Intelligence reads the brand, name and expiry date for you, right on your device.", comment: "Onboarding note about smart scanning")
                   : ""),
             image: "camera.viewfinder", color: .appBlue),
        Page(step: .location,
             title: NSLocalizedString("location_aware_title", comment: "Location Aware screen title"),
             subtitle: NSLocalizedString("location_aware_subtitle", comment: "Location Aware screen subtitle"),
             description: NSLocalizedString("location_aware_description", comment: "Location Aware screen description"),
             image: "location.circle.fill", color: .appGreen),
        Page(step: .notifications,
             title: NSLocalizedString("notify_title", value: "Right on Cue", comment: "Onboarding notifications title"),
             subtitle: NSLocalizedString("notify_subtitle", value: "A tap away when you arrive", comment: "Onboarding notifications subtitle"),
             description: NSLocalizedString("notify_description", value: "Allow notifications and CardOnCue will put the right card on your Lock Screen and Apple Watch as you walk in. Only for places you've saved, never ads.", comment: "Onboarding notifications description"),
             image: "bell.badge.fill", color: .appPrimary),
        Page(step: .info,
             title: NSLocalizedString("privacy_first_title", comment: "Privacy First screen title"),
             subtitle: NSLocalizedString("privacy_first_subtitle", comment: "Privacy First screen subtitle"),
             description: NSLocalizedString("privacy_first_description", comment: "Privacy First screen description"),
             image: "hand.raised.fill", color: .appBlue)
    ]

    private var page: Page { pages[currentPage] }
    private var isLastPage: Bool { currentPage == pages.count - 1 }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(NSLocalizedString("skip_button", comment: "Skip button"), action: finish)
                        .font(.subheadline)
                        .foregroundColor(.appLightGray)
                        .opacity(isLastPage ? 0 : 1)
                        .disabled(isLastPage)
                }
                .padding(.horizontal, 24)
                .frame(height: 44)

                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { index in
                        OnboardingPageView(
                            title: pages[index].title,
                            subtitle: pages[index].subtitle,
                            description: pages[index].description,
                            image: pages[index].image,
                            color: pages[index].color,
                            isCustomImage: pages[index].isCustomImage,
                            badge: grantedBadge(for: pages[index].step)
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator.padding(.vertical, 16)

                VStack(spacing: 8) {
                    Button(action: primaryAction) {
                        Text(primaryTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(page.color)
                            .cornerRadius(14)
                    }

                    // "Not now" only where there is something to decline.
                    Button(NSLocalizedString("not_now", value: "Not Now", comment: "Decline permission button"), action: advance)
                        .font(.subheadline)
                        .foregroundColor(.appLightGray)
                        .padding(.vertical, 8)
                        .opacity(needsPermission ? 1 : 0)
                        .disabled(!needsPermission)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
        .task { await refreshNotificationStatus() }
        .onChange(of: geofenceManager.authorizationStatus) { _, status in
            // The system prompt was answered; move on.
            if page.step == .location && status != .notDetermined { advance() }
        }
    }

    // MARK: Pieces

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? page.color : Color.appLightGray.opacity(0.4))
                    .frame(width: index == currentPage ? 22 : 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(String(format: NSLocalizedString("page_x_of_y", value: "Page %d of %d", comment: ""), currentPage + 1, pages.count))
    }

    private var needsPermission: Bool {
        switch page.step {
        case .location: return geofenceManager.authorizationStatus == .notDetermined
        case .notifications: return notificationStatus == .notDetermined
        case .info: return false
        }
    }

    private var primaryTitle: String {
        if isLastPage { return NSLocalizedString("get_started", comment: "Get Started button") }
        guard needsPermission else { return NSLocalizedString("next_button", comment: "Next button") }
        return page.step == .location
            ? NSLocalizedString("enable_location", value: "Enable Location", comment: "")
            : NSLocalizedString("enable_notifications", value: "Enable Notifications", comment: "")
    }

    private func grantedBadge(for step: Step) -> String? {
        let granted: Bool
        switch step {
        case .location: granted = [.authorizedAlways, .authorizedWhenInUse].contains(geofenceManager.authorizationStatus)
        case .notifications: granted = [.authorized, .provisional, .ephemeral].contains(notificationStatus)
        case .info: return nil
        }
        return granted ? NSLocalizedString("permission_enabled", value: "Enabled", comment: "Permission granted badge") : nil
    }

    // MARK: Actions

    private func primaryAction() {
        if isLastPage { return finish() }
        guard needsPermission else { return advance() }
        switch page.step {
        case .location:
            hasSeenLocationPrompt = true
            geofenceManager.requestLocationPermission() // advances via onChange
        case .notifications:
            hasSeenNotificationPrompt = true
            Task {
                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                await refreshNotificationStatus()
                advance()
            }
        case .info:
            advance()
        }
    }

    private func advance() {
        // Passing a permission page (either way) means MainView shouldn't re-ask with a sheet.
        if page.step == .location { hasSeenLocationPrompt = true }
        if page.step == .notifications { hasSeenNotificationPrompt = true }
        if isLastPage { finish() } else { currentPage += 1 }
    }

    private func finish() {
        withAnimation { onboardingService.completeOnboarding() }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}

struct OnboardingPageView: View {
    let title: String
    let subtitle: String
    let description: String
    let image: String
    let color: Color
    let isCustomImage: Bool
    var badge: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                Group {
                    if isCustomImage {
                        Image(image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 128, height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .shadow(color: color.opacity(0.3), radius: 16, y: 8)
                    } else {
                        ZStack {
                            Circle()
                                .fill(color.opacity(0.12))
                                .frame(width: 128, height: 128)
                            Image(systemName: image)
                                .font(.system(size: 52, weight: .semibold))
                                .foregroundColor(color)
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
                }
                .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundColor(.appBlue)
                    Text(subtitle)
                        .font(.title3.weight(.medium))
                        .foregroundColor(color)
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .padding(.top, 4)
                    if let badge {
                        Label(badge, systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appGreen)
                            .padding(.top, 8)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

                Spacer(minLength: 24)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(OnboardingService())
        .environmentObject(GeofenceManager.shared)
}
