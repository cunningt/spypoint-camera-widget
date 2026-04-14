import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.isLoggedIn {
                DashboardView()
            } else {
                LoginView()
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .background(.ultraThinMaterial)
    }
}

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPhoto: Photo?

    var body: some View {
        VStack(spacing: 0) {
            if appState.isLoading && appState.cameras.isEmpty {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Cameras Section
                        if !appState.cameras.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                                ForEach(appState.cameras) { camera in
                                    CameraCard(camera: camera)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 0)
                        }

                        // Photos Section
                        Text("Recent Photos (\(appState.photos.count))")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        if appState.photos.isEmpty {
                            VStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("No photos found")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
                                ForEach(appState.photos) { photo in
                                    PhotoCard(photo: photo)
                                        .onTapGesture {
                                            selectedPhoto = photo
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom)
                }
                .scrollIndicators(.hidden)
            }

            if let error = appState.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                    Spacer()
                    Button("Dismiss") {
                        appState.error = nil
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.red.opacity(0.2))
            }
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo, allPhotos: appState.photos)
        }
    }
}

struct CameraCard: View {
    let camera: Camera

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(camera.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                Circle()
                    .fill(camera.isOnline ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }

            HStack(spacing: 12) {
                // Battery
                if let battery = camera.batteryPercentage {
                    HStack(spacing: 4) {
                        Image(systemName: batteryIcon(for: battery))
                            .foregroundColor(batteryColor(for: battery))
                        Text("\(battery)%")
                            .font(.caption2)
                    }
                }

                // Signal
                if let bars = camera.signalBars {
                    HStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { index in
                            Rectangle()
                                .fill(index < bars ? Color.primary : Color.gray.opacity(0.3))
                                .frame(width: 3, height: CGFloat(4 + index * 2))
                        }
                    }
                }

                Spacer()

                // Photo count
                Text("\(camera.photoCount)")
                    .font(.caption2)
                Image(systemName: "camera")
                    .font(.caption2)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    func batteryIcon(for percentage: Int) -> String {
        switch percentage {
        case 0..<25: return "battery.25"
        case 25..<50: return "battery.50"
        case 50..<75: return "battery.75"
        default: return "battery.100"
        }
    }

    func batteryColor(for percentage: Int) -> Color {
        switch percentage {
        case 0..<20: return .red
        case 20..<50: return .orange
        default: return .green
        }
    }
}

struct PhotoCard: View {
    let photo: Photo

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: photo.largeURL, scale: 1.0) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(ProgressView())
                case .success(let image):
                    image
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    EmptyView()
                }
            }
            .frame(height: 140)
            .clipped()
            .cornerRadius(12)

            // Overlay with date
            if let date = photo.displayDate {
                Text(date.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                    .padding(6)
            }

            // Video badge
            if photo.isVideo {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "video.fill")
                            .font(.caption)
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(6)
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

struct PhotoDetailView: View {
    let photo: Photo
    let allPhotos: [Photo]
    @Environment(\.dismiss) var dismiss
    @State private var currentIndex: Int = 0

    init(photo: Photo, allPhotos: [Photo]) {
        self.photo = photo
        self.allPhotos = allPhotos
        _currentIndex = State(initialValue: allPhotos.firstIndex(where: { $0.id == photo.id }) ?? 0)
    }

    var currentPhoto: Photo {
        allPhotos[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }

                Spacer()

                Text(currentPhoto.cameraName ?? "Camera")
                    .font(.headline)

                Spacer()

                if let url = currentPhoto.imageURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .padding()

            // Image - use highest quality (originPhoto)
            AsyncImage(url: currentPhoto.imageURL, scale: 1.0) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("Failed to load image")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        if value.translation.width > 0 {
                            showPrevious()
                        } else {
                            showNext()
                        }
                    }
            )

            // Footer
            HStack {
                Button(action: showPrevious) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentIndex == 0)

                Spacer()

                VStack {
                    if let date = currentPhoto.displayDate {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                    }
                    if !currentPhoto.displayTags.isEmpty {
                        Text(currentPhoto.displayTags.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(action: showNext) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentIndex >= allPhotos.count - 1)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    func showPrevious() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }

    func showNext() {
        if currentIndex < allPhotos.count - 1 {
            currentIndex += 1
        }
    }
}
