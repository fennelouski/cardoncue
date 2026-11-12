import SwiftUI
import CoreLocation
import UserNotifications

/// One place for every app-level preference and permission.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var onboardingService: OnboardingService
    @EnvironmentObject private var geofenceManager: GeofenceManager

    @AppStorage("cardSortOption") private var sortOption: CardSortOption = .recentlyAdded
    @AppStorage("cardGroupOption") private var groupOption: CardGroupOption = .brand
    @AppStorage(CardIntelligence.userDefaultsKey) private var useAppleIntelligence = true

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingArchived = false
    @State private var showingDrawingSettings = false

    var body: some View {
        NavigationStack {
            Form {
                permissionsSection
                displaySection
                intelligenceSection
                librarySection
                aboutSection
            }
            .navigationTitle(NSLocalizedString("settings_title", value: "Settings", comment: "Settings screen title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("done", value: "Done", comment: "Done button")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingArchived) { ArchivedCardsView() }
            .sheet(isPresented: $showingDrawingSettings) { DrawingPadSettingsView() }
            .task { await refreshNotificationStatus() }
            .onChange(of: scenePhase) { _, phase in
                // Pick up changes made in the iOS Settings app.
                if phase == .active { Task { await refreshNotificationStatus() } }
            }
        }
    }

    // MARK: Sections

    private var permissionsSection: some View {
        Section {
            HStack {
                Label(NSLocalizedString("settings_location", value: "Location", comment: ""), systemImage: "location.fill")
                Spacer()
                Text(locationStatusText).foregroundStyle(.secondary)
                if let action = locationActionTitle {
                    Button(action, action: locationAction).buttonStyle(.borderless)
                }
            }
            HStack {
                Label(NSLocalizedString("settings_notifications", value: "Notifications", comment: ""), systemImage: "bell.badge.fill")
                Spacer()
                Text(notificationStatusText).foregroundStyle(.secondary)
                if let action = notificationActionTitle {
                    Button(action, action: notificationAction).buttonStyle(.borderless)
                }
            }
        } header: {
            Text(NSLocalizedString("settings_arrival_alerts", value: "Arrival Alerts", comment: ""))
        } footer: {
            Text(NSLocalizedString("settings_arrival_footer",
                value: "CardOnCue shows the right card when you arrive at a saved location. That needs location set to Always and notifications on. Location never leaves your device.",
                comment: ""))
        }
    }

    private var displaySection: some View {
        Section(NSLocalizedString("settings_display", value: "Card List", comment: "")) {
            Picker(NSLocalizedString("sort_by", value: "Sort By", comment: ""), selection: $sortOption) {
                ForEach(CardSortOption.allCases) { Text($0.label).tag($0) }
            }
            Picker(NSLocalizedString("group_by", value: "Group By", comment: ""), selection: $groupOption) {
                ForEach(CardGroupOption.allCases) { Text($0.label).tag($0) }
            }
        }
    }

    private var intelligenceSection: some View {
        Section {
            if CardIntelligence.status == .available {
                Toggle(isOn: $useAppleIntelligence) {
                    Label(NSLocalizedString("settings_ai_toggle", value: "Smart Card Reading", comment: ""), systemImage: "sparkles")
                }
            } else {
                Label(intelligenceUnavailableText, systemImage: "sparkles")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(NSLocalizedString("settings_ai_header", value: "Apple Intelligence", comment: ""))
        } footer: {
            Text(NSLocalizedString("settings_ai_footer",
                value: "When you scan or import a card, Apple Intelligence reads the brand, cardholder, tier and expiry date. It runs entirely on this device.",
                comment: ""))
        }
    }

    private var librarySection: some View {
        Section {
            Button { showingArchived = true } label: {
                Label(NSLocalizedString("archived_cards", value: "Archived Cards", comment: ""), systemImage: "archivebox")
            }
            Button { showingDrawingSettings = true } label: {
                Label(NSLocalizedString("settings_drawing", value: "Icon Drawing Pad", comment: ""), systemImage: "pencil.tip.crop.circle")
            }
        }
        .tint(.primary)
    }

    private var aboutSection: some View {
        Section {
            Link(destination: URL(string: "https://cardoncue.com/support")!) {
                Label(NSLocalizedString("settings_support", value: "Help & Support", comment: ""), systemImage: "questionmark.circle")
            }
            Link(destination: URL(string: "https://cardoncue.com/privacy")!) {
                Label(NSLocalizedString("settings_privacy", value: "Privacy Policy", comment: ""), systemImage: "hand.raised")
            }
            Link(destination: URL(string: "https://cardoncue.com/terms")!) {
                Label(NSLocalizedString("settings_terms", value: "Terms of Use", comment: ""), systemImage: "doc.text")
            }
            Button {
                dismiss()
                onboardingService.resetOnboarding()
            } label: {
                Label(NSLocalizedString("settings_replay_onboarding", value: "Show Welcome Tour", comment: ""), systemImage: "sparkles")
            }
        } footer: {
            Text("CardOnCue \(appVersion)")
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        .tint(.primary)
    }

    // MARK: Location

    private var locationStatusText: String {
        switch geofenceManager.authorizationStatus {
        case .authorizedAlways: return NSLocalizedString("perm_always", value: "Always", comment: "")
        case .authorizedWhenInUse: return NSLocalizedString("perm_while_using", value: "While Using", comment: "")
        case .denied, .restricted: return NSLocalizedString("perm_off", value: "Off", comment: "")
        default: return ""
        }
    }

    private var locationActionTitle: String? {
        switch geofenceManager.authorizationStatus {
        case .notDetermined: return NSLocalizedString("perm_allow", value: "Allow", comment: "")
        case .authorizedAlways: return nil
        default: return NSLocalizedString("perm_change", value: "Change", comment: "")
        }
    }

    private func locationAction() {
        if geofenceManager.authorizationStatus == .notDetermined {
            geofenceManager.requestLocationPermission()
        } else {
            openAppSettings()
        }
    }

    // MARK: Notifications

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return NSLocalizedString("perm_on", value: "On", comment: "")
        case .denied: return NSLocalizedString("perm_off", value: "Off", comment: "")
        default: return ""
        }
    }

    private var notificationActionTitle: String? {
        switch notificationStatus {
        case .notDetermined: return NSLocalizedString("perm_allow", value: "Allow", comment: "")
        case .denied: return NSLocalizedString("perm_change", value: "Change", comment: "")
        default: return nil
        }
    }

    private func notificationAction() {
        guard notificationStatus == .notDetermined else { return openAppSettings() }
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            await refreshNotificationStatus()
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: Helpers

    private var intelligenceUnavailableText: String {
        switch CardIntelligence.status {
        case .notEnabled: return NSLocalizedString("ai_not_enabled", value: "Turn on Apple Intelligence in the Settings app to use smart card reading.", comment: "")
        case .notReady: return NSLocalizedString("ai_not_ready", value: "Apple Intelligence is still downloading. Check back soon.", comment: "")
        default: return NSLocalizedString("ai_unsupported", value: "Not available on this device. Cards are still read with on-device text recognition.", comment: "")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}

#Preview {
    SettingsView()
        .environmentObject(OnboardingService())
        .environmentObject(GeofenceManager.shared)
}
