import Foundation

/// Explicit adapter-based temperature control, independent of charge-percentage policies.
/// This reducer emits intent only. A qualified owner must journal, actuate and verify it.
public struct ThermalAdapterPolicy: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var disconnectAtCelsius: Double
    public var reconnectAtCelsius: Double
    public var reservePercent: Double
    public var maximumPauseSeconds: Double
    public var cooldownSeconds: Double
    public init(enabled: Bool = false, disconnectAtCelsius: Double = 40,
                reconnectAtCelsius: Double = 37, reservePercent: Double = 30,
                maximumPauseSeconds: Double = 120, cooldownSeconds: Double = 60) {
        self.enabled = enabled; self.disconnectAtCelsius = disconnectAtCelsius
        self.reconnectAtCelsius = reconnectAtCelsius; self.reservePercent = reservePercent
        self.maximumPauseSeconds = maximumPauseSeconds; self.cooldownSeconds = cooldownSeconds
    }
    public var isValid: Bool {
        disconnectAtCelsius.isFinite && reconnectAtCelsius.isFinite &&
        (30...50).contains(disconnectAtCelsius) && (25...47).contains(reconnectAtCelsius) &&
        disconnectAtCelsius - reconnectAtCelsius >= 3 && reservePercent.isFinite &&
        (20...80).contains(reservePercent) && maximumPauseSeconds.isFinite &&
        (1...120).contains(maximumPauseSeconds) && cooldownSeconds.isFinite &&
        (60...3600).contains(cooldownSeconds)
    }
}

public enum ThermalAdapterObservation: Sendable {
    case enabled, inhibitedByThisSession, unknown, ownedByOtherController
}
public enum ThermalAdapterReason: String, Codable, Sendable {
    case disabled, invalidConfiguration, unqualified, authorizationMissing, recoveryRequired
    case ownerConflict, sessionExpired, sleeping, quitting, nativeRequestInProgress
    case staleTelemetry, noBattery, adapterUnavailable, temperatureUnavailable
    case reserveReached, systemThermalPressure, cooling, belowThreshold, cooldown
    case pauseExpired, hot, holding
}
public struct ThermalAdapterDecision: Sendable {
    public var effect: ControlEffect
    public var reason: ThermalAdapterReason
    /// A new explicit session is required after a fault, expiration, sleep or quit.
    public var endSession: Bool
}
public struct ThermalAdapterInput: Sendable {
    public var policy: ThermalAdapterPolicy
    public var capabilities: CapabilitySnapshot
    public var telemetry: BatterySnapshot
    /// Boot captured at session authorization; never substitute a new boot on reload.
    public var bootID: UUID
    public var now: UInt64
    public var sessionStartedAt: UInt64
    public var sessionDeadline: UInt64
    public var minimumSampleTime: UInt64 = 0
    public var authorized = false
    public var recoveryComplete = false
    public var awake = true
    public var quitting = false
    public var nativeRequestInProgress = false
    public var observation: ThermalAdapterObservation = .unknown
    public var controlObservedAt: UInt64 = 0
    /// Set from the durable pre-write intent, never reset on each telemetry tick.
    public var pauseStartedAt: UInt64?
    /// Verified restoration time, used to avoid rapid repeated adapter cycling.
    public var lastRestoredAt: UInt64?
    public init(policy: ThermalAdapterPolicy, capabilities: CapabilitySnapshot,
                telemetry: BatterySnapshot, bootID: UUID, now: UInt64,
                sessionStartedAt: UInt64, sessionDeadline: UInt64) {
        self.policy = policy; self.capabilities = capabilities; self.telemetry = telemetry
        self.bootID = bootID; self.now = now; self.sessionStartedAt = sessionStartedAt
        self.sessionDeadline = sessionDeadline
    }
}

public enum ThermalAdapterReducer {
    public static func evaluate(_ i: ThermalAdapterInput) -> ThermalAdapterDecision {
        func restore(_ reason: ThermalAdapterReason, end: Bool = true) -> ThermalAdapterDecision {
            .init(effect: .releaseOwnedControls, reason: reason, endSession: end)
        }
        guard i.policy.enabled else { return restore(.disabled) }
        guard i.policy.isValid else { return restore(.invalidConfiguration) }
        guard i.authorized else { return restore(.authorizationMissing) }
        guard i.recoveryComplete else { return restore(.recoveryRequired) }
        guard i.capabilities.supportsBoundedAdapterInhibition,
              i.capabilities.canObserveBatteryTemperature.isVerified,
              let bounds = i.capabilities.verifiedBatteryTemperatureBoundsCelsius,
              bounds.contains(i.policy.disconnectAtCelsius), bounds.contains(i.policy.reconnectAtCelsius) else {
            return restore(.unqualified)
        }
        guard i.observation != .ownedByOtherController else { return restore(.ownerConflict) }
        guard i.observation != .unknown else { return restore(.recoveryRequired) }
        guard i.controlObservedAt >= i.minimumSampleTime, i.controlObservedAt <= i.now,
              i.now - i.controlObservedAt <= 2_000_000_000 else { return restore(.recoveryRequired) }
        guard i.now >= i.sessionStartedAt, i.sessionDeadline > i.sessionStartedAt,
              i.sessionDeadline - i.sessionStartedAt <= 3_600_000_000_000,
              i.now < i.sessionDeadline else { return restore(.sessionExpired) }
        guard i.awake else { return restore(.sleeping) }
        guard !i.quitting else { return restore(.quitting) }
        guard !i.nativeRequestInProgress else { return restore(.nativeRequestInProgress) }
        guard i.telemetry.bootID == i.bootID else { return restore(.staleTelemetry) }
        func fresh<T>(_ metric: Metric<T>, allowDerived: Bool = false) -> Bool {
            (metric.quality == .observed || (allowDerived && metric.quality == .derived)) && metric.isFresh(at: i.now, maximumAgeSeconds: 2,
                                                       minimumSampleNanoseconds: i.minimumSampleTime)
        }
        let t = i.telemetry
        guard fresh(t.batteryPresent), fresh(t.stateOfChargePercent, allowDerived: true), fresh(t.adapterAttached),
              fresh(t.supplyingSource), fresh(t.thermalPressure) else { return restore(.staleTelemetry) }
        guard t.batteryPresent.value == true else { return restore(.noBattery) }
        guard let soc = t.stateOfChargePercent.value, soc.isFinite, (0...100).contains(soc) else {
            return restore(.staleTelemetry)
        }
        guard soc > i.policy.reservePercent else { return restore(.reserveReached) }
        guard t.adapterAttached.value == true else { return restore(.adapterUnavailable) }
        // Severe system pressure exits our experiment; Apple's own protections remain in charge.
        guard t.thermalPressure.value == .nominal || t.thermalPressure.value == .fair else {
            return restore(.systemThermalPressure)
        }
        guard fresh(t.batteryTemperatureCelsius), let temperature = t.batteryTemperatureCelsius.value,
              bounds.contains(temperature) else { return restore(.temperatureUnavailable) }
        switch i.observation {
        case .inhibitedByThisSession:
            guard let started = i.pauseStartedAt, started >= i.sessionStartedAt, i.now >= started else {
                return restore(.recoveryRequired)
            }
            guard Double(i.now - started) / 1_000_000_000 < i.policy.maximumPauseSeconds else {
                return restore(.pauseExpired)
            }
            guard t.supplyingSource.value == .battery else { return restore(.recoveryRequired) }
            if temperature <= i.policy.reconnectAtCelsius { return restore(.cooling, end: false) }
            return .init(effect: .inhibitAdapter, reason: .holding, endSession: false)
        case .enabled:
            guard t.supplyingSource.value == .adapter, i.pauseStartedAt == nil else {
                return restore(.recoveryRequired)
            }
            if let restored = i.lastRestoredAt {
                guard restored >= i.sessionStartedAt, i.now >= restored else { return restore(.recoveryRequired) }
                if Double(i.now - restored) / 1_000_000_000 < i.policy.cooldownSeconds {
                    return restore(.cooldown, end: false)
                }
            }
            guard temperature >= i.policy.disconnectAtCelsius else { return restore(.belowThreshold, end: false) }
            return .init(effect: .inhibitAdapter, reason: .hot, endSession: false)
        case .unknown, .ownedByOtherController:
            return restore(.recoveryRequired)
        }
    }
}
