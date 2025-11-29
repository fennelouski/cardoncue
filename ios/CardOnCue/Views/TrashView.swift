import SwiftUI

struct TrashView: View {
    @EnvironmentObject var storageService: StorageService
    @State private var showingEmptyTrashAlert = false
    @State private var selectedCard: DeletedCard?
    @State private var showingPermanentDeleteAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if storageService.deletedCards.isEmpty {
                    emptyTrashView
                } else {
                    deletedCardsList
                }
            }
            .navigationTitle("Trash")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !storageService.deletedCards.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingEmptyTrashAlert = true
                        }) {
                            Text("Empty")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .alert("Empty Trash", isPresented: $showingEmptyTrashAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Empty Trash", role: .destructive) {
                    storageService.emptyTrash()
                }
            } message: {
                Text("All deleted cards will be permanently removed. This action cannot be undone.")
            }
            .alert("Permanently Delete Card", isPresented: $showingPermanentDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    selectedCard = nil
                }
                Button("Delete Permanently", role: .destructive) {
                    if let card = selectedCard {
                        storageService.permanentlyDeleteCard(card)
                        selectedCard = nil
                    }
                }
            } message: {
                Text("This card will be permanently deleted. This action cannot be undone.")
            }
        }
    }

    private var emptyTrashView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash")
                .font(.system(size: 64))
                .foregroundColor(.appLightGray)

            Text("Trash is Empty")
                .font(.title2)
                .foregroundColor(.appBlue)

            Text("Deleted cards will appear here and be kept for 7 days before being permanently removed.")
                .font(.body)
                .foregroundColor(.appLightGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private var deletedCardsList: some View {
        List {
            ForEach(storageService.deletedCards) { deletedCard in
                DeletedCardRowView(deletedCard: deletedCard)
                    .listRowBackground(Color.appBackground)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            storageService.restoreCard(deletedCard)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.appGreen)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            selectedCard = deletedCard
                            showingPermanentDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color.appBackground)
        .scrollContentBackground(.hidden)
    }
}

struct DeletedCardRowView: View {
    let deletedCard: DeletedCard

    var body: some View {
        HStack(spacing: 16) {
            // Card icon/type indicator
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appLightGray.opacity(0.2))
                    .frame(width: 50, height: 35)

                Image(systemName: barcodeIcon(for: deletedCard.card.barcodeType))
                    .foregroundColor(.appLightGray)
                    .font(.system(size: 16))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(deletedCard.card.name)
                    .font(.headline)
                    .foregroundColor(.appBlue)

                Text(deletedCard.card.barcodeType.displayName)
                    .font(.caption)
                    .foregroundColor(.appLightGray)

                if deletedCard.daysUntilPermanentDeletion > 0 {
                    Text("Deletes in \(deletedCard.daysUntilPermanentDeletion) day\(deletedCard.daysUntilPermanentDeletion == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    Text("Deleting soon")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            Spacer()

            // Trash indicator
            Image(systemName: "trash.fill")
                .foregroundColor(.appLightGray.opacity(0.5))
                .font(.system(size: 16))
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
    TrashView()
        .environmentObject(StorageService(keychainService: KeychainService()))
}
