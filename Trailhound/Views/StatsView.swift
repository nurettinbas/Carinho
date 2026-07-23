import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @Query(sort: \Trip.startedAt, order: .reverse) private var trips: [Trip]
    @Query(sort: \UserCategory.sortOrder) private var categories: [UserCategory]
    @Bindable private var settings = AppSettings.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedPeriod: StatsPeriod = .week
    @State private var selectedCategoryID: String?
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @State private var animatedProgress: Double = 0
    @Namespace private var periodChipNamespace

    private var completedTrips: [Trip] {
        trips.filter { $0.endedAt != nil }
    }

    private var selectedInterval: DateInterval {
        StatsViewModel.interval(for: selectedPeriod, customStart: customStart, customEnd: customEnd)
    }

    private var previousInterval: DateInterval {
        StatsViewModel.previousInterval(for: selectedInterval)
    }

    private var periodTrips: [Trip] {
        StatsViewModel.trips(in: selectedInterval, from: completedTrips)
    }

    private var previousTrips: [Trip] {
        StatsViewModel.trips(in: previousInterval, from: completedTrips)
    }

    private var stats: TripStats {
        StatsViewModel.stats(for: periodTrips, categoryID: selectedCategoryID)
    }

    private var previousStats: TripStats {
        StatsViewModel.stats(for: previousTrips, categoryID: selectedCategoryID)
    }

    private var distanceTrendText: String? {
        StatsViewModel.trendText(
            current: stats.totalDistanceMeters,
            previous: previousStats.totalDistanceMeters
        )
    }

    private var tripCountTrendText: String? {
        StatsViewModel.trendText(
            current: Double(stats.tripCount),
            previous: Double(previousStats.tripCount)
        )
    }

    private var dailyChartData: [DailyDistance] {
        StatsViewModel.dailyDistances(in: selectedInterval, from: completedTrips)
    }

    private var categoryChartData: [CategoryDistance] {
        StatsViewModel.categoryBreakdown(for: periodTrips, categories: categories)
    }

    private var monthInterval: DateInterval {
        let end = Date()
        let start = Calendar.current.date(byAdding: .month, value: -1, to: end) ?? end
        return DateInterval(start: start, end: end)
    }

    private var monthDistanceMeters: Double {
        StatsViewModel.stats(
            for: StatsViewModel.trips(in: monthInterval, from: completedTrips)
        ).totalDistanceMeters
    }

    private var goalProgress: Double {
        guard settings.monthlyDistanceGoalMeters > 0 else { return 0 }
        return min(1, monthDistanceMeters / settings.monthlyDistanceGoalMeters)
    }

    private var goalPercentText: String {
        "\(Int(goalProgress * 100))%"
    }

    var body: some View {
        List {
            statsFilterCard
                .glassListRow()

            Section(L10n.string("stats.goal.section")) {
                HStack(spacing: 20) {
                    goalRing
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.string("stats.goal.monthly"))
                            .font(.subheadline.weight(.semibold))
                        Text("\(DateFormatters.formatDistance(monthDistanceMeters)) / \(DateFormatters.formatDistance(settings.monthlyDistanceGoalMeters))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper(
                            value: Binding(
                                get: { Int(settings.monthlyDistanceGoalMeters / 1000) },
                                set: { newValue in
                                    settings.monthlyDistanceGoalMeters = Double(newValue) * 1000
                                    TrailhoundHaptics.selection()
                                }
                            ),
                            in: 50...2000,
                            step: 50
                        ) {
                            Text(L10n.string("stats.goal.target_km"))
                                .font(.caption)
                        }
                    }
                }
                .padding(.vertical, 4)
                .glassListRow()
            }

            Section(L10n.string("stats.summary.section")) {
                trendRow(L10n.string("stats.trips"), value: "\(stats.tripCount)", trend: tripCountTrendText)
                    .glassRow(position: .first)
                trendRow(L10n.string("stats.total_distance"), value: stats.totalDistanceText, trend: distanceTrendText)
                    .glassRow(position: .middle)
                statRow(L10n.string("stats.average_duration"), value: stats.averageDurationText)
                    .glassRow(position: .middle)
                statRow(L10n.estimatedFuel, value: stats.fuelCostText)
                    .glassRow(position: .middle)
                statRow(L10n.string("stats.night_driving"), value: stats.nightDrivingText)
                    .glassRow(position: .last)
            }
            .transition(TrailhoundMotion.fadeScaleTransition(reduceMotion: reduceMotion))

            if !dailyChartData.isEmpty {
                Section(L10n.string("stats.chart.weekly_distance")) {
                    Chart(dailyChartData) { item in
                        BarMark(
                            x: .value(L10n.string("stats.chart.day"), item.day, unit: .day),
                            y: .value(L10n.string("stats.chart.distance_km"), item.distanceKilometers)
                        )
                        .foregroundStyle(TrailhoundBrandColors.brandBottom.gradient)
                    }
                    .chartYAxisLabel(L10n.string("stats.chart.distance_km"))
                    .frame(height: 200)
                    .glassListRow()
                }
                .animation(reduceMotion ? nil : TrailhoundMotion.gentle, value: selectedPeriod)
            }

            if !categoryChartData.isEmpty {
                Section(L10n.string("stats.chart.categories")) {
                    Chart(categoryChartData) { item in
                        SectorMark(
                            angle: .value(L10n.string("stats.chart.distance_km"), item.distanceKilometers),
                            innerRadius: .ratio(0.55),
                            angularInset: 1.5
                        )
                        .foregroundStyle(by: .value(L10n.string("filter.category"), item.name))
                    }
                    .frame(height: 220)
                    .glassRow(position: .first)

                    ForEach(Array(categoryChartData.enumerated()), id: \.element.id) { index, item in
                        LabeledContent(item.name) {
                            Text(DateFormatters.formatDistance(item.distanceMeters))
                                .foregroundStyle(.secondary)
                        }
                        .glassRow(position: GlassRowPosition.index(index + 1, in: categoryChartData.count + 1))
                    }
                }
                .animation(reduceMotion ? nil : TrailhoundMotion.gentle, value: selectedCategoryID)
            }
        }
        .animation(reduceMotion ? nil : TrailhoundMotion.gentle, value: selectedPeriod)
        .animation(reduceMotion ? nil : TrailhoundMotion.gentle, value: selectedCategoryID)
        .glassListChrome()
        .navigationTitle(L10n.string("stats.title"))
        .onAppear {
            updateAnimatedProgress(animated: false)
        }
        .onChange(of: goalProgress) { _, _ in
            updateAnimatedProgress(animated: true)
        }
        .onChange(of: monthDistanceMeters) { _, _ in
            updateAnimatedProgress(animated: true)
        }
    }

    private var selectedCategoryName: String {
        guard let selectedCategoryID,
              let category = categories.first(where: { $0.storageKey == selectedCategoryID }) else {
            return L10n.all
        }
        return category.name
    }

    private var statsFilterCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(StatsPeriod.allCases) { period in
                    GlassFilterChip(
                        title: period.title,
                        isSelected: selectedPeriod == period,
                        namespace: periodChipNamespace,
                        highlightID: "statsPeriodHighlight",
                        expands: true
                    ) {
                        if reduceMotion {
                            selectedPeriod = period
                        } else {
                            withAnimation(TrailhoundMotion.gentle) {
                                selectedPeriod = period
                            }
                        }
                        TrailhoundHaptics.selection()
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.string("stats.period.title"))

            if selectedPeriod == .custom {
                HStack(alignment: .top, spacing: 10) {
                    statsCustomDateField(
                        title: L10n.string("stats.period.start"),
                        date: $customStart
                    )
                    statsCustomDateField(
                        title: L10n.string("stats.period.end"),
                        date: $customEnd
                    )
                }
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 12) {
                Text(L10n.string("filter.category"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Picker(L10n.string("filter.category"), selection: $selectedCategoryID) {
                    Text(L10n.all).tag(String?.none)
                    ForEach(categories) { category in
                        Text(category.name).tag(Optional(category.storageKey))
                    }
                }
                .pickerStyle(.menu)
                .tint(TrailhoundBrandColors.brandBottom)
                .labelsHidden()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(L10n.string("filter.category"))
            .accessibilityValue(selectedCategoryName)
        }
        .padding(.vertical, 6)
        .animation(reduceMotion ? nil : TrailhoundMotion.gentle, value: selectedPeriod)
    }

    private func statsCustomDateField(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            DatePicker(title, selection: date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var goalRing: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(goalPercentText)
                .font(.caption.bold())
                .numericTextAnimation(value: goalPercentText)
        }
        .frame(width: 72, height: 72)
        .accessibilityLabel(L10n.string("stats.goal.progress_accessibility"))
        .accessibilityValue(goalPercentText)
    }

    private func updateAnimatedProgress(animated: Bool) {
        if animated && !reduceMotion {
            withAnimation(TrailhoundMotion.cardSpring) {
                animatedProgress = goalProgress
            }
        } else {
            animatedProgress = goalProgress
        }
    }

    private func statRow(_ title: String, value: String) -> some View {
        LabeledContent(title) {
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func trendRow(_ title: String, value: String, trend: String?) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                Text(value)
                    .foregroundStyle(.secondary)
                if let trend {
                    Text(trend)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(trendColor(for: trend))
                        .animation(reduceMotion ? nil : TrailhoundMotion.gentle, value: trend)
                        .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
                }
            }
        }
    }

    private func trendColor(for trend: String) -> Color {
        if trend.hasPrefix("+") { return .green }
        if trend.hasPrefix("-") { return .red }
        return .secondary
    }
}

#Preview {
    NavigationStack { StatsView() }
        .modelContainer(PreviewData.shared.container)
}
