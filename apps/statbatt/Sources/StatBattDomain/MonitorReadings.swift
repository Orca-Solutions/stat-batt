import Foundation

/// Presentation validity is deliberately separate from the stricter active-control watchdog.
/// Normal monitoring samples every 30 seconds; values expire after two missed samples.
public enum MonitorReadings {
    public static let maximumAgeSeconds = 60.0

    public static func validated(_ snapshot: BatterySnapshot, at now: UInt64,
                                 minimumSampleNanoseconds: UInt64 = 0) -> BatterySnapshot {
        var result = snapshot
        func fresh<T>(_ metric: Metric<T>) -> Metric<T> {
            guard metric.isFresh(at: now, maximumAgeSeconds: maximumAgeSeconds,
                                 minimumSampleNanoseconds: minimumSampleNanoseconds) else {
                var missing = metric
                missing.value = nil
                if [.observed, .derived, .estimated].contains(metric.quality) {
                    missing.quality = .stale
                    missing.unavailableReason = "monitorSampleExpired"
                }
                return missing
            }
            return metric
        }
        func number(_ metric: Metric<Double>, allowed: (Double) -> Bool = { _ in true }) -> Metric<Double> {
            var metric = fresh(metric)
            if let value = metric.value, !value.isFinite || !allowed(value) {
                metric.value = nil
                metric.quality = .invalid
                metric.unavailableReason = "invalidMeasurement"
            }
            return metric
        }
        result.batteryPresent = fresh(snapshot.batteryPresent)
        result.stateOfChargePercent = number(snapshot.stateOfChargePercent) { (0...100).contains($0) }
        result.rawStateOfChargePercent = number(snapshot.rawStateOfChargePercent) { (0...100).contains($0) }
        result.isCharging = fresh(snapshot.isCharging)
        result.adapterAttached = fresh(snapshot.adapterAttached)
        result.supplyingSource = fresh(snapshot.supplyingSource)
        result.batteryCurrentMilliamps = number(snapshot.batteryCurrentMilliamps)
        result.batteryVoltageMillivolts = number(snapshot.batteryVoltageMillivolts) { $0 > 0 }
        result.batteryPowerWatts = number(snapshot.batteryPowerWatts)
        result.adapterRatedWatts = number(snapshot.adapterRatedWatts) { $0 > 0 }
        result.adapterObservedInputWatts = number(snapshot.adapterObservedInputWatts) { $0 >= 0 }
        result.batteryTemperatureCelsius = number(snapshot.batteryTemperatureCelsius) { (-20...100).contains($0) }
        result.cycleCount = fresh(snapshot.cycleCount)
        result.fullChargeCapacityMilliampHours = number(snapshot.fullChargeCapacityMilliampHours) { $0 > 0 && $0 <= 100_000 }
        result.designCapacityMilliampHours = number(snapshot.designCapacityMilliampHours) { $0 > 0 && $0 <= 100_000 }
        result.healthPercent = number(snapshot.healthPercent) { $0 >= 0 }
        result.operatingSystemCondition = fresh(snapshot.operatingSystemCondition)
        result.thermalPressure = fresh(snapshot.thermalPressure)
        // Estimates have no individual timestamp. Their enclosing acquisition must remain usable.
        if result.isCharging.value == nil || result.supplyingSource.value == nil {
            result.timeToEmpty = .unavailable(reason: "monitorSampleExpired")
            result.timeToFull = .unavailable(reason: "monitorSampleExpired")
        }
        return result
    }
}
