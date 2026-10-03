import Foundation
import Testing
@testable import StatBattDomain

private func thermalFixture() -> ThermalAdapterInput {
    let now: UInt64 = 100_000_000_000
    let boot = UUID()
    var sample = BatterySnapshot(bootID: boot)
    func value<T>(_ v: T) -> Metric<T> { .init(value: v, quality: .observed, sampledAtContinuousNanoseconds: now, source: "fixture") }
    sample.batteryPresent = value(true); sample.adapterAttached = value(true)
    sample.stateOfChargePercent = value(80); sample.stateOfChargePercent.quality = .derived; sample.supplyingSource = value(.adapter)
    sample.batteryTemperatureCelsius = value(40); sample.thermalPressure = value(.nominal)
    let verified = Capability(status: .verified, scope: .awakeOnly, evidence: [.init(identifier: "fixture", provenance: "test only")],
                              verifiedAtUTC: Date(), restorationVerified: true, crashRecoveryBoundSeconds: 5)
    var caps = CapabilitySnapshot()
    caps.canInhibitAdapter = verified; caps.canReadControlState = verified; caps.canRestoreOwnedControl = verified
    caps.canObserveBatteryTemperature = verified; caps.verifiedBatteryTemperatureBoundsCelsius = .init(lower: 0, upper: 60)
    var input = ThermalAdapterInput(policy: .init(enabled: true), capabilities: caps, telemetry: sample,
                                   bootID: boot, now: now, sessionStartedAt: 1, sessionDeadline: 1_000_000_000_000)
    input.authorized = true; input.recoveryComplete = true; input.observation = .enabled; input.controlObservedAt = now
    return input
}

@Test func thermalAdapterHysteresisUsesObservedOwnership() {
    var i = thermalFixture()
    #expect(ThermalAdapterReducer.evaluate(i).reason == .hot)
    #expect(ThermalAdapterReducer.evaluate(i).effect == .inhibitAdapter)
    i.telemetry.batteryTemperatureCelsius.value = 39
    #expect(ThermalAdapterReducer.evaluate(i).effect == .releaseOwnedControls)
    i.observation = .inhibitedByThisSession
    i.pauseStartedAt = i.now - 1_000_000_000
    i.telemetry.supplyingSource.value = .battery
    #expect(ThermalAdapterReducer.evaluate(i).reason == .holding)
    i.telemetry.batteryTemperatureCelsius.value = 37
    let cooled = ThermalAdapterReducer.evaluate(i)
    #expect(cooled.reason == .cooling)
    #expect(cooled.effect == .releaseOwnedControls)
    #expect(!cooled.endSession)
}

@Test func thermalAdapterFailuresRestoreAndEndSession() {
    let mutations: [(inout ThermalAdapterInput) -> Void] = [
        { $0.policy.enabled = false }, { $0.authorized = false }, { $0.recoveryComplete = false },
        { $0.capabilities.canInhibitAdapter.restorationVerified = false },
        { $0.capabilities.canInhibitAdapter.crashRecoveryBoundSeconds = nil },
        { $0.capabilities.canObserveBatteryTemperature = .init() },
        { $0.awake = false }, { $0.quitting = true }, { $0.nativeRequestInProgress = true },
        { $0.controlObservedAt = $0.now + 1 }, { $0.controlObservedAt = $0.now - 2_000_000_001 },
        { $0.observation = .unknown }, { $0.observation = .ownedByOtherController },
        { $0.sessionDeadline = $0.now }, { $0.sessionStartedAt = $0.now + 1 },
        { $0.sessionDeadline = $0.sessionStartedAt + 3_600_000_000_001 },
        { $0.bootID = UUID() }, { $0.minimumSampleTime = $0.now + 1 },
        { $0.telemetry.batteryPresent.value = false }, { $0.telemetry.stateOfChargePercent.value = 30 },
        { $0.telemetry.stateOfChargePercent.quality = .estimated },
        { $0.telemetry.stateOfChargePercent.value = .nan }, { $0.telemetry.stateOfChargePercent.value = 101 },
        { $0.telemetry.adapterAttached.value = false }, { $0.telemetry.supplyingSource.value = .unknown },
        { $0.telemetry.thermalPressure.value = .critical }, { $0.telemetry.thermalPressure.value = .unknown },
        { $0.telemetry.batteryTemperatureCelsius.value = nil }, { $0.telemetry.batteryTemperatureCelsius.value = .nan },
        { $0.telemetry.batteryTemperatureCelsius.value = 61 },
        { $0.telemetry.batteryTemperatureCelsius.quality = .estimated },
        { $0.telemetry.stateOfChargePercent.sampledAtContinuousNanoseconds = $0.now - 2_000_000_001 }
    ]
    for mutate in mutations {
        for inhibited in [false, true] {
            var i = thermalFixture()
            if inhibited {
                i.observation = .inhibitedByThisSession
                i.pauseStartedAt = i.now - 1_000_000_000
                i.telemetry.supplyingSource.value = .battery
            }
            mutate(&i)
            let result = ThermalAdapterReducer.evaluate(i)
            #expect(result.effect == .releaseOwnedControls)
            #expect(result.endSession)
        }
    }
}

@Test func thermalAdapterPauseDeadlineCannotSlideWithTelemetry() {
    var i = thermalFixture()
    i.observation = .inhibitedByThisSession; i.telemetry.supplyingSource.value = .battery
    i.policy.maximumPauseSeconds = 10
    i.pauseStartedAt = i.now - 10_000_000_000
    let result = ThermalAdapterReducer.evaluate(i)
    #expect(result.reason == .pauseExpired)
    #expect(result.effect == .releaseOwnedControls)
    #expect(result.endSession)
    i.pauseStartedAt = i.now - 9_999_999_999
    #expect(ThermalAdapterReducer.evaluate(i).reason == .holding)
    i.pauseStartedAt = i.now + 1
    #expect(ThermalAdapterReducer.evaluate(i).reason == .recoveryRequired)
    i.pauseStartedAt = 0
    #expect(ThermalAdapterReducer.evaluate(i).reason == .recoveryRequired)
    i.pauseStartedAt = nil
    #expect(ThermalAdapterReducer.evaluate(i).reason == .recoveryRequired)
}

@Test func thermalAdapterCooldownPreventsRapidReentry() {
    var i = thermalFixture()
    i.lastRestoredAt = i.now - 59_999_999_999
    #expect(ThermalAdapterReducer.evaluate(i).reason == .cooldown)
    #expect(!ThermalAdapterReducer.evaluate(i).endSession)
    i.lastRestoredAt = i.now - 60_000_000_000
    #expect(ThermalAdapterReducer.evaluate(i).reason == .hot)
    i.lastRestoredAt = i.now + 1
    #expect(ThermalAdapterReducer.evaluate(i).reason == .recoveryRequired)
}

@Test func thermalAdapterRejectsUnsafeOrNonfiniteConfiguration() {
    #expect(ThermalAdapterPolicy().isValid)
    let mutations: [(inout ThermalAdapterPolicy) -> Void] = [
        { $0.disconnectAtCelsius = .nan }, { $0.reconnectAtCelsius = .infinity },
        { $0.disconnectAtCelsius = 51 }, { $0.reconnectAtCelsius = 39 },
        { $0.reservePercent = 19 }, { $0.maximumPauseSeconds = 121 },
        { $0.maximumPauseSeconds = 0 }, { $0.cooldownSeconds = 59 }
    ]
    for mutate in mutations {
        var i = thermalFixture(); mutate(&i.policy)
        #expect(!i.policy.isValid)
        #expect(ThermalAdapterReducer.evaluate(i).reason == .invalidConfiguration)
    }
}
