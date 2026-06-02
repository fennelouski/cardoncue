import SwiftUI
import SwiftData

struct ArchivedCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<CardModel> { card in
        card.archivedAt != nil
    }, sort: \CardModel.archivedAt, order: .reverse)
    private var archivedCards: [CardModel]

    @State private var showingPermanentDeleteConfirm = false
    @State private var cardToDelete: CardModel?

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if archivedCards.isEmpty {
                    ContentUnavailableView(
                        "No Archived Cards",
                        systemImage: "archivebox",
                        description: Text("Cards you remove will appear here so you can restore them.")
                    )
                } else {
                    List {
                        ForEach(archivedCards) { card in
                            HStack(spacing: 12) {
                                Image(systemName: card.iconName ?? "creditcard")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.name)
                                        .font(.body)
                                    if let date = card.archivedAt {
                                        Text("Archived \(dateFormatter.string(from: date))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Button("Restore") {
                                    restoreCard(card)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    cardToDelete = card
                                    showingPermanentDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    restoreCard(card)
                                } label: {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Archived Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Permanently Delete?", isPresented: $showingPermanentDeleteConfirm) {
                Button("Cancel", role: .cancel) { cardToDelete = nil }
                Button("Delete Forever", role: .destructive) {
                    if let card = cardToDelete {
                        modelContext.delete(card)
                        PersistenceHelper.save(modelContext, label: "ArchivedCardsView.delete")
                        cardToDelete = nil
                    }
                }
            } message: {
                Text("This cannot be undone. The card and all its data will be removed.")
            }
        }
    }

    private func restoreCard(_ card: CardModel) {
        card.archivedAt = nil
        PersistenceHelper.save(modelContext, label: "ArchivedCardsView.restore")
    }
}
