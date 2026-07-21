import SwiftUI
import SwiftData

// MARK: - Sort & Group options

enum CardSortOption: String, CaseIterable, Identifiable {
    case recentlyAdded, nameAtoZ, expiringSoon, recentlyUsed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .recentlyAdded: return NSLocalizedString("sort_recently_added", value: "Recently Added", comment: "Sort option")
        case .nameAtoZ:      return NSLocalizedString("sort_name", value: "Name (A–Z)", comment: "Sort option")
        case .expiringSoon:  return NSLocalizedString("sort_expiring", value: "Expiring Soon", comment: "Sort option")
        case .recentlyUsed:  return NSLocalizedString("sort_recently_used", value: "Recently Used", comment: "Sort option")
        }
    }
}

enum CardGroupOption: String, CaseIterable, Identifiable {
    case brand, category, none
    var id: String { rawValue }
    var label: String {
        switch self {
        case .brand:    return NSLocalizedString("group_brand", value: "Brand", comment: "Group option")
        case .category: return NSLocalizedString("group_category", value: "Category", comment: "Group option")
        case .none:     return NSLocalizedString("group_none", value: "None", comment: "Group option")
        }
    }
}

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CardModel> { card in
        card.archivedAt == nil
    }, sort: \CardModel.createdAt, order: .reverse)
    private var cards: [CardModel]

    @StateObject private var cameraPermission = CameraPermissionManager()
    @State private var showingAddCardView = false
    @State private var showingArchivedCards = false

    @AppStorage("cardSortOption") private var sortOption: CardSortOption = .recentlyAdded
    @AppStorage("cardGroupOption") private var groupOption: CardGroupOption = .brand

    private var isCameraAvailable: Bool {
        cameraPermission.isCameraAvailable && cameraPermission.permissionStatus != .unavailable
    }

    private var otherLabel: String {
        NSLocalizedString("group_other", value: "Other", comment: "Fallback group name")
    }

    // MARK: Sorting

    private func sortedCards(_ cards: [CardModel]) -> [CardModel] {
        switch sortOption {
        case .recentlyAdded:
            return cards.sorted { $0.createdAt > $1.createdAt }
        case .nameAtoZ:
            return cards.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .expiringSoon:
            return cards.sorted { lhs, rhs in
                switch (lhs.validTo, rhs.validTo) {
                case let (l?, r?): return l < r
                case (_?, nil):    return true
                case (nil, _?):    return false
                case (nil, nil):   return lhs.createdAt > rhs.createdAt
                }
            }
        case .recentlyUsed:
            return cards.sorted { lhs, rhs in
                switch (lhs.usedAt, rhs.usedAt) {
                case let (l?, r?): return l > r
                case (_?, nil):    return true
                case (nil, _?):    return false
                case (nil, nil):   return lhs.createdAt > rhs.createdAt
                }
            }
        }
    }

    // MARK: Grouping

    // Grouped, sorted cards honoring the selected sort + group options.
    // Group order is stable (alphabetical, "Other" last); within-group order
    // follows the chosen sort.
    private var groupedCards: [(key: String, title: String, cards: [CardModel])] {
        let sorted = sortedCards(cards)
        switch groupOption {
        case .none:
            return sorted.isEmpty ? [] : [(key: "all", title: "", cards: sorted)]
        case .brand:
            return brandGroups(sorted)
        case .category:
            return categoryGroups(sorted)
        }
    }

    private func brandGroups(_ sorted: [CardModel]) -> [(key: String, title: String, cards: [CardModel])] {
        let grouped = Dictionary(grouping: sorted) { $0.groupKey }
        var groups = grouped.map { (key, cards) -> (key: String, title: String, cards: [CardModel]) in
            let title = cards.first(where: { $0.brandName != "Other" })?.brandName
                ?? cards.first?.brandName
                ?? "Other"
            return (key, title, cards)
        }
        groups.sort { lhs, rhs in
            if lhs.title == "Other" { return false }
            if rhs.title == "Other" { return true }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return groups
    }

    private func categoryGroups(_ sorted: [CardModel]) -> [(key: String, title: String, cards: [CardModel])] {
        let other = otherLabel
        let grouped = Dictionary(grouping: sorted) { $0.categories.first?.label ?? other }
        var groups = grouped.map { (label, cards) -> (key: String, title: String, cards: [CardModel]) in
            (label, label, cards)
        }
        groups.sort { lhs, rhs in
            if lhs.title == other { return false }
            if rhs.title == other { return true }
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedGradientBackground()

                Group {
                    if cards.isEmpty {
                        EmptyStateView(
                            onAddCard: { showingAddCardView = true },
                            canScan: isCameraAvailable && cameraPermission.permissionStatus != .denied
                        )
                    } else {
                        cardGrid
                            .navigationTitle(NSLocalizedString("my_cards", comment: "My Cards navigation title"))
                            .navigationBarTitleDisplayMode(.large)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    sortGroupMenu
                                }
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button(action: { showingAddCardView = true }) {
                                        Image(systemName: "plus")
                                            .foregroundColor(.appPrimary)
                                    }
                                }
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button(action: { showingArchivedCards = true }) {
                                        Image(systemName: "archivebox")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                    }
                }
            }
            .sheet(isPresented: $showingAddCardView) {
                AddCardSwipeableView(
                    canScan: isCameraAvailable && cameraPermission.permissionStatus != .denied
                )
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingArchivedCards) {
                ArchivedCardsView()
            }
        }
        .onAppear {
            GeofenceManager.shared.syncCardsToWatch()
        }
        .onChange(of: cards.map(\.updatedAt)) {
            GeofenceManager.shared.syncCardsToWatch()
        }
    }

    private var sortGroupMenu: some View {
        Menu {
            Picker(NSLocalizedString("sort_by", value: "Sort By", comment: "Sort menu title"), selection: $sortOption) {
                ForEach(CardSortOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            Picker(NSLocalizedString("group_by", value: "Group By", comment: "Group menu title"), selection: $groupOption) {
                ForEach(CardGroupOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundColor(.appPrimary)
        }
    }

    private var cardGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(groupedCards, id: \.key) { group in
                    if !group.title.isEmpty {
                        BrandSectionHeader(brandName: group.title, cardCount: group.cards.count)
                            .padding(.horizontal)
                    }
                    MasonryLayout(spacing: 12) {
                        ForEach(group.cards) { card in
                            NavigationLink(destination: CardDetailView(card: card)) {
                                CardCellView(card: card) { archive(card) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    private func archive(_ card: CardModel) {
        // Soft delete - set archivedAt instead of actually deleting
        card.archivedAt = Date()
        card.updatedAt = Date()
        PersistenceHelper.save(modelContext, label: "CardListView.archive")
    }
}

// MARK: - Brand Section Header
struct BrandSectionHeader: View {
    let brandName: String
    let cardCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(brandName)
                .font(.headline)
                .foregroundColor(.primary)

            Text("(\(cardCount))")
                .font(.subheadline)
                .foregroundColor(.secondary)
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
