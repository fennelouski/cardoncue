import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var storageService: StorageService
    @Environment(\.clerk) private var clerk
    @AppStorage("hasSkippedAuth") private var hasSkippedAuth = false

    var body: some View {
        NavigationStack {
            List {
                // Trash Section
                Section {
                    NavigationLink(destination: TrashView()) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                                .frame(width: 24)

                            Text("Trash")
                                .foregroundColor(.appBlue)

                            Spacer()

                            if storageService.deletedCardsCount > 0 {
                                Text("\(storageService.deletedCardsCount)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                } header: {
                    Text("Storage")
                }

                // Account Section
                Section {
                    if let user = clerk.user {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.fullName ?? user.emailAddress ?? "User")
                                .font(.headline)
                                .foregroundColor(.appBlue)

                            if let email = user.emailAddress {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.appLightGray)
                            }
                        }
                        .padding(.vertical, 4)

                        Button(action: {
                            Task {
                                try? await clerk.signOut()
                            }
                        }) {
                            Text("Sign Out")
                                .foregroundColor(.red)
                        }
                    } else if hasSkippedAuth {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Not Signed In")
                                .font(.headline)
                                .foregroundColor(.appBlue)

                            Text("Sign in to sync your cards across devices")
                                .font(.caption)
                                .foregroundColor(.appLightGray)
                        }
                        .padding(.vertical, 4)

                        Button(action: {
                            hasSkippedAuth = false
                        }) {
                            Text("Sign In")
                                .foregroundColor(.appPrimary)
                        }
                    }
                } header: {
                    Text("Account")
                }

                // App Info Section
                Section {
                    HStack {
                        Text("Version")
                            .foregroundColor(.appBlue)
                        Spacer()
                        Text(Bundle.main.appVersion)
                            .foregroundColor(.appLightGray)
                    }

                    HStack {
                        Text("Build")
                            .foregroundColor(.appBlue)
                        Spacer()
                        Text(Bundle.main.appBuild)
                            .foregroundColor(.appLightGray)
                    }
                } header: {
                    Text("About")
                }
            }
            .listStyle(.insetGrouped)
            .background(Color.appBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var appBuild: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

#Preview {
    SettingsView()
        .environmentObject(StorageService(keychainService: KeychainService()))
        .environment(\.clerk, Clerk.shared)
}
