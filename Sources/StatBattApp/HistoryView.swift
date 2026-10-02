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
            guard let value = point[keyPath: key] else { continue }
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
                Text("Unavailable · this Mac isn’t reporting this measurement").font(.callout).foregroundStyle(.secondary).frame(maxWidth: .infinity, minHeight: 80)
            } else {
                let plot = Chart(values) { point in
                    LineMark(x: .value("Time", point.date), y: .value(unit, point.value), series: .value("Segment", point.segment))
                        .foregroundStyle(.green).interpolationMethod(.linear)
                    PointMark(x: .value("Time", point.date), y: .value(unit, point.value)).foregroundStyle(.green).symbolSize(12)
                }.chartYAxisLabel(unit).frame(height: 170).padding(8)
                if fixedScale { plot.chartYScale(domain: 0...100) } else { plot }
            }
        }
    }
}
private struct ChartReading: Identifiable {
    let date: Date
    let value: Double
    let segment: String
    var id: Date { date }
}
