import SwiftUI

@main
struct CardOnCueWatchApp: App {
    @StateObject private var notificationManager = WatchNotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(notificationManager)
                .onAppear {
                    notificationManager.requestNotificationPermission()
                }
        }
    }
}

