import Foundation

public struct BatteryNotificationSettings: Equatable, Sendable {
    public var enabled: Bool
    public var chargingTransitions: Bool
    public var temperature: Bool
    public var failures: Bool
    public var lowBatteryPercent: Double
    public var highTemperatureCelsius: Double

    public init(enabled: Bool = false, chargingTransitions: Bool = true, temperature: Bool = true,
                failures: Bool = true, lowBatteryPercent: Double = 20, highTemperatureCelsius: Double = 40) {
        self.enabled = enabled; self.chargingTransitions = chargingTransitions
        self.temperature = temperature; self.failures = failures
        self.lowBatteryPercent = lowBatteryPercent; self.highTemperatureCelsius = highTemperatureCelsius
    }
}

public enum BatteryNotificationCategory: Int, CaseIterable, Sendable {
    case failure, temperature, lowBattery, charging, powerSource
}

public struct BatteryNotification: Equatable, Sendable {
    public let category: BatteryNotificationCategory
    public let message: String
}

/// Pure transition/coalescing state. One pending intent per category bounds memory.
/// Call drain on live telemetry ticks and deliberate failure events; no wake timer is needed.
public struct BatteryNotificationReducer: Sendable {
    public private(set) var settings: BatteryNotificationSettings
    private var baseline: BatterySnapshot?
    private var pending: [BatteryNotificationCategory: BatteryNotification] = [:]
    private var lastDeliveryNanoseconds: UInt64?
    private var activeFailureID: String?
    public static let cooldownNanoseconds: UInt64 = 60_000_000_000

    public init(settings: BatteryNotificationSettings = .init()) { self.settings = settings }

    public mutating func configure(_ settings: BatteryNotificationSettings) {
        guard self.settings != settings else { return }
        self.settings = settings
        // Changing thresholds or enabling alerts establishes a new baseline, not a crossing.
        suspend()
        activeFailureID = nil
    }

    public mutating func suspend() {
        baseline = nil
        pending.removeAll()
    }

    public mutating func observe(_ sample: BatterySnapshot, nowNanoseconds: UInt64) {
        guard settings.enabled else { suspend(); return }
        if let old = baseline, old.bootID == sample.bootID, sample.sequence <= old.sequence { return }
        if let old = baseline, old.bootID != sample.bootID { suspend(); activeFailureID = nil }
        defer { baseline = sample }
        guard let old = baseline, old.bootID == sample.bootID,
              usable(sample.batteryPresent, nowNanoseconds), sample.batteryPresent.value == true,
              usable(old.batteryPresent, nowNanoseconds), old.batteryPresent.value == true else { return }
        if settings.chargingTransitions {
            if usable(old.isCharging, nowNanoseconds), usable(sample.isCharging, nowNanoseconds),
               let prior = old.isCharging.value, let current = sample.isCharging.value, prior != current {
                enqueue(.charging, current ? "Battery charging started." : "Battery charging stopped. Reason unavailable.")
            }
            if usable(old.supplyingSource, nowNanoseconds), usable(sample.supplyingSource, nowNanoseconds),
               let prior = old.supplyingSource.value, let current = sample.supplyingSource.value,
               prior != .unknown, current != .unknown, prior != current {
                switch current {
                case .battery: enqueue(.powerSource, "This Mac is now using battery power.")
                case .adapter: enqueue(.powerSource, "This Mac is now using adapter power.")
                case .ups: enqueue(.powerSource, "This Mac is now using UPS power.")
                case .unknown: break
                }
            }
        }
        if usable(old.stateOfChargePercent, nowNanoseconds), usable(sample.stateOfChargePercent, nowNanoseconds),
           let prior = old.stateOfChargePercent.value, let current = sample.stateOfChargePercent.value,
           prior.isFinite, current.isFinite, (0...100).contains(prior), (0...100).contains(current),
           prior > settings.lowBatteryPercent, current <= settings.lowBatteryPercent {
            enqueue(.lowBattery, "Battery reached your low-battery notification threshold.")
        }
        if settings.temperature, usable(old.batteryTemperatureCelsius, nowNanoseconds),
           usable(sample.batteryTemperatureCelsius, nowNanoseconds),
           let prior = old.batteryTemperatureCelsius.value, let current = sample.batteryTemperatureCelsius.value,
           prior.isFinite, current.isFinite,
           prior < settings.highTemperatureCelsius, current >= settings.highTemperatureCelsius {
            enqueue(.temperature, "Battery reached your temperature notification threshold. This alert does not control charging.")
        }
    }

    public mutating func recordFailure(id: String, message: String) {
        guard settings.enabled, settings.failures, id != activeFailureID else { return }
        activeFailureID = id
        enqueue(.failure, message)
    }

    public mutating func clearFailure() {
        activeFailureID = nil
        pending.removeValue(forKey: .failure)
    }

    /// All pending categories share one delivery. Suppressed crossings remain queued.
    public mutating func drain(nowNanoseconds: UInt64) -> [BatteryNotification] {
        guard settings.enabled, !pending.isEmpty else { return [] }
        if let last = lastDeliveryNanoseconds, nowNanoseconds >= last,
           nowNanoseconds - last < Self.cooldownNanoseconds { return [] }
        let result = BatteryNotificationCategory.allCases.compactMap { pending[$0] }
        pending.removeAll()
        lastDeliveryNanoseconds = nowNanoseconds
        return result
    }

    private mutating func enqueue(_ category: BatteryNotificationCategory, _ message: String) {
        pending[category] = BatteryNotification(category: category, message: message)
    }

    private func usable<T>(_ metric: Metric<T>, _ now: UInt64) -> Bool {
        // Monitoring runs every 30s; permit a prior comparison sample through one delayed tick.
        metric.isFresh(at: now, maximumAgeSeconds: 75)
    }
}
