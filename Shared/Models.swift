import Foundation

// MARK: - API Response Models

struct LoginResponse: Codable {
    let token: String
    let uuid: String
}

struct Camera: Codable, Identifiable {
    let id: String
    let name: String?
    let config: CameraConfig?
    let status: CameraStatus?
    let subscriptions: [Subscription]?
    let lastUpdateTime: String?

    var displayName: String {
        name ?? config?.name ?? "Unnamed Camera"
    }

    var batteryPercentage: Int? {
        if let percentage = status?.powerSources?.first?.percentage {
            return percentage
        }
        return status?.batteries?.first
    }

    var signalBars: Int? {
        if let bar = status?.signal?.bar {
            return bar
        }
        if let bars = status?.signal?.bars {
            return bars
        }
        return status?.signal?.processed?.bar
    }

    var signalType: String? {
        status?.signal?.type ?? status?.signal?.processed?.type
    }

    var photoCount: Int {
        subscriptions?.first?.photoCount ?? 0
    }

    var photoLimit: Int {
        subscriptions?.first?.photoLimit ?? 100
    }

    var isOnline: Bool {
        guard let lastUpdate = lastUpdateTime ?? status?.lastUpdate else { return false }
        guard let date = ISO8601DateFormatter().date(from: lastUpdate) else { return false }
        let hoursSince = Date().timeIntervalSince(date) / 3600
        return hoursSince < 24
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, config, status, subscriptions, lastUpdateTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try _id first, then id
        if let id = try? container.decode(String.self, forKey: .id) {
            self.id = id
        } else {
            let altContainer = try decoder.container(keyedBy: AlternateKeys.self)
            self.id = try altContainer.decode(String.self, forKey: .id)
        }
        self.name = try? container.decode(String.self, forKey: .name)
        self.config = try? container.decode(CameraConfig.self, forKey: .config)
        self.status = try? container.decode(CameraStatus.self, forKey: .status)
        self.subscriptions = try? container.decode([Subscription].self, forKey: .subscriptions)
        self.lastUpdateTime = try? container.decode(String.self, forKey: .lastUpdateTime)
    }

    private enum AlternateKeys: String, CodingKey {
        case id
    }
}

struct CameraConfig: Codable {
    let name: String?
}

struct CameraStatus: Codable {
    let powerSources: [PowerSource]?
    let batteries: [Int]?
    let signal: Signal?
    let memory: Memory?
    let lastUpdate: String?
}

struct PowerSource: Codable {
    let percentage: Int?
}

struct Signal: Codable {
    let bar: Int?
    let bars: Int?
    let type: String?
    let processed: SignalProcessed?
}

struct SignalProcessed: Codable {
    let bar: Int?
    let type: String?
}

struct Memory: Codable {
    let used: Int?
    let size: Int?
}

struct Subscription: Codable {
    let photoCount: Int?
    let photoLimit: Int?
}

struct Photo: Codable, Identifiable {
    let id: String
    let camera: String?
    let cameraName: String?
    let date: String?
    let tags: [String]?
    let species: [String]?
    let small: PhotoSize?
    let medium: PhotoSize?
    let large: PhotoSize?
    let originPhoto: PhotoSize?
    let video: Bool?

    var displayDate: Date? {
        guard let dateString = date else { return nil }
        return ISO8601DateFormatter().date(from: dateString)
    }

    var imageURL: URL? {
        let size = originPhoto ?? large ?? medium ?? small
        guard let host = size?.host, let path = size?.path else { return nil }
        return URL(string: "https://\(host)/\(path)")
    }

    var largeURL: URL? {
        let size = large ?? originPhoto ?? medium ?? small
        guard let host = size?.host, let path = size?.path else { return nil }
        return URL(string: "https://\(host)/\(path)")
    }

    var mediumURL: URL? {
        let size = medium ?? large ?? small
        guard let host = size?.host, let path = size?.path else { return nil }
        return URL(string: "https://\(host)/\(path)")
    }

    var thumbnailURL: URL? {
        let size = small ?? medium ?? large
        guard let host = size?.host, let path = size?.path else { return nil }
        return URL(string: "https://\(host)/\(path)")
    }

    var displayTags: [String] {
        tags ?? species ?? []
    }

    var isVideo: Bool {
        video ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case camera, cameraName, date, tags, species, small, medium, large, originPhoto, video
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let id = try? container.decode(String.self, forKey: .id) {
            self.id = id
        } else {
            let altContainer = try decoder.container(keyedBy: AlternateKeys.self)
            self.id = try altContainer.decode(String.self, forKey: .id)
        }
        self.camera = try? container.decode(String.self, forKey: .camera)
        self.cameraName = try? container.decode(String.self, forKey: .cameraName)
        self.date = try? container.decode(String.self, forKey: .date)
        self.tags = try? container.decode([String].self, forKey: .tags)
        self.species = try? container.decode([String].self, forKey: .species)
        self.small = try? container.decode(PhotoSize.self, forKey: .small)
        self.medium = try? container.decode(PhotoSize.self, forKey: .medium)
        self.large = try? container.decode(PhotoSize.self, forKey: .large)
        self.originPhoto = try? container.decode(PhotoSize.self, forKey: .originPhoto)
        self.video = try? container.decode(Bool.self, forKey: .video)
    }

    private enum AlternateKeys: String, CodingKey {
        case id
    }
}

struct PhotoSize: Codable {
    let host: String?
    let path: String?
    let url: String?
}

// MARK: - API Request Models

struct PhotosRequest: Codable {
    let cameras: [String]
    let dateEnd: String
    let limit: Int
}

// MARK: - Widget Data Model

struct CachedPhoto: Codable, Identifiable {
    let id: String
    let imageData: Data
    let cameraName: String?
}

struct WidgetData: Codable {
    let cameras: [Camera]
    let photos: [Photo]
    let cachedPhotos: [CachedPhoto]
    let lastUpdate: Date

    static var empty: WidgetData {
        WidgetData(cameras: [], photos: [], cachedPhotos: [], lastUpdate: Date.distantPast)
    }

    init(cameras: [Camera], photos: [Photo], cachedPhotos: [CachedPhoto] = [], lastUpdate: Date) {
        self.cameras = cameras
        self.photos = photos
        self.cachedPhotos = cachedPhotos
        self.lastUpdate = lastUpdate
    }
}
