import Testing
import StatBattDomain
@testable import StatBattAdapterGuardian

@Test func longLeaseIsFixedNonrenewableAndOverflowSafe() {
    var gate = WorkerRecoveryGate(lease: .longTrial)
    let began = gate.begin(now: 7, ownerGone: false, sleeping: false)
    let renewed = gate.begin(now: 8, ownerGone: false, sleeping: false)
    let early = gate.shouldRestore(now: 120_000_000_006, ownerGone: false, sleeping: false)
    let due = gate.shouldRestore(now: 120_000_000_007, ownerGone: false, sleeping: false)
    #expect(began && !renewed && !early && due)
    #expect(gate.cause == .deadline)
    var overflow = WorkerRecoveryGate(lease: .longTrial)
    let accepted = overflow.begin(now: .max, ownerGone: false, sleeping: false)
    #expect(!accepted && overflow.deadline == nil)
}

@Test func longPauseRejectsMissingStaleFutureAndUnsafeHostReadings() {
    let now: UInt64 = 10_000_000_000
    var sample = BatterySnapshot(bootID: .init())
    sample.batteryPresent = Metric(value: true, quality: .observed, sampledAtContinuousNanoseconds: now, source: "fixture")
    sample.stateOfChargePercent = Metric(value: 50, quality: .observed, sampledAtContinuousNanoseconds: now, source: "fixture")
    sample.thermalPressure = Metric(value: .nominal, quality: .observed, sampledAtContinuousNanoseconds: now, source: "fixture")
    sample.supplyingSource = Metric(value: .battery, quality: .observed, sampledAtContinuousNanoseconds: now, source: "fixture")
    sample.batteryTemperatureCelsius = Metric(value: 35, quality: .estimated, sampledAtContinuousNanoseconds: now, source: "fixture")
    #expect(LongPauseSafety.rejection(sample, now: now, requireBattery: true) == nil)
    #expect(sample.batteryTemperatureCelsius.quality == .estimated)
    #expect(LongPauseSafety.rejection(sample, now: now + 2_000_000_001, requireBattery: true) != nil)
    #expect(LongPauseSafety.rejection(sample, now: now - 1, requireBattery: true) != nil)
    var changed = sample; changed.stateOfChargePercent.value = 49.9
    #expect(LongPauseSafety.rejection(changed, now: now, requireBattery: true) == .reserveMissingOrStale)
    changed = sample; changed.thermalPressure.value = .fair
    #expect(LongPauseSafety.rejection(changed, now: now, requireBattery: true) == .thermalNotNominalOrStale)
    for value: Double? in [nil, .nan, .infinity, 101] {
        changed = sample; changed.batteryTemperatureCelsius.value = value
        #expect(LongPauseSafety.rejection(changed, now: now, requireBattery: true) == .temperatureMissingInvalidOrStale)
    }
    changed = sample; changed.batteryTemperatureCelsius.quality = .derived
    #expect(LongPauseSafety.rejection(changed, now: now, requireBattery: true) == .temperatureMissingInvalidOrStale)
    changed = sample; changed.supplyingSource.value = .adapter
    #expect(LongPauseSafety.rejection(changed, now: now, requireBattery: false) == nil)
    #expect(LongPauseSafety.rejection(changed, now: now, requireBattery: true) == .powerSourceUnavailableOrUnexpected)
}
