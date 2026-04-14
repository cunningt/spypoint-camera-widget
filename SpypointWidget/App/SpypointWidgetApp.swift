import SwiftUI
import AppKit
import WidgetKit

@main
struct SpypointWidgetApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .background(WindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// Hide the traffic light buttons
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                // Hide traffic light buttons
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true

                // Make it float like a widget
                window.level = .floating
                window.isMovableByWindowBackground = true
                window.backgroundColor = .clear
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
class AppState: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var cameras: [Camera] = []
    @Published var photos: [Photo] = []
    @Published var lastRefresh: Date?

    private var refreshTimer: Timer?

    init() {
        // Check for saved credentials
        if let token = SharedDataManager.loadToken() {
            Task {
                await SpypointAPI.shared.setToken(token)
                isLoggedIn = true
                await refresh()
            }
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let response = try await SpypointAPI.shared.login(email: email, password: password)

            // Save credentials
            try? KeychainHelper.save(email, for: .email)
            try? KeychainHelper.save(password, for: .password)
            SharedDataManager.saveToken(response.token)
            SharedDataManager.setHasCredentials(true)

            isLoggedIn = true
            await refresh()
            startAutoRefresh()

            // Tell widget to refresh
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func logout() {
        KeychainHelper.deleteAll()
        SharedDataManager.clearToken()
        SharedDataManager.setHasCredentials(false)

        Task {
            await SpypointAPI.shared.setToken(nil)
        }

        isLoggedIn = false
        cameras = []
        photos = []
        stopAutoRefresh()
    }

    func refresh() async {
        isLoading = true
        error = nil

        do {
            let data = try await SpypointAPI.shared.fetchAllData()
            cameras = data.cameras
            photos = data.photos
            lastRefresh = Date()

            // Download and cache images for widget (first 7 photos for large widget)
            var cachedPhotos: [CachedPhoto] = []
            for photo in data.photos.prefix(7) {
                // Prefer large images for better quality
                if let url = photo.largeURL ?? photo.originPhoto?.url.flatMap({ URL(string: $0) }) ?? photo.mediumURL {
                    do {
                        let (imageData, _) = try await URLSession.shared.data(from: url)
                        print("Cached image \(photo.id): \(imageData.count) bytes from \(url.lastPathComponent)")
                        cachedPhotos.append(CachedPhoto(
                            id: photo.id,
                            imageData: imageData,
                            cameraName: photo.cameraName
                        ))
                    } catch {
                        print("Failed to cache image: \(error)")
                    }
                }
            }
            print("Total cached photos: \(cachedPhotos.count)")

            // Save for widget with cached images
            let widgetData = WidgetData(
                cameras: data.cameras,
                photos: data.photos,
                cachedPhotos: cachedPhotos,
                lastUpdate: Date()
            )
            SharedDataManager.saveWidgetData(widgetData)
            WidgetCenter.shared.reloadAllTimelines()
        } catch let apiError as APIError {
            if case .unauthorized = apiError {
                logout()
            }
            error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
