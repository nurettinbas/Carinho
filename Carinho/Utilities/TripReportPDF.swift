import PDFKit
import SwiftData
import UIKit

enum TripReportPDF {
    struct ReportRow {
        let date: String
        let route: String
        let distanceKm: String
        let duration: String
        let cost: String
    }

    static func businessTrips(
        in trips: [Trip],
        month: Date = Date()
    ) -> [Trip] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        let businessID = BuiltInCategory.businessID.uuidString
        return StatsViewModel.trips(in: interval, from: trips)
            .filter { $0.categoryID == businessID }
            .sorted { $0.startedAt < $1.startedAt }
    }

    static func generateMonthlyWorkReport(
        trips: [Trip],
        places: [SavedPlace],
        privacyRadius: Double,
        month: Date = Date()
    ) -> Data? {
        let monthTrips = businessTrips(in: trips, month: month)
        guard !monthTrips.isEmpty else { return nil }

        let stats = StatsViewModel.stats(for: monthTrips)
        let rows = monthTrips.map { trip in
            ReportRow(
                date: DateFormatters.tripDate.string(from: trip.startedAt),
                route: TripListViewModel.routeSummary(for: trip, places: places, privacyRadius: privacyRadius),
                distanceKm: String(format: "%.1f", trip.distanceMeters / 1000),
                duration: trip.duration.map(DateFormatters.formatDuration) ?? "—",
                cost: FuelCostCalculator.formatCost(StatsViewModel.fuelCost(for: trip))
            )
        }

        let formatter = DateFormatter()
        formatter.locale = DateFormatters.currentLocale
        formatter.dateFormat = "MMMM yyyy"
        let monthTitle = formatter.string(from: month)

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = 40

            drawText(L10n.pdfWorkReportTitle, at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 20))
            y += 28
            drawText(monthTitle, at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 14), color: .secondaryLabel)
            y += 24
            drawText(
                L10n.pdfWorkReportSummary(
                    distance: stats.totalDistanceText,
                    tripCount: stats.tripCount,
                    fuelCost: stats.fuelCostText
                ),
                at: CGPoint(x: 40, y: y),
                font: .systemFont(ofSize: 12)
            )
            y += 32

            drawText(L10n.pdfColumnDate, at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 11))
            drawText(L10n.pdfColumnRoute, at: CGPoint(x: 120, y: y), font: .boldSystemFont(ofSize: 11))
            drawText(L10n.pdfColumnDistance, at: CGPoint(x: 360, y: y), font: .boldSystemFont(ofSize: 11))
            drawText(L10n.pdfColumnDuration, at: CGPoint(x: 410, y: y), font: .boldSystemFont(ofSize: 11))
            drawText(L10n.pdfColumnCost, at: CGPoint(x: 480, y: y), font: .boldSystemFont(ofSize: 11))
            y += 18

            for row in rows {
                if y > pageRect.height - 50 {
                    context.beginPage()
                    y = 40
                }
                drawText(row.date, at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 10))
                drawText(row.route, at: CGPoint(x: 120, y: y), font: .systemFont(ofSize: 10), maxWidth: 220)
                drawText(row.distanceKm, at: CGPoint(x: 360, y: y), font: .systemFont(ofSize: 10))
                drawText(row.duration, at: CGPoint(x: 410, y: y), font: .systemFont(ofSize: 10))
                drawText(row.cost, at: CGPoint(x: 480, y: y), font: .systemFont(ofSize: 10))
                y += 16
            }
        }
    }

    private static func drawText(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        color: UIColor = .label,
        maxWidth: CGFloat = 220
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        (text as NSString).draw(
            with: CGRect(x: point.x, y: point.y, width: maxWidth, height: 14),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: attributes,
            context: nil
        )
    }
}
