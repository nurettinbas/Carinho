import MapKit
import UIKit

@MainActor
final class TripMapSnapshotCache {
    static let shared = TripMapSnapshotCache()

    private let fileManager = FileManager.default
    private var memoryCache: [UUID: UIImage] = [:]
    private var inFlight: [UUID: Task<UIImage?, Never>] = [:]

    private var cacheDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = appSupport.appendingPathComponent("TripMapSnapshots", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private init() {}

    func cachedImage(for tripID: UUID) -> UIImage? {
        if let image = memoryCache[tripID] {
            return image
        }
        let fileURL = cacheDirectory.appendingPathComponent("\(tripID.uuidString).jpg")
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        memoryCache[tripID] = image
        return image
    }

    func snapshot(for trip: Trip, size: CGSize = CGSize(width: 88, height: 88)) async -> UIImage? {
        if let cached = cachedImage(for: trip.id) {
            return cached
        }

        if let existingTask = inFlight[trip.id] {
            return await existingTask.value
        }

        let coordinates = trip.coordinates
        let task = Task<UIImage?, Never> { @MainActor in
            defer { inFlight[trip.id] = nil }
            guard coordinates.count >= 2 else { return nil }
            guard let image = await renderSnapshot(coordinates: coordinates, size: size) else { return nil }
            store(image, for: trip.id)
            return image
        }

        inFlight[trip.id] = task
        return await task.value
    }

    func remove(for tripID: UUID) {
        memoryCache.removeValue(forKey: tripID)
        inFlight[tripID]?.cancel()
        inFlight.removeValue(forKey: tripID)
        let fileURL = cacheDirectory.appendingPathComponent("\(tripID.uuidString).jpg")
        try? fileManager.removeItem(at: fileURL)
    }

    private func store(_ image: UIImage, for tripID: UUID) {
        memoryCache[tripID] = image
        let fileURL = cacheDirectory.appendingPathComponent("\(tripID.uuidString).jpg")
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func renderSnapshot(coordinates: [CLLocationCoordinate2D], size: CGSize) async -> UIImage? {
        guard let region = mapRegion(for: coordinates) else { return nil }

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.scale = UIScreen.main.scale

        let snapshotter = MKMapSnapshotter(options: options)

        return await withCheckedContinuation { continuation in
            snapshotter.start { snapshot, _ in
                guard let snapshot else {
                    continuation.resume(returning: nil)
                    return
                }

                let image = UIGraphicsImageRenderer(size: size).image { _ in
                    snapshot.image.draw(at: .zero)

                    let path = UIBezierPath()
                    for (index, coordinate) in coordinates.enumerated() {
                        let point = snapshot.point(for: coordinate)
                        if index == 0 {
                            path.move(to: point)
                        } else {
                            path.addLine(to: point)
                        }
                    }
                    UIColor.systemBlue.setStroke()
                    path.lineWidth = 2.5
                    path.lineCapStyle = .round
                    path.lineJoinStyle = .round
                    path.stroke()
                }

                continuation.resume(returning: image)
            }
        }
    }

    private func mapRegion(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.008, (maxLat - minLat) * 1.5),
            longitudeDelta: max(0.008, (maxLon - minLon) * 1.5)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}
