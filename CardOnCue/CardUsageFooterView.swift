import SwiftUI
import SwiftData
import CoreLocation

/// Subtle, non-blocking footer shown under the barcode while a user is *using*
/// a card (view mode). Two low-friction signals:
///  1. "Did it scan?" thumbs feedback that expands into a "tell us more" note.
///  2. "This card works here" — one tap submits the current location to the
///     existing user-submitted-location approval queue.
struct CardUsageFooterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.apiClient) private var apiClient
    let card: CardModel

    private let keychainService = KeychainService()

    // Scan feedback
    private enum ScanPhase { case ask, responded, note, done }
    @State private var scanPhase: ScanPhase = .ask
    @State private var worked: Bool? = nil
    @State private var noteText: String = ""
    @State private var submissionId = UUID().uuidString
    @State private var scanFeedbackHidden: Bool

    // Works-here
    private enum ReportState { case idle, reporting, done }
    @State private var reportState: ReportState = .idle

    @State private var toastMessage: String?

    init(card: CardModel) {
        self.card = card
        // Don't nag: hide the thumbs once this card has already been rated.
        // ponytail: hide-once per card; revisit if we want periodic re-prompts
        _scanFeedbackHidden = State(
            initialValue: UserDefaults.standard.bool(forKey: "scanFeedback_\(card.id)")
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            if !scanFeedbackHidden {
                scanFeedbackRow
            }
            worksHereRow
            if let toastMessage {
                Text(toastMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.appLightGray, in: Capsule())
                    .transition(.opacity)
            }
        }
        .font(.footnote)
        .padding(.top, 4)
    }

    // MARK: - Scan feedback

    @ViewBuilder
    private var scanFeedbackRow: some View {
        switch scanPhase {
        case .ask:
            HStack(spacing: 16) {
                Text(NSLocalizedString("scan_feedback_prompt", comment: "Did the barcode scan?"))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    respond(worked: true)
                } label: {
                    Image(systemName: "hand.thumbsup.fill")
                        .foregroundStyle(Color.appGreen.opacity(0.6))
                }
                .accessibilityLabel(Text(NSLocalizedString("scan_feedback_yes", comment: "It scanned")))
                Button {
                    respond(worked: false)
                } label: {
                    Image(systemName: "hand.thumbsdown.fill")
                        .foregroundStyle(Color.red.opacity(0.5))
                }
                .accessibilityLabel(Text(NSLocalizedString("scan_feedback_no", comment: "It didn't scan")))
            }
            .buttonStyle(.plain)
        case .responded:
            HStack {
                Text(NSLocalizedString("scan_feedback_thanks", comment: "Thanks for the feedback"))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(NSLocalizedString("scan_feedback_more", comment: "Tell us more")) {
                    withAnimation { scanPhase = .note }
                }
            }
        case .note:
            HStack(spacing: 8) {
                TextField(
                    NSLocalizedString("scan_feedback_note_placeholder", comment: "What happened?"),
                    text: $noteText
                )
                .textFieldStyle(.roundedBorder)
                Button(NSLocalizedString("scan_feedback_send", comment: "Send")) {
                    sendNote()
                }
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        case .done:
            HStack {
                Text(NSLocalizedString("scan_feedback_thanks", comment: "Thanks for the feedback"))
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    private func respond(worked: Bool) {
        self.worked = worked
        submitFeedback(note: nil)
        withAnimation { scanPhase = .responded }
    }

    private func sendNote() {
        let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        submitFeedback(note: trimmed)
        withAnimation { scanPhase = .done }
    }

    /// Fire-and-forget. Uses a stable `submissionId` so the note upserts onto the
    /// same server row as the initial thumb tap.
    private func submitFeedback(note: String?) {
        guard let worked else { return }
        UserDefaults.standard.set(true, forKey: "scanFeedback_\(card.id)")
        let client = apiClient
        let sid = submissionId
        let cardId = card.id
        let barcodeType = card.barcodeType.rawValue
        let deviceId = AppUser.id
        Task {
            try? await client?.submitScanFeedback(
                submissionId: sid,
                deviceId: deviceId,
                cardId: cardId,
                barcodeType: barcodeType,
                worked: worked,
                note: note
            )
        }
    }

    // MARK: - Works-here

    private var worksHereRow: some View {
        Button {
            reportWorksHere()
        } label: {
            HStack(spacing: 6) {
                if reportState == .reporting {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: reportState == .done ? "checkmark.circle.fill" : "mappin.and.ellipse")
                }
                Text(reportState == .done
                     ? NSLocalizedString("card_works_here_done", comment: "Reported")
                     : NSLocalizedString("card_works_here", comment: "This card works here"))
                Spacer()
            }
            .foregroundStyle(reportState == .done ? Color.appGreen : Color.appBlue)
        }
        .buttonStyle(.plain)
        .disabled(reportState != .idle)
    }

    private func reportWorksHere() {
        reportState = .reporting
        let client = apiClient
        Task {
            guard let location = await OneShotLocation().current() else {
                showToast(NSLocalizedString("location_unavailable", comment: "Location unavailable"))
                reportState = .idle
                return
            }
            let (name, address) = await reverseGeocode(location)
            var reported = false
            if let client {
                do {
                    let serverCardId = try await CardServerSync.ensureServerCardId(
                        card: card,
                        apiClient: client,
                        keychainService: keychainService
                    )
                    _ = try await client.reportCardLocation(
                        cardId: serverCardId,
                        locationName: name,
                        address: address,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        notes: nil,
                        source: "card_location"
                    )
                    reported = true
                    PersistenceHelper.save(modelContext, label: "CardUsageFooter.worksHere")
                } catch {
                    print("⚠️ works-here report failed: \(error)")
                }
            }
            if reported {
                reportState = .done
                showToast(String(
                    format: NSLocalizedString("card_works_here_toast", comment: "Added <name> — thanks!"),
                    name
                ))
            } else {
                reportState = .idle
                showToast(NSLocalizedString("scan_feedback_submit_failed", comment: "Couldn't submit"))
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> (name: String, address: String?) {
        let fallback = NSLocalizedString("nearby_location", comment: "Nearby location")
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return (fallback, nil)
        }
        let name = placemark.name ?? placemark.thoroughfare ?? fallback
        var parts: [String] = []
        if let v = placemark.thoroughfare { parts.append(v) }
        if let v = placemark.locality { parts.append(v) }
        if let v = placemark.administrativeArea { parts.append(v) }
        if let v = placemark.postalCode { parts.append(v) }
        return (name, parts.isEmpty ? nil : parts.joined(separator: ", "))
    }

    // MARK: - Toast

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        Task {
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            await MainActor.run { withAnimation { toastMessage = nil } }
        }
    }
}

/// One-shot current-location fetch. Prefers GeofenceManager's cached fix (the app
/// already monitors location for geofencing); falls back to a single request.
@MainActor
private final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    func current() async -> CLLocation? {
        if let cached = GeofenceManager.shared.currentLocation,
           cached.timestamp.timeIntervalSinceNow > -300 {
            return cached
        }
        let status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            return GeofenceManager.shared.currentLocation
        }
        manager.delegate = self
        return await withCheckedContinuation { cont in
            self.continuation = cont
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let loc = locations.last
        Task { @MainActor in self.resume(with: loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.resume(with: GeofenceManager.shared.currentLocation) }
    }

    private func resume(with location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }
}
