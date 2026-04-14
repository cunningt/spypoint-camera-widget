import WidgetKit
import SwiftUI
import AppKit

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SpypointEntry {
        SpypointEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpypointEntry) -> Void) {
        // Just use cached data for snapshots
        if let data = SharedDataManager.loadWidgetData() {
            completion(SpypointEntry(date: Date(), data: .loaded(data)))
        } else if SharedDataManager.hasCredentials() {
            completion(SpypointEntry(date: Date(), data: .needsRefresh))
        } else {
            completion(SpypointEntry(date: Date(), data: .notLoggedIn))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpypointEntry>) -> Void) {
        let currentDate = Date()
        let entry: SpypointEntry

        print("Widget getTimeline: Starting...")
        print("Widget getTimeline: containerURL = \(FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "2VBGUP463F.group.com.spypoint.widget")?.path ?? "nil")")

        // Use cached data from the main app
        if let cachedData = SharedDataManager.loadWidgetData() {
            print("Widget getTimeline: Got cached data with \(cachedData.photos.count) photos")
            entry = SpypointEntry(date: currentDate, data: .loaded(cachedData))
        } else if SharedDataManager.hasCredentials() {
            print("Widget getTimeline: No data but has credentials")
            entry = SpypointEntry(date: currentDate, data: .needsRefresh)
        } else {
            print("Widget getTimeline: Not logged in")
            entry = SpypointEntry(date: currentDate, data: .notLoggedIn)
        }

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Entry

struct SpypointEntry: TimelineEntry {
    let date: Date
    let data: WidgetDataState

    enum WidgetDataState {
        case placeholder
        case notLoggedIn
        case needsRefresh
        case loaded(WidgetData)
        case error(String)
    }
}

// MARK: - Widget Views

struct SpypointWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.12) : Color(red: 0.95, green: 0.95, blue: 0.97)
    }

    var body: some View {
        contentView
            .drawingGroup()
            .privacySensitive(false)
            .containerBackground(backgroundColor, for: .widget)
    }

    @ViewBuilder
    var contentView: some View {
        switch entry.data {
        case .placeholder:
            PlaceholderView()
        case .notLoggedIn:
            NotLoggedInView()
        case .needsRefresh:
            NeedsRefreshView()
        case .loaded(let data):
            switch family {
            case .systemSmall:
                SmallWidgetView(data: data)
            case .systemMedium:
                MediumWidgetView(data: data)
            case .systemLarge:
                LargeWidgetView(data: data)
            default:
                SmallWidgetView(data: data)
            }
        case .error(let message):
            ErrorView(message: message)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let data: WidgetData

    private var featuredImage: NSImage? {
        guard let firstPhoto = data.cachedPhotos.first else { return nil }
        return NSImage(data: firstPhoto.imageData)
    }

    var body: some View {
        let img = featuredImage
        GeometryReader { geo in
            ZStack {
                // Latest photo as background
                if let nsImage = img {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .drawingGroup()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                // Gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geo.size.width, height: geo.size.height)

                // Stats overlay
                VStack {
                    Spacer()
                    HStack {
                        Label("\(data.cameras.count)", systemImage: "video")
                        Spacer()
                        Label("\(data.photos.count)", systemImage: "photo")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(12)
                }
            }
        }
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let data: WidgetData

    private var images: [NSImage?] {
        (0..<5).map { index in
            guard index < data.cachedPhotos.count else { return nil }
            return NSImage(data: data.cachedPhotos[index].imageData)
        }
    }

    var body: some View {
        let imgs = images
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left side - Featured photo
                ZStack(alignment: .bottomLeading) {
                    if let nsImage = imgs[0] {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width * 0.5, height: geo.size.height)
                            .clipped()
                            .drawingGroup()
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geo.size.width * 0.5, height: geo.size.height)
                    }

                    // Gradient overlay
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: geo.size.width * 0.5, height: geo.size.height)

                    // Camera info
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(data.cameras.prefix(2)) { camera in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(camera.isOnline ? Color.green : Color.gray)
                                    .frame(width: 6, height: 6)
                                Text(camera.displayName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .padding(10)
                }

                // Right side - Photo grid (2x2)
                let cellWidth = (geo.size.width * 0.5 - 2) / 2
                let cellHeight = (geo.size.height - 2) / 2

                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(1..<3, id: \.self) { index in
                            if let nsImage = imgs[index] {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: cellWidth, height: cellHeight)
                                    .clipped()
                                    .drawingGroup()
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                    HStack(spacing: 2) {
                        ForEach(3..<5, id: \.self) { index in
                            if let nsImage = imgs[index] {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: cellWidth, height: cellHeight)
                                    .clipped()
                                    .drawingGroup()
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let data: WidgetData

    private var images: [NSImage?] {
        (0..<7).map { index in
            guard index < data.cachedPhotos.count else { return nil }
            return NSImage(data: data.cachedPhotos[index].imageData)
        }
    }

    private func batteryIcon(for percentage: Int) -> String {
        if percentage > 75 { return "battery.100" }
        if percentage > 50 { return "battery.75" }
        if percentage > 25 { return "battery.50" }
        if percentage > 10 { return "battery.25" }
        return "battery.0"
    }

    var body: some View {
        let imgs = images

        GeometryReader { geo in
            VStack(spacing: 0) {
                // Top - Camera statuses
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(data.cameras.prefix(3)) { camera in
                        HStack(spacing: 0) {
                            // Online indicator + name
                            Circle()
                                .fill(camera.isOnline ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(camera.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .padding(.leading, 6)

                            Spacer(minLength: 8)

                            // Signal bars - fixed width, right aligned
                            HStack(alignment: .bottom, spacing: 1) {
                                ForEach(0..<4, id: \.self) { i in
                                    Rectangle()
                                        .fill(i < (camera.signalBars ?? 0) ? Color.primary : Color.primary.opacity(0.3))
                                        .frame(width: 3, height: CGFloat(6 + i * 2))
                                }
                            }
                            .frame(width: 22, alignment: .center)

                            // Battery - fixed width, right aligned
                            HStack(spacing: 2) {
                                Image(systemName: batteryIcon(for: camera.batteryPercentage ?? 0))
                                    .font(.system(size: 12))
                                Text("\(camera.batteryPercentage ?? 0)%")
                                    .font(.system(size: 10).monospacedDigit())
                            }
                            .frame(width: 55, alignment: .trailing)

                            // Photo count - count then icon, fixed width
                            HStack(spacing: 3) {
                                Text("\(camera.photoCount)")
                                    .font(.system(size: 10).monospacedDigit())
                                    .frame(width: 28, alignment: .trailing)
                                Image(systemName: "photo")
                                    .font(.system(size: 10))
                                    .frame(width: 12)
                            }
                            .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // Middle - Featured photo (no overlay)
                if let nsImage = imgs[0] {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width, height: geo.size.height * 0.45)
                        .drawingGroup()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: geo.size.width, height: geo.size.height * 0.45)
                }

                // Bottom - Photo grid (2 rows x 3 columns)
                let gridHeight = geo.size.height * 0.30
                let cellWidth = (geo.size.width - 4) / 3
                let cellHeight = (gridHeight - 2) / 2

                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(1..<4, id: \.self) { index in
                            if let nsImage = imgs[index] {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: cellWidth, height: cellHeight)
                                    .clipped()
                                    .drawingGroup()
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                    HStack(spacing: 2) {
                        ForEach(4..<7, id: \.self) { index in
                            if let nsImage = imgs[index] {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: cellWidth, height: cellHeight)
                                    .clipped()
                                    .drawingGroup()
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct CameraStatusRow: View {
    let camera: Camera

    var batteryIcon: String {
        guard let pct = camera.batteryPercentage else { return "battery.0" }
        if pct > 75 { return "battery.100" }
        if pct > 50 { return "battery.75" }
        if pct > 25 { return "battery.50" }
        return "battery.25"
    }

    var batteryColor: Color {
        guard let pct = camera.batteryPercentage else { return .gray }
        if pct > 50 { return .green }
        if pct > 20 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 8) {
            // Online dot
            Circle()
                .fill(camera.isOnline ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            // Name
            Text(camera.displayName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)

            Spacer()

            // Signal
            if let bars = camera.signalBars {
                HStack(spacing: 1) {
                    ForEach(0..<4, id: \.self) { i in
                        Rectangle()
                            .fill(i < bars ? Color.primary : Color.primary.opacity(0.3))
                            .frame(width: 3, height: CGFloat(6 + i * 2))
                    }
                }
            }

            // Battery
            if let pct = camera.batteryPercentage {
                HStack(spacing: 2) {
                    Image(systemName: batteryIcon)
                        .foregroundColor(batteryColor)
                        .font(.system(size: 12))
                    Text("\(pct)%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            // Photos
            HStack(spacing: 2) {
                Image(systemName: "photo")
                    .font(.system(size: 10))
                Text("\(camera.photoCount)")
                    .font(.system(size: 10))
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Helper Views

struct BatteryView: View {
    let percentage: Int

    var batteryColor: Color {
        if percentage > 50 { return .green }
        if percentage > 20 { return .yellow }
        return .red
    }

    var body: some View {
        HStack(spacing: 2) {
            ZStack(alignment: .leading) {
                // Battery outline
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
                    .frame(width: 20, height: 10)

                // Battery fill
                RoundedRectangle(cornerRadius: 1)
                    .fill(batteryColor)
                    .frame(width: CGFloat(percentage) / 100 * 17, height: 7)
                    .padding(.leading, 1.5)
            }

            // Battery tip
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.8))
                .frame(width: 2, height: 5)

            Text("\(percentage)%")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct SignalBarsView: View {
    let bars: Int
    let maxBars: Int

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<maxBars, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < bars ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + index * 2))
            }
        }
    }
}

struct PlaceholderView: View {
    var body: some View {
        VStack {
            Image(systemName: "camera.viewfinder")
                .font(.largeTitle)
        }
        .foregroundColor(.secondary)
    }
}

struct NotLoggedInView: View {
    private var debugInfo: String {
        let groupID = "2VBGUP463F.group.com.spypoint.widget"
        let fm = FileManager.default

        guard let containerURL = fm.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
            return "No container"
        }

        let fileURL = containerURL.appendingPathComponent("shared_data.json")
        let exists = fm.fileExists(atPath: fileURL.path)

        if exists {
            do {
                let data = try Data(contentsOf: fileURL)
                return "OK: \(data.count)b"
            } catch {
                return "Err: \(error.localizedDescription.prefix(20))"
            }
        } else {
            return "No file"
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "camera.viewfinder")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("Open app to login")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(debugInfo)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct NeedsRefreshView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.clockwise")
                .font(.largeTitle)
                .foregroundColor(.accentColor)
            Text("Refreshing...")
                .font(.caption)
        }
        .padding()
    }
}

struct ErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Widget Configuration

@main
struct SpypointWidgetBundle: WidgetBundle {
    var body: some Widget {
        SpypointCameraWidget()
    }
}

struct SpypointCameraWidget: Widget {
    let kind: String = "SpypointWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            SpypointWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("SpyPoint")
        .description("View your trail camera photos and status.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    SpypointCameraWidget()
} timeline: {
    SpypointEntry(date: .now, data: .placeholder)
    SpypointEntry(date: .now, data: .notLoggedIn)
}
