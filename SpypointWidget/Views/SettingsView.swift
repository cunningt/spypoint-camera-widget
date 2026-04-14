import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("refreshInterval") private var refreshInterval = 300
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true

    var body: some View {
        Form {
            Section {
                Picker("Refresh Interval", selection: $refreshInterval) {
                    Text("1 minute").tag(60)
                    Text("5 minutes").tag(300)
                    Text("15 minutes").tag(900)
                    Text("30 minutes").tag(1800)
                    Text("1 hour").tag(3600)
                }

                Toggle("Enable Notifications", isOn: $notificationsEnabled)
            } header: {
                Text("General")
            }

            Section {
                if appState.isLoggedIn {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text("Connected")
                            .foregroundColor(.green)
                    }

                    if let email = KeychainHelper.load(key: .email) {
                        HStack {
                            Text("Account")
                            Spacer()
                            Text(email)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button("Logout", role: .destructive) {
                        appState.logout()
                    }
                } else {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text("Not connected")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Account")
            }

            Section {
                Text("Spypoint Widget v1.0.0")
                    .foregroundColor(.secondary)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
    }
}
