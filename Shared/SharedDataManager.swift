import Foundation

/// Manages shared data between the main app and widget extension via App Groups
/// Uses file-based storage in the container root for reliable sharing
enum SharedDataManager {
    private static let appGroupIdentifier = "2VBGUP463F.group.com.spypoint.widget"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private static var dataFileURL: URL? {
        containerURL?.appendingPathComponent("shared_data.json")
    }

    // MARK: - Shared Data Structure

    private struct SharedData: Codable {
        var token: String?
        var hasCredentials: Bool
        var widgetData: WidgetData?
    }

    // MARK: - File Operations

    private static func loadSharedData() -> SharedData {
        guard let url = dataFileURL else { return SharedData(hasCredentials: false) }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(SharedData.self, from: data)
        } catch {
            return SharedData(hasCredentials: false)
        }
    }

    private static func saveSharedData(_ sharedData: SharedData) {
        guard let url = dataFileURL else {
            print("SharedDataManager: No data file URL")
            return
        }

        do {
            let data = try JSONEncoder().encode(sharedData)
            try data.write(to: url, options: .atomic)
            // Set permissions to be readable by widget
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            print("SharedDataManager: Saved shared data (\(data.count) bytes)")
        } catch {
            print("SharedDataManager: Failed to save: \(error)")
        }
    }

    // MARK: - Widget Data

    static func saveWidgetData(_ data: WidgetData) {
        var shared = loadSharedData()
        shared.widgetData = data
        saveSharedData(shared)
    }

    static func loadWidgetData() -> WidgetData? {
        let shared = loadSharedData()
        if let data = shared.widgetData {
            print("SharedDataManager: Loaded \(data.photos.count) photos")
        }
        return shared.widgetData
    }

    // MARK: - Credentials Status

    static func setHasCredentials(_ hasCredentials: Bool) {
        var shared = loadSharedData()
        shared.hasCredentials = hasCredentials
        saveSharedData(shared)
    }

    static func hasCredentials() -> Bool {
        return loadSharedData().hasCredentials
    }

    // MARK: - Token

    static func saveToken(_ token: String) {
        var shared = loadSharedData()
        shared.token = token
        saveSharedData(shared)
    }

    static func loadToken() -> String? {
        return loadSharedData().token
    }

    static func clearToken() {
        guard let url = dataFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
