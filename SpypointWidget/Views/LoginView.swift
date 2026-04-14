import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo/Title
            VStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Spypoint Widget")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Connect to your trail cameras")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Login Form
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.emailAddress)
                    .disabled(appState.isLoading)

                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.password)
                    .disabled(appState.isLoading)
                    .onSubmit {
                        login()
                    }

                if let error = appState.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: login) {
                    if appState.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || password.isEmpty || appState.isLoading)
            }
            .frame(maxWidth: 280)

            Spacer()

            Text("Your credentials are stored securely in the Keychain")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .padding(32)
        .onAppear {
            // Load saved email if available
            if let savedEmail = KeychainHelper.load(key: .email) {
                email = savedEmail
            }
        }
    }

    func login() {
        Task {
            await appState.login(email: email, password: password)
        }
    }
}
