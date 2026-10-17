import Foundation
import StatBattDomain
import StatBattTelemetry

extension AppStore {
    var displaySnapshot: BatterySnapshot {
        MonitorReadings.validated(snapshot, at: SampleClock.nowNanoseconds(),
            minimumSampleNanoseconds: sleeping ? UInt64.max : 0)
    }

    var percentage: String {
        guard let value = displaySnapshot.stateOfChargePercent.value else { return "—" }
        return "\(Int(value.rounded()))%"
    }

    var sourceText: String {
        guard !sleeping else { return "Sleeping · readings paused" }
        switch displaySnapshot.supplyingSource.value {
        case .adapter: return "On adapter"
        case .battery: return "On battery"
        case .ups: return "On UPS"
        default: return "Power source unavailable"
        }
    }

    var chargingText: String {
        guard !sleeping else { return "Readings paused" }
        let readings = displaySnapshot
        guard readings.batteryPresent.value == true else { return "Internal battery unavailable" }
        guard let charging = readings.isCharging.value else { return "Charging state unavailable" }
        if charging { return "Charging" }
        if readings.stateOfChargePercent.value == 100 { return "Fully charged" }
        if readings.supplyingSource.value == .battery { return "Using battery power" }
        return "Not charging · reason unavailable"
    }

    var menuText: String {
        let readings = displaySnapshot
        switch preferences.menuDisplay {
        case .percentage: return percentage
        case .temperature:
            return readings.batteryTemperatureCelsius.value == nil ? "— \(temperatureSuffix)"
                : format(readings.batteryTemperatureCelsius, unit: "°C", temperature: true)
        case .batteryWatts:
            return readings.batteryPowerWatts.value == nil ? "— W" : format(readings.batteryPowerWatts, unit: "W")
        case .timeRemaining:
            return estimateText(readings.isCharging.value == true ? readings.timeToFull : readings.timeToEmpty)
                .replacingOccurrences(of: "Unavailable", with: "—")
        }
    }

    var menuAccessibilityLabel: String {
        let name: String
        switch preferences.menuDisplay {
        case .percentage: name = "battery charge"
        case .temperature: name = "battery temperature"
        case .batteryWatts: name = "net battery power"
        case .timeRemaining: name = displaySnapshot.isCharging.value == true ? "time to full" : "time remaining"
        }
        let value = menuText.contains("—") ? "unavailable" : menuText.replacingOccurrences(of: "~", with: "estimated ")
        return "StatBatt, \(name) \(value), \(sourceText), \(chargingText)"
    }

    var symbol: String {
        let readings = displaySnapshot
        if readings.isCharging.value == true { return "battery.100percent.bolt" }
        guard let percentage = readings.stateOfChargePercent.value else { return "battery.0percent" }
        let level = percentage < 12.5 ? 0 : percentage < 37.5 ? 25 : percentage < 62.5 ? 50 : percentage < 87.5 ? 75 : 100
        return "battery.\(level)percent"
    }

    func format(_ metric: Metric<Double>, unit: String, temperature: Bool = false) -> String {
        guard !sleeping, metric.isFresh(at: SampleClock.nowNanoseconds(), maximumAgeSeconds: MonitorReadings.maximumAgeSeconds),
              let value = metric.value, value.isFinite else { return "Unavailable" }
        let shown = temperature ? displayTemperature(value) : value
        guard shown.isFinite else { return "Unavailable" }
        let estimated = metric.quality == .estimated || metric.source.hasPrefix("derived.registry.FullCharge")
            || metric.source == "derived.capacityHealth"
        return (estimated ? "~" : "") + shown.formatted(.number.precision(.fractionLength(1)))
            + " " + (temperature ? temperatureSuffix : unit)
    }

    func estimateText(_ estimate: TimeEstimate) -> String {
        let readings = displaySnapshot
        guard !sleeping, readings.isCharging.value != nil, readings.supplyingSource.value != nil else { return "Unavailable" }
        switch estimate {
        case .seconds(let seconds, _):
            guard seconds.isFinite, seconds > 0, seconds <= 7 * 24 * 3600 else { return "Unavailable" }
            return "~\(Int((seconds / 60).rounded())) min"
        case .calculating: return "Calculating…"
        case .unlimited: return "On external power"
        case .unavailable: return "Unavailable"
        }
    }

    var temperatureSuffix: String { preferences.temperatureUnit == .fahrenheit ? "°F" : "°C" }
    func displayTemperature(_ celsius: Double) -> Double {
        preferences.temperatureUnit == .fahrenheit ? celsius * 9 / 5 + 32 : celsius
    }
    func celsiusFromDisplay(_ value: Double) -> Double {
        preferences.temperatureUnit == .fahrenheit ? (value - 32) * 5 / 9 : value
    }
}
