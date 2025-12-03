import SwiftUI

struct ContentView: View {
    @EnvironmentObject var notificationManager: WatchNotificationManager
    
    var body: some View {
        NavigationStack {
            if let card = notificationManager.currentCard {
                BarcodeDisplayView(card: card)
            } else {
                EmptyStateView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WatchCardNotification"))) { notification in
            if let cardData = notification.userInfo?["card"] as? WatchCardDisplay {
                notificationManager.currentCard = cardData
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("CardOnCue")
                .font(.headline)
            
            Text("Your card will appear here when you arrive at a location")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

