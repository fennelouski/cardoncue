import SwiftUI

struct IconSelectionSheet: View {
    let card: CardModel
    @Binding var selectedIcon: CardIcon?
    @State private var autoIcon: CardIcon?
    
    var body: some View {
        Group {
            if let autoIcon = autoIcon {
                IconSelectionView(
                    selectedIcon: $selectedIcon,
                    card: card,
                    autoIcon: autoIcon
                )
            } else {
                ProgressView()
                    .onAppear {
                        loadAutoIcon()
                    }
            }
        }
    }
    
    private func loadAutoIcon() {
        Task {
            let iconName = await CardIconService.shared.assignIconForCard(
                name: card.name,
                locationName: card.locationName
            )
            await MainActor.run {
                autoIcon = CardIcon.sfSymbol(iconName)
            }
        }
    }
}

