import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct ContentView: View {
    @EnvironmentObject var notificationManager: WatchNotificationManager
    @State private var lastCardId: String?
    
    var body: some View {
        NavigationStack {
            if let card = notificationManager.currentCard {
                BarcodeDisplayView(card: card)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                EmptyStateView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WatchCardNotification"))) { notification in
            if let cardData = notification.userInfo?["card"] as? WatchCardDisplay {
                // Only update if it's a different card
                if lastCardId != cardData.id {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        notificationManager.currentCard = cardData
                    }
                    lastCardId = cardData.id
                    
                    // Haptic feedback for new card
                    #if os(watchOS)
                    WKInterfaceDevice.current().play(.notification)
                    #endif
                }
            }
        }
        .onAppear {
            // Try to restore last displayed card
            notificationManager.restoreLastCard()
            if let card = notificationManager.currentCard {
                lastCardId = card.id
            }
        }
    }
}

struct EmptyStateView: View {
    @State private var animateIcon = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                    .scaleEffect(animateIcon ? 1.1 : 1.0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animateIcon = true
                }
            }
            
            VStack(spacing: 8) {
                Text("CardOnCue")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Your card will appear here when you arrive at a location")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
            }
            
            // Hint text
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.system(size: 10))
                Text("Location-based")
                    .font(.system(size: 10))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.vertical, 20)
    }
}

