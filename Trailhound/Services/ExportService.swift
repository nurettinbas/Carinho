import Foundation
import SwiftData

enum ExportService {
    struct ExportTrip: Codable {
        let id: UUID
        let startedAt: Date
        let endedAt: Date?
        let distanceMeters: Double
        let startAddress: String?
        let endAddress: String?
        let note: String?
        let label: String?
        let category: String
        let estimatedFuelCost: Double?
        let points: [ExportPoint]
    }

    struct ExportPoint: Codable {
        let timestamp: Date
        let latitude: Double
        let longitude: Double
        let sequence: Int
        let speedMps: Double?
    }

    static func exportJSON(trips: [Trip], blurCoordinates: Bool) throws -> Data {
        let payload = trips.map { trip in
            ExportTrip(
                id: trip.id,
                startedAt: trip.startedAt,
                endedAt: trip.endedAt,
                distanceMeters: trip.distanceMeters,
                startAddress: trip.startAddress,
                endAddress: trip.endAddress,
                note: trip.note,
                label: trip.label,
                category: trip.categoryRaw,
                estimatedFuelCost: trip.estimatedFuelCost,
                points: trip.sortedPoints.map { point in
                    let coordinate = blurCoordinates
                        ? PlaceMatchingService.blurredCoordinate(point.coordinate)
                        : point.coordinate
                    return ExportPoint(
                        timestamp: point.timestamp,
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude,
                        sequence: point.sequence,
                        speedMps: point.speedMps
                    )
                }
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    static func exportCSV(trips: [Trip]) -> String {
        var lines = ["id,startedAt,endedAt,distanceKm,start,end,label,category,note,fuelCost"]
        let formatter = ISO8601DateFormatter()
        for trip in trips {
            let distanceKm = String(format: "%.2f", trip.distanceMeters / 1000)
            let fuel = trip.estimatedFuelCost.map { String(format: "%.0f", $0) } ?? ""
            let row = [
                trip.id.uuidString,
                formatter.string(from: trip.startedAt),
                trip.endedAt.map { formatter.string(from: $0) } ?? "",
                distanceKm,
                csvEscape(trip.displayStartName),
                csvEscape(trip.displayEndName),
                csvEscape(trip.label ?? ""),
                trip.categoryRaw,
                csvEscape(trip.note ?? ""),
                fuel
            ].joined(separator: ",")
            lines.append(row)
        }
        return lines.joined(separator: "\n")
    }

    private static func csvEscape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    static func exportGPX(trips: [Trip], blurCoordinates: Bool) -> String {
        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<gpx version="1.1" creator="Trailhound">"#
        ]
        let formatter = ISO8601DateFormatter()

        for trip in trips {
            lines.append(#"<trk>"#)
            lines.append(#"<name>\#(xmlEscape(trip.label ?? trip.id.uuidString))</name>"#)
            if let note = trip.note, !note.isEmpty {
                lines.append(#"<desc>\#(xmlEscape(note))</desc>"#)
            }
            lines.append(#"<trkseg>"#)
            for point in trip.sortedPoints {
                let coordinate = blurCoordinates
                    ? PlaceMatchingService.blurredCoordinate(point.coordinate)
                    : point.coordinate
                lines.append(
                    #"<trkpt lat="\#(coordinate.latitude)" lon="\#(coordinate.longitude)">"#
                )
                lines.append(#"<time>\#(formatter.string(from: point.timestamp))</time>"#)
                if let speed = point.speedMps, speed > 0 {
                    lines.append(#"<speed>\#(speed)</speed>"#)
                }
                lines.append(#"</trkpt>"#)
            }
            lines.append(#"</trkseg>"#)
            lines.append(#"</trk>"#)
        }

        lines.append(#"</gpx>"#)
        return lines.joined(separator: "\n")
    }

    static func exportKML(trips: [Trip], blurCoordinates: Bool) -> String {
        var lines = [
            #"<?xml version="1.0" encoding="UTF-8"?>"#,
            #"<kml xmlns="http://www.opengis.net/kml/2.2">"#,
            "<Document>"
        ]

        for trip in trips {
            let name = trip.label ?? DateFormatters.tripDate.string(from: trip.startedAt)
            lines.append(#"<Placemark>"#)
            lines.append(#"<name>\#(xmlEscape(name))</name>"#)
            lines.append(#"<description>\#(xmlEscape(TripListViewModel.routeSummary(for: trip)))</description>"#)
            lines.append(#"<LineString><tessellate>1</tessellate><coordinates>"#)
            let coordinates = trip.sortedPoints.map { point -> String in
                let coordinate = blurCoordinates
                    ? PlaceMatchingService.blurredCoordinate(point.coordinate)
                    : point.coordinate
                return "\(coordinate.longitude),\(coordinate.latitude),0"
            }.joined(separator: " ")
            lines.append(coordinates)
            lines.append(#"</coordinates></LineString>"#)
            lines.append(#"</Placemark>"#)
        }

        lines.append("</Document>")
        lines.append("</kml>")
        return lines.joined(separator: "\n")
    }

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
