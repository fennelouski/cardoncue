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

/// How the main collection is rendered. `list` and multi-column choices are
/// only meaningful in a regular horizontal size class; compact width always
/// falls back to a single-column masonry grid.
enum CardLayoutStyle: String, CaseIterable, Identifiable {
    case grid, list
    var id: String { rawValue }
    var label: String {
        switch self {
        case .grid: return NSLocalizedString("layout_grid", value: "Grid", comment: "Layout option")
        case .list: return NSLocalizedString("layout_list", value: "List", comment: "Layout option")
        }
    }
    var symbol: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

struct CardListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CardModel> { card in
        card.archivedAt == nil
    }, sort: \CardModel.createdAt, order: .reverse)
    private var cards: [CardModel]

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var cameraPermission = CameraPermissionManager()
    @State private var showingAddCardView = false
    @State private var showingArchivedCards = false

    @AppStorage("cardSortOption") private var sortOption: CardSortOption = .recentlyAdded
    @AppStorage("cardGroupOption") private var groupOption: CardGroupOption = .brand

    // Layout preferences. `layoutStyle` toggles list vs. masonry grid (regular
    // width only). `gridColumns` is the user's chosen masonry column count;
    // 0 means "Auto" (derive from width). Both are ignored in compact width,
    // which is always forced to a single-column masonry grid.
    @AppStorage("cardLayoutStyle") private var layoutStyle: CardLayoutStyle = .grid
    @AppStorage("cardGridColumns") private var gridColumns: Int = 0

    /// iPad, or a large iPhone in landscape — where multi-column / list are allowed.
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    /// Effective style: compact width can never be a list.
    private var effectiveLayoutStyle: CardLayoutStyle {
        isRegularWidth ? layoutStyle : .grid
    }

    /// Column count passed to `MasonryLayout`. Compact width is always a single
    /// column; in regular width `nil` lets the layout auto-derive from width.
    private var masonryColumns: Int? {
        guard isRegularWidth else { return 1 }
        return gridColumns == 0 ? nil : min(4, max(1, gridColumns))
    }

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
                                if isRegularWidth {
                                    ToolbarItem(placement: .navigationBarTrailing) {
                                        layoutMenu
                                    }
                                }
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

    // Layout switcher — only shown in regular width (see toolbar gating). Lets
    // the user pick list vs. masonry grid and, for the grid, a column count.
    private var layoutMenu: some View {
        Menu {
            Picker(NSLocalizedString("layout", value: "Layout", comment: "Layout menu title"), selection: $layoutStyle) {
                ForEach(CardLayoutStyle.allCases) { style in
                    Label(style.label, systemImage: style.symbol).tag(style)
                }
            }
            if effectiveLayoutStyle == .grid {
                Picker(NSLocalizedString("columns", value: "Columns", comment: "Column count menu title"), selection: $gridColumns) {
                    Text(NSLocalizedString("columns_auto", value: "Auto", comment: "Automatic column count")).tag(0)
                    ForEach(1...4, id: \.self) { count in
                        Text("\(count)").tag(count)
                    }
                }
            }
        } label: {
            Image(systemName: effectiveLayoutStyle.symbol)
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
                    if effectiveLayoutStyle == .list {
                        VStack(spacing: 10) {
                            ForEach(group.cards) { card in
                                NavigationLink(destination: CardDetailView(card: card)) {
                                    CardRowView(card: card) { archive(card) }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        MasonryLayout(columns: masonryColumns, spacing: 12) {
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

// MARK: - Card Row (list layout)

/// Compact single-line-per-card row used by the iPad "List" layout. Mirrors the
/// data shown by `CardCellView` but in a horizontal, list-friendly arrangement.
struct CardRowView: View {
    let card: CardModel
    var onArchive: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.appLightGray.opacity(0.25))
                    .frame(width: 44, height: 44)

                CardIconDisplay(
                    icon: card.getIcon() ?? CardIcon.sfSymbol(barcodeIcon(for: card.barcodeType)),
                    size: card.getIcon()?.type == .image ? 42 : 28
                )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(.appBlue)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.appLightGray)
                    .lineLimit(1)

                if let expiryInfo = card.expiryInfo {
                    Text(expiryInfo)
                        .font(.caption)
                        .foregroundColor(card.isExpired ? .red : .appGreen)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            trailingBadges
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [card.themeTint.opacity(0.20), card.themeTint.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.appBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(card.themeTint.opacity(0.30), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive, action: onArchive) {
                Label(
                    NSLocalizedString("archive", value: "Archive", comment: "Archive card action"),
                    systemImage: "archivebox"
                )
            }
        }
    }

    private var trailingBadges: some View {
        HStack(spacing: 5) {
            ForEach(Array(card.categories.prefix(3)), id: \.self) { category in
                Image(systemName: category.sfSymbol)
                    .font(.system(size: 11))
                    .foregroundColor(category.tint)
            }

            if card.isExpired {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
            } else if card.oneTime && card.usedAt != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appGreen)
                    .font(.system(size: 14))
            }
        }
    }

    private var subtitle: String {
        if let cardholder = card.cardholderName {
            return cardholder
        } else if let locationName = card.locationName, !locationName.isEmpty {
            return locationName
        } else {
            return card.barcodeType.displayName
        }
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
