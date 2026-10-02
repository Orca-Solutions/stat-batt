import Foundation

public enum ControlEffect: String, Codable, Sendable { case releaseOwnedControls, holdChargingPreservingAC, inhibitAdapter }
public enum PolicyPhase: String, Codable, Sendable { case disabled, chargingPermitted, holding, discharging, suspended }
public struct PolicyLatch: Codable, Equatable, Sendable {
    public var holding: Bool
    public var thermalHolding: Bool
    public init(holding: Bool = false, thermalHolding: Bool = false) { self.holding = holding; self.thermalHolding = thermalHolding }
}

public struct PolicyInput: Sendable {
    public var policy: RangePolicy
    public var capabilities: CapabilitySnapshot
    public var telemetry: BatterySnapshot
    public var activeOverride: ActiveOverride?
    public var priorLatch: PolicyLatch
    public var bootID: UUID
    public var nowUTC: Date
    public var nowContinuousNanoseconds: UInt64
    /// Set on wake to reject every sample acquired before wake, even if wall time looks fresh.
    public var minimumSampleNanoseconds: UInt64
    public var awake: Bool
    public var authorized: Bool
    public var recoveryComplete: Bool
    public var ownershipConflict: Bool
    public var nativeFenceActive: Bool
    public var uiQuitRequested: Bool
    public init(policy: RangePolicy, capabilities: CapabilitySnapshot, telemetry: BatterySnapshot,
                activeOverride: ActiveOverride? = nil, priorLatch: PolicyLatch = .init(),
                bootID: UUID, nowUTC: Date, nowContinuousNanoseconds: UInt64,
                minimumSampleNanoseconds: UInt64 = 0, awake: Bool = true, authorized: Bool = false,
                recoveryComplete: Bool = false, ownershipConflict: Bool = false,
                nativeFenceActive: Bool = false, uiQuitRequested: Bool = false) {
        self.policy = policy; self.capabilities = capabilities; self.telemetry = telemetry
        self.activeOverride = activeOverride; self.priorLatch = priorLatch; self.bootID = bootID
        self.nowUTC = nowUTC; self.nowContinuousNanoseconds = nowContinuousNanoseconds
        self.minimumSampleNanoseconds = minimumSampleNanoseconds; self.awake = awake; self.authorized = authorized
        self.recoveryComplete = recoveryComplete; self.ownershipConflict = ownershipConflict
        self.nativeFenceActive = nativeFenceActive; self.uiQuitRequested = uiQuitRequested
    }
}

/// A decision is an intent. Holding/discharging become observed state only after provider readback.
public struct PolicyDecision: Codable, Sendable {
    public var desiredEffect: ControlEffect
    /// Ordered operations: restoring adapter availability precedes an optional thermal charge hold.
    public var effects: [ControlEffect]
    public var phase: PolicyPhase
    public var reason: ErrorCode?
    public var nextLatch: PolicyLatch
    public var cancelOverride: Bool
    public init(desiredEffect: ControlEffect, effects: [ControlEffect]? = nil, phase: PolicyPhase,
                reason: ErrorCode? = nil, nextLatch: PolicyLatch = .init(), cancelOverride: Bool = false) {
        self.desiredEffect = desiredEffect; self.effects = effects ?? [desiredEffect]; self.phase = phase
        self.reason = reason; self.nextLatch = nextLatch; self.cancelOverride = cancelOverride
    }
}

public enum PolicyReducer {
    public static func evaluate(_ input: PolicyInput) -> PolicyDecision {
        let overridePresent = input.activeOverride != nil
        func release(_ reason: ErrorCode?, phase: PolicyPhase = .suspended, cancel: Bool = true) -> PolicyDecision {
            PolicyDecision(desiredEffect: .releaseOwnedControls, phase: phase, reason: reason,
                           cancelOverride: cancel && overridePresent)
        }
        guard input.policy.enabled || overridePresent else { return release(nil, phase: .disabled) }
        guard input.authorized else { return release(.authorizationDenied) }
        guard input.recoveryComplete else { return release(.recoveryRequired) }
        guard !input.ownershipConflict else { return release(.ownershipConflict) }
        guard !input.nativeFenceActive else { return release(.nativeModeFenced) }
        do { try input.policy.validate(capabilities: input.capabilities) }
        catch let error as APIError { return release(error.code) }
        catch { return release(.invalidConfiguration) }
        guard input.capabilities.supportsOwnedControl else { return release(.unsupportedPlatform) }
        guard input.awake else { return release(nil) }
        guard input.telemetry.bootID == input.bootID else { return release(.telemetryStale) }
        func fresh<T>(_ metric: Metric<T>) -> Bool {
            metric.isFresh(at: input.nowContinuousNanoseconds, minimumSampleNanoseconds: input.minimumSampleNanoseconds)
        }
        let sample = input.telemetry
        guard fresh(sample.batteryPresent) else { return release(.telemetryStale) }
        guard sample.batteryPresent.value == true else { return release(.noInternalBattery) }
        guard fresh(sample.stateOfChargePercent), let soc = sample.stateOfChargePercent.value,
              soc.isFinite, (0...100).contains(soc) else { return release(.telemetryStale) }
        guard fresh(sample.adapterAttached) else { return release(.telemetryStale) }
        guard sample.adapterAttached.value == true else { return release(.adapterUnavailable) }
        guard fresh(sample.thermalPressure), let pressure = sample.thermalPressure.value,
              pressure != .unknown else { return release(.telemetryStale) }

        var thermalHold = input.priorLatch.thermalHolding
        if input.policy.temperatureGuardEnabled {
            guard input.capabilities.canObserveBatteryTemperature.isVerified,
                  let bounds = input.capabilities.verifiedBatteryTemperatureBoundsCelsius,
                  let pause = input.policy.maximumBatteryTemperatureCelsius, bounds.contains(pause),
                  let resume = input.policy.resumeBatteryTemperatureCelsius, bounds.contains(resume),
                  fresh(sample.batteryTemperatureCelsius), let temperature = sample.batteryTemperatureCelsius.value,
                  bounds.contains(temperature) else { return release(.temperatureUnavailable) }
            if temperature >= pause { thermalHold = true }
            if temperature <= resume && pressure != .serious && pressure != .critical { thermalHold = false }
        } else if pressure == .nominal || pressure == .fair {
            thermalHold = false
        }
        if pressure == .serious || pressure == .critical { thermalHold = true }
        if thermalHold {
            // Temperature never silently substitutes adapter inhibition for a charge gate.
            guard input.capabilities.supportsTrueHold else { return release(.thermalGuardActive) }
            let discharge = input.activeOverride.map { if case .discharge = $0.goal { return true }; return false } ?? false
            return PolicyDecision(desiredEffect: .holdChargingPreservingAC,
                                  effects: [.releaseOwnedControls, .holdChargingPreservingAC], phase: .holding,
                                  reason: .thermalGuardActive, nextLatch: .init(holding: input.priorLatch.holding, thermalHolding: true),
                                  cancelOverride: discharge || (input.activeOverride?.isExpired(bootID: input.bootID,
                                      nowContinuousNanoseconds: input.nowContinuousNanoseconds, nowUTC: input.nowUTC) ?? false))
        }

        var cancelOverride = false
        var restoreAdapterFirst = false
        if let active = input.activeOverride {
            if active.isExpired(bootID: input.bootID, nowContinuousNanoseconds: input.nowContinuousNanoseconds, nowUTC: input.nowUTC) {
                cancelOverride = true
                if case .discharge = active.goal { restoreAdapterFirst = true }
            } else {
                switch active.goal {
                case .allowCharging(let target):
                    guard target.isFinite, (0...100).contains(target) else { return release(.invalidConfiguration) }
                    guard input.capabilities.supportsTrueHold else { return release(.unsupportedPlatform) }
                    if soc < target {
                        return PolicyDecision(desiredEffect: .releaseOwnedControls, phase: .chargingPermitted,
                                              nextLatch: .init(holding: input.priorLatch.holding))
                    }
                    cancelOverride = true
                case .holdCharging:
                    guard input.capabilities.supportsTrueHold else { return release(.unsupportedPlatform) }
                    return PolicyDecision(desiredEffect: .holdChargingPreservingAC, phase: .holding,
                                          nextLatch: .init(holding: input.priorLatch.holding))
                case .discharge(let target):
                    guard target.isFinite, target >= input.policy.reserveFloorPercent, target <= 100 else { return release(.unsafeReserve) }
                    guard input.capabilities.supportsBoundedAdapterInhibition else { return release(.unsupportedPlatform) }
                    if soc <= input.policy.reserveFloorPercent {
                        return release(.unsafeReserve)
                    }
                    if soc <= target || input.uiQuitRequested {
                        cancelOverride = true; restoreAdapterFirst = true
                    } else {
                        return PolicyDecision(desiredEffect: .inhibitAdapter, phase: .discharging,
                                              nextLatch: .init(holding: input.priorLatch.holding))
                    }
                }
            }
        }
        guard input.policy.enabled else {
            return PolicyDecision(desiredEffect: .releaseOwnedControls, phase: .disabled, cancelOverride: cancelOverride)
        }
        var holding = input.priorLatch.holding
        if soc >= input.policy.holdAtPercent { holding = true }
        if soc <= input.policy.resumeAtPercent { holding = false }
        let latch = PolicyLatch(holding: holding, thermalHolding: false)
        if holding && input.policy.backend == .adapterCycling && soc <= input.policy.reserveFloorPercent {
            return release(.unsafeReserve)
        }
        let effect: ControlEffect = holding ? (input.policy.backend == .trueChargeHold ? .holdChargingPreservingAC : .inhibitAdapter) : .releaseOwnedControls
        let phase: PolicyPhase = holding ? (input.policy.backend == .trueChargeHold ? .holding : .discharging) : .chargingPermitted
        return PolicyDecision(desiredEffect: effect,
                              effects: restoreAdapterFirst && effect != .releaseOwnedControls ? [.releaseOwnedControls, effect] : [effect],
                              phase: phase, nextLatch: latch, cancelOverride: cancelOverride)
    }
}
