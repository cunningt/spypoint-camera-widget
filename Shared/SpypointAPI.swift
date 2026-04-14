import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Invalid credentials"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data error: \(error.localizedDescription)"
        }
    }
}

actor SpypointAPI {
    static let shared = SpypointAPI()

    private let baseURL = "https://restapi.spypoint.com"
    private var token: String?

    private init() {}

    func setToken(_ token: String?) {
        self.token = token
    }

    func getToken() -> String? {
        return token
    }

    // MARK: - Authentication

    func login(email: String, password: String) async throws -> LoginResponse {
        let url = URL(string: "\(baseURL)/api/v3/user/login")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["username": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        do {
            let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
            self.token = loginResponse.token
            return loginResponse
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Cameras

    func fetchCameras() async throws -> [Camera] {
        guard let token = token else {
            throw APIError.unauthorized
        }

        let url = URL(string: "\(baseURL)/api/v3/camera/all")!

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        do {
            // Try parsing as array first
            if let cameras = try? JSONDecoder().decode([Camera].self, from: data) {
                return cameras
            }

            // Try parsing as object with cameras key
            struct CamerasResponse: Codable {
                let cameras: [Camera]?
                let camera: [Camera]?
            }

            let response = try JSONDecoder().decode(CamerasResponse.self, from: data)
            return response.cameras ?? response.camera ?? []
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Photos

    func fetchPhotos(cameraIds: [String], limit: Int = 24) async throws -> [Photo] {
        guard let token = token else {
            throw APIError.unauthorized
        }

        let url = URL(string: "\(baseURL)/api/v3/photo/all")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = PhotosRequest(
            cameras: cameraIds,
            dateEnd: "2100-01-01T00:00:00.000Z",
            limit: limit
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }

        do {
            // Try parsing as array first
            if let photos = try? JSONDecoder().decode([Photo].self, from: data) {
                return photos
            }

            // Try parsing as object with photos key
            struct PhotosResponse: Codable {
                let photos: [Photo]?
                let photo: [Photo]?
            }

            let response = try JSONDecoder().decode(PhotosResponse.self, from: data)
            return response.photos ?? response.photo ?? []
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - Full Data Fetch

    func fetchAllData() async throws -> WidgetData {
        let cameras = try await fetchCameras()
        let cameraIds = cameras.map { $0.id }

        guard !cameraIds.isEmpty else {
            return WidgetData(cameras: cameras, photos: [], lastUpdate: Date())
        }

        let photos = try await fetchPhotos(cameraIds: cameraIds)
        return WidgetData(cameras: cameras, photos: photos, lastUpdate: Date())
    }
}
