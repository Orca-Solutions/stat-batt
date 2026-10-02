import SwiftUI
import Charts
import StatBattPersistence

struct HistoryView: View {
    @ObservedObject var store: AppStore
    @State private var clearConfirmation = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Battery history").font(.title2.bold())
                    Text("7 days · one-minute summaries · local to this Mac").font(.caption).foregroundStyle(.secondary)
                    Text("Displayed times are local; CSV timestamps use UTC.").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Export CSV…") { store.exportHistory() }
                Button("Clear…") { clearConfirmation = true }
            }
            if !store.preferences.historyEnabled {
                Label("Recording is paused. Existing history remains available.", systemImage: "pause.circle").font(.callout)
            }
            if store.points.isEmpty {
                ContentUnavailableView("No battery history yet", systemImage: "chart.xyaxis.line", description: Text("History appears as live readings arrive. Enable recording in Settings."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Battery temperature readings may be estimated. History shows observations, not a thermal charging policy.")
                            .font(.caption).foregroundStyle(.secondary)
                        chart(title: "Battery charge", unit: "%", values: readings(\.percentage), fixedScale: true)
                        chart(title: "Temperature", unit: store.temperatureSuffix, values: readings(\.temperatureCelsius, temperature: true))
                        chart(title: "Net battery power", unit: "W", values: readings(\.batteryWatts))
                        if !store.gaps.isEmpty {
                            Label("\(store.gaps.count) recorded gaps · no readings are interpolated across sleep", systemImage: "moon.zzz").font(.caption).foregroundStyle(.secondary)
                        }
                        transitionHistory
                    }
                }
            }
            Spacer(minLength: 0)
        }.padding(20)
        .confirmationDialog("Clear all saved battery history?", isPresented: $clearConfirmation) {
            Button("Clear history", role: .destructive) { store.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes local readings and gap records.") }
    }
    private func readings(_ key: KeyPath<HistoryPoint, Double?>, temperature: Bool = false) -> [ChartReading] {
        let orderedGaps = store.gaps.sorted { $0.start < $1.start }
        var gapIndex = 0, section = 0
        var previous: Date?
        var result: [ChartReading] = []
        result.reserveCapacity(store.points.count)
        for point in store.points {
            guard let value = point[keyPath: key], value.isFinite else { continue }
            while gapIndex < orderedGaps.count && orderedGaps[gapIndex].start <= point.timestamp {
                if let previous, orderedGaps[gapIndex].end > previous { section += 1 }
                gapIndex += 1
            }
            if let previous, point.timestamp.timeIntervalSince(previous) > 90 { section += 1 }
            result.append(ChartReading(date: point.timestamp, value: temperature ? store.displayTemperature(value) : value, segment: String(section)))
            previous = point.timestamp
        }
        return result
    }
    @ViewBuilder private func chart(title: String, unit: String, values: [ChartReading], fixedScale: Bool = false) -> some View {
        GroupBox(title) {
            if values.isEmpty {
                Text("Unavailable · no saved readings for this measurement").font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(summary(values, unit: unit))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("\(title) history summary")
                        .accessibilityValue(summary(values, unit: unit))
                    let plot = Chart(values) { point in
                        LineMark(x: .value("Time", point.date), y: .value(unit, point.value), series: .value("Segment", point.segment))
                            .foregroundStyle(.green).interpolationMethod(.linear)
                        PointMark(x: .value("Time", point.date), y: .value(unit, point.value)).foregroundStyle(.green).symbolSize(12)
                    }.chartYAxisLabel(unit).frame(height: 170).padding(8)
                        .accessibilityLabel("\(title) history chart")
                    if fixedScale { plot.chartYScale(domain: 0...100) } else { plot }
                }
            }
        }
    }

    private func summary(_ values: [ChartReading], unit: String) -> String {
        guard let first = values.first, let last = values.last,
              let minimum = values.map(\.value).min(), let maximum = values.map(\.value).max() else {
            return "No recorded readings."
        }
        func number(_ value: Double) -> String {
            value.formatted(.number.precision(.fractionLength(1)))
        }
        return "Latest recorded: \(number(last.value)) \(unit) at \(last.date.formatted(date: .abbreviated, time: .shortened)). Range: \(number(minimum)) to \(number(maximum)) \(unit). \(values.count) readings since \(first.date.formatted(date: .abbreviated, time: .shortened))."
    }

    private var transitionHistory: some View {
        let observations = stateObservations
        return GroupBox("Power source & charging changes") {
            VStack(alignment: .leading, spacing: 12) {
                Text("States from one-minute summaries. Change times are sampled observations, not exact events. No changes are inferred across a recording gap.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if observations.isEmpty {
                    Text("No recorded power-state observations.").foregroundStyle(.secondary)
                } else {
                    if observations.count > 30 {
                        Text("Showing the latest 30 of \(observations.count) state observations. Export CSV for all recorded states.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(observations.suffix(30).reversed())) { observation in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(observation.description).font(.callout)
                            Text("\(observation.context) · \(observation.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
        }
    }

    private var stateObservations: [HistoryStateObservation] {
        let points = store.points.sorted { $0.timestamp < $1.timestamp }
        let gaps = store.gaps.sorted { $0.start < $1.start }
        var result: [HistoryStateObservation] = []
        var previous: HistoryPoint?
        var gapIndex = 0
        for point in points {
            var afterGap = previous.map { point.timestamp.timeIntervalSince($0.timestamp) > 90 } ?? false
            while gapIndex < gaps.count && gaps[gapIndex].start <= point.timestamp {
                if let previous, gaps[gapIndex].end > previous.timestamp { afterGap = true }
                gapIndex += 1
            }
            if previous == nil || afterGap || previous?.source != point.source || previous?.isCharging != point.isCharging {
                result.append(HistoryStateObservation(timestamp: point.timestamp, source: point.source,
                    isCharging: point.isCharging,
                    context: previous == nil ? "Initial recorded state" : afterGap ? "State after gap" : "Observed change"))
            }
            previous = point
        }
        return result
    }
}
private struct ChartReading: Identifiable {
    let date: Date
    let value: Double
    let segment: String
    var id: Date { date }
}

private struct HistoryStateObservation: Identifiable {
    let timestamp: Date
    let source: HistoryPowerSource
    let isCharging: Bool?
    let context: String
    var id: Date { timestamp }
    var description: String {
        let sourceText: String
        switch source {
        case .battery: sourceText = "On battery"
        case .adapter: sourceText = "On adapter"
        case .unknown: sourceText = "Power source unavailable"
        }
        let chargingText = isCharging.map { $0 ? "Charging" : "Not charging" } ?? "Charging state unavailable"
        return "\(sourceText) · \(chargingText)"
    }
}
