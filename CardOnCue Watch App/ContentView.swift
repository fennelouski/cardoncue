import SwiftUI

struct ContentView: View {
    @EnvironmentObject var notificationManager: WatchNotificationManager
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if notificationManager.cards.isEmpty {
                    EmptyStateView()
                } else {
                    List(notificationManager.cards) { card in
                        NavigationLink(value: card.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(card.cardName)
                                    .font(.headline)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text(card.barcodeType.uppercased())
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    if let locationName = card.locationName, !locationName.isEmpty {
                                        Text("• \(locationName)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.carousel)
                }
            }
            .navigationTitle("Cards")
            .navigationDestination(for: String.self) { cardId in
                if let card = notificationManager.cards.first(where: { $0.id == cardId }) {
                    BarcodeDisplayView(card: card)
                } else {
                    EmptyStateView()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WatchCardNotification"))) { notification in
            if let cardData = notification.userInfo?["card"] as? WatchCardDisplay {
                notificationManager.selectCard(cardData)
                path = NavigationPath()
                path.append(cardData.id)
            }
        }
        .onAppear {
            notificationManager.restoreCards()
            notificationManager.restoreLastCard()
            if let currentCard = notificationManager.currentCard {
                path = NavigationPath()
                path.append(currentCard.id)
            }
        }
    }
}

struct EmptyStateView: View {
    @State private var animateIcon = false
    @State private var animatePulse = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Animated icon with improved design
            ZStack {
                // Outer pulse ring
                Circle()
                    .stroke(Color.watchPrimary.opacity(0.3), lineWidth: 2)
                    .frame(width: 70, height: 70)
                    .scaleEffect(animatePulse ? 1.2 : 1.0)
                    .opacity(animatePulse ? 0 : 1)
                
                // Middle ring
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.watchPrimary.opacity(0.2), Color.watchPrimary.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                
                // Icon
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.watchPrimary)
                    .scaleEffect(animateIcon ? 1.05 : 1.0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    animateIcon = true
                }
                withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                    animatePulse = true
                }
            }
            
            VStack(spacing: 10) {
                Text("CardOnCue")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Your card will appear here when you arrive at a location")
                    .font(.system(size: 13, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
                    .lineSpacing(2)
            }
            
            // Location badge with improved design
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11))
                Text("Location-based")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.watchInfo)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.watchInfo.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(Color.watchInfo.opacity(0.3), lineWidth: 0.5)
            )
            
            // Additional helpful hint
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 10))
                    Text("Notifications enabled")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.watchSuccess.opacity(0.9))
                
                Text("You'll receive a notification when you're near a saved location")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
    }
}

