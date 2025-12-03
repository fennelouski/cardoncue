import SwiftUI
import SwiftData

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CardModel> { card in
        card.archivedAt == nil
    }, sort: \CardModel.createdAt, order: .reverse)
    private var cards: [CardModel]

    @StateObject private var cameraPermission = CameraPermissionManager()
    @State private var showingScanner = false
    @State private var showingManualEntry = false
    @State private var showingPermissionPrompt = false
    
    private var isCameraAvailable: Bool {
        cameraPermission.isCameraAvailable && cameraPermission.permissionStatus != .unavailable
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    EmptyStateView(
                        onScanCard: {
                            handleScanRequest()
                        },
                        onAddManually: {
                            showingManualEntry = true
                        },
                        canScan: isCameraAvailable && cameraPermission.permissionStatus != .denied
                    )
                } else {
                    cardListView
                        .navigationTitle(NSLocalizedString("my_cards", comment: "My Cards navigation title"))
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Menu {
                                    if isCameraAvailable && cameraPermission.permissionStatus != .denied {
                                        Button(action: {
                                            handleScanRequest()
                                        }) {
                                            Label(NSLocalizedString("scan_card", comment: "Scan card menu item"), systemImage: "camera.viewfinder")
                                        }
                                    }

                                    Button(action: {
                                        showingManualEntry = true
                                    }) {
                                        Label(NSLocalizedString("add_manually", comment: "Add manually menu item"), systemImage: "keyboard")
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .foregroundColor(.appPrimary)
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $showingPermissionPrompt) {
                CameraPermissionPromptView(
                    onPermissionGranted: {
                        cameraPermission.checkPermissionStatus()
                        showingScanner = true
                    },
                    onPermissionDenied: {
                        cameraPermission.markAsDenied()
                    }
                )
            }
            .sheet(isPresented: $showingScanner) {
                #if !os(visionOS)
                BarcodeScannerView()
                #endif
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView()
            }
        }
    }

    private var cardListView: some View {
        List {
            ForEach(cards) { card in
                NavigationLink(destination: CardDetailView(card: card)) {
                    CardRowView(card: card)
                }
                .listRowBackground(Color.appBackground)
            }
            .onDelete(perform: deleteCards)
        }
        .listStyle(.insetGrouped)
        .background(Color.appBackground)
        .scrollContentBackground(.hidden)
    }

    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            let card = cards[index]
            // Soft delete - set archivedAt instead of actually deleting
            card.archivedAt = Date()
            card.updatedAt = Date()
        }
    }

    private func handleScanRequest() {
        guard isCameraAvailable else {
            // Camera not available (e.g., on visionOS)
            return
        }
        
        switch cameraPermission.permissionStatus {
        case .granted:
            showingScanner = true
        case .notDetermined:
            showingPermissionPrompt = true
        case .denied, .restricted, .unavailable:
            // Camera access denied or unavailable, do nothing (button should be hidden)
            break
        }
    }
}

struct CardRowView: View {
    let card: CardModel

    var body: some View {
        HStack(spacing: 16) {
            // Card icon/type indicator
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appLightGray.opacity(0.2))
                    .frame(width: 50, height: 35)

                Image(systemName: barcodeIcon(for: card.barcodeType))
                    .foregroundColor(.appBlue)
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(.appBlue)

                if let locationName = card.locationName, !locationName.isEmpty {
                    Text(locationName)
                        .font(.caption)
                        .foregroundColor(.appLightGray)
                } else {
                    Text(card.barcodeType.displayName)
                        .font(.caption)
                        .foregroundColor(.appLightGray)
                }

                if let expiryInfo = card.expiryInfo {
                    Text(expiryInfo)
                        .font(.caption)
                        .foregroundColor(card.isExpired ? .red : .appGreen)
                }
            }

            Spacer()

            // Status indicators
            if card.isExpired {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
            } else if card.oneTime && card.usedAt != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appGreen)
                    .font(.system(size: 16))
            }
        }
        .padding(.vertical, 8)
    }

    private func barcodeIcon(for type: BarcodeType) -> String {
        switch type {
        case .qr:
            return "qrcode"
        case .code128, .ean13, .upcA:
            return "barcode"
        case .pdf417:
            return "doc.text"
        case .aztec:
            return "square.grid.2x2"
        case .code39, .itf:
            return "barcode"
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CardModel.self, configurations: config)

        return CardListView()
            .modelContainer(container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
