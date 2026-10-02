import Foundation
import XCTest
@testable import StatBattDomain

final class PolicyTests: XCTestCase {
    let boot = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let now: UInt64 = 100_000_000_000
    let wall = Date(timeIntervalSince1970: 1_800_000_000)

    func verified(restoration: Bool = true, recovery: Double? = 5) -> Capability {
        Capability(status: .verified, scope: .awakeOnly, reasonCode: nil,
                   evidence: [.init(identifier: "synthetic-fixture", provenance: "testOnly")], verifiedAtUTC: wall,
                   restorationVerified: restoration, crashRecoveryBoundSeconds: recovery)
    }
    func capabilities() -> CapabilitySnapshot {
        var result = CapabilitySnapshot()
        result.canHoldChargePreservingAC = verified(); result.canInhibitAdapter = verified()
        result.canReadControlState = verified(); result.canRestoreOwnedControl = verified()
        result.canObserveBatteryTemperature = verified(); result.verifiedBatteryTemperatureBoundsCelsius = .init(lower: 0, upper: 60)
        return result
    }
    func metric<T: Codable & Sendable>(_ value: T, at time: UInt64? = nil) -> Metric<T> {
        Metric(value: value, quality: .observed, sampledAtUTC: wall,
               sampledAtContinuousNanoseconds: time ?? now, source: "test.synthetic")
    }
    func input(soc: Double = 75, policy: RangePolicy = .init(enabled: true)) -> PolicyInput {
        var snapshot = BatterySnapshot(bootID: boot)
        snapshot.batteryPresent = metric(true); snapshot.stateOfChargePercent = metric(soc)
        snapshot.adapterAttached = metric(true); snapshot.thermalPressure = metric(ThermalPressure.nominal)
        snapshot.batteryTemperatureCelsius = metric(35)
        return PolicyInput(policy: policy, capabilities: capabilities(), telemetry: snapshot,
                           bootID: boot, nowUTC: wall, nowContinuousNanoseconds: now, authorized: true, recoveryComplete: true)
    }
    func override(_ goal: OverrideGoal, seconds: Double = 7_200) throws -> ActiveOverride {
        try ActiveOverride(request: .init(goal: goal, expiresAfterSeconds: seconds), bootID: boot,
                           nowContinuousNanoseconds: now, nowUTC: wall)
    }

    func testInclusiveBandHysteresisAndColdStart() {
        var latch = PolicyLatch()
        let values = [69.0, 70, 75, 80, 79, 71, 70]
        let expected: [ControlEffect] = [.releaseOwnedControls, .releaseOwnedControls, .releaseOwnedControls,
                                         .holdChargingPreservingAC, .holdChargingPreservingAC,
                                         .holdChargingPreservingAC, .releaseOwnedControls]
        for (soc, effect) in zip(values, expected) {
            var value = input(soc: soc); value.priorLatch = latch
            let decision = PolicyReducer.evaluate(value)
            XCTAssertEqual(decision.desiredEffect, effect); XCTAssertNil(decision.reason)
            latch = decision.nextLatch
        }
        XCTAssertEqual(PolicyReducer.evaluate(input(soc: 75)).desiredEffect, .releaseOwnedControls)
    }
    func testInvalidThresholdsAndConsentAreNotClamped() {
        for policy in [RangePolicy(enabled: true, resumeAtPercent: .nan), .init(resumeAtPercent: 9),
                       .init(resumeAtPercent: 79, holdAtPercent: 80), .init(reserveFloorPercent: 19),
                       .init(backend: .adapterCycling), .init(resumeAtPercent: 10, backend: .adapterCycling,
                               adapterCyclingConsent: .init(disclosureVersion: "v1")),
                       .init(temperatureGuardEnabled: true, maximumBatteryTemperatureCelsius: 37,
                             resumeBatteryTemperatureCelsius: 37)] {
            XCTAssertThrowsError(try policy.validate())
        }
        XCTAssertNoThrow(try RangePolicy(resumeAtPercent: 10, holdAtPercent: 12).validate())
    }
    func testUnsupportedCapabilitiesNeverEmitInhibition() {
        var value = input(soc: 90); value.capabilities = CapabilitySnapshot()
        let decision = PolicyReducer.evaluate(value)
        XCTAssertEqual(decision.effects, [.releaseOwnedControls]); XCTAssertEqual(decision.reason, .unsupportedPlatform)
    }
    func testEvidenceAndRestorationRequired() {
        var value = input(soc: 90)
        value.capabilities.canHoldChargePreservingAC.evidence = []
        XCTAssertEqual(PolicyReducer.evaluate(value).reason, .unsupportedPlatform)
        value.capabilities = capabilities(); value.capabilities.canRestoreOwnedControl.restorationVerified = false
        XCTAssertEqual(PolicyReducer.evaluate(value).reason, .unsupportedPlatform)
    }
    func testAuthorizationRecoveryAndNativeFencePrecedeActuation() {
        var value = input(soc: 90); value.authorized = false
        XCTAssertEqual(PolicyReducer.evaluate(value).reason, .authorizationDenied)
        value.authorized = true; value.recoveryComplete = false
        XCTAssertEqual(PolicyReducer.evaluate(value).reason, .recoveryRequired)
        value.recoveryComplete = true; value.ownershipConflict = true
        XCTAssertEqual(PolicyReducer.evaluate(value).reason, .ownershipConflict)
        value.ownershipConflict = false; value.nativeFenceActive = true
        XCTAssertEqual(PolicyReducer.evaluate(value).reason, .nativeModeFenced)
    }
    func testDischargeStopsOnStaleInputAndReserve() throws {
        var value = input(soc: 85); value.activeOverride = try override(.discharge(untilPercent: 70))
        XCTAssertEqual(PolicyReducer.evaluate(value).desiredEffect, .inhibitAdapter)
        value.telemetry.stateOfChargePercent = metric(85, at: now - 15_000_000_001)
        var result = PolicyReducer.evaluate(value)
        XCTAssertEqual(result.desiredEffect, .releaseOwnedControls); XCTAssertTrue(result.cancelOverride)
        value.telemetry.stateOfChargePercent = metric(20)
        result = PolicyReducer.evaluate(value)
        XCTAssertEqual(result.reason, .unsafeReserve); XCTAssertEqual(result.effects, [.releaseOwnedControls])
    }
    func testDischargeCompletionRestoresAdapterBeforeResumingPolicy() throws {
        var value = input(soc: 70, policy: .init(enabled: true, resumeAtPercent: 50, holdAtPercent: 60))
        value.activeOverride = try override(.discharge(untilPercent: 70))
        let decision = PolicyReducer.evaluate(value)
        XCTAssertTrue(decision.cancelOverride)
        XCTAssertEqual(decision.effects, [.releaseOwnedControls, .holdChargingPreservingAC])
    }
    func testDischargeSleepUnplugAndUIQuitRestore() throws {
        var value = input(soc: 85); value.activeOverride = try override(.discharge(untilPercent: 70))
        value.awake = false
        XCTAssertEqual(PolicyReducer.evaluate(value).effects, [.releaseOwnedControls])
        XCTAssertTrue(PolicyReducer.evaluate(value).cancelOverride)
        value.awake = true; value.telemetry.adapterAttached = metric(false)
        XCTAssertEqual(PolicyReducer.evaluate(value).reason, .adapterUnavailable)
        value.telemetry.adapterAttached = metric(true); value.uiQuitRequested = true
        let decision = PolicyReducer.evaluate(value)
        XCTAssertTrue(decision.cancelOverride); XCTAssertEqual(decision.effects.first, .releaseOwnedControls)
    }
    func testPersistentHoldSurvivesUIQuit() {
        var value = input(soc: 85); value.uiQuitRequested = true
        XCTAssertEqual(PolicyReducer.evaluate(value).desiredEffect, .holdChargingPreservingAC)
    }
    func testContinuousExpiryCannotBeExtendedByClockRollback() throws {
        var value = input(soc: 75); value.activeOverride = try override(.holdCharging, seconds: 10)
        value.nowContinuousNanoseconds += 10_000_000_000; value.nowUTC = wall.addingTimeInterval(-3_600)
        let decision = PolicyReducer.evaluate(value)
        XCTAssertTrue(decision.cancelOverride); XCTAssertEqual(decision.desiredEffect, .releaseOwnedControls)
    }
    func testRebootCancelsOverrideWithoutComparingClocksAcrossBoots() throws {
        var value = input(soc: 75); value.activeOverride = try override(.holdCharging)
        value.activeOverride?.bootID = UUID()
        XCTAssertTrue(PolicyReducer.evaluate(value).cancelOverride)
        XCTAssertEqual(PolicyReducer.evaluate(value).desiredEffect, .releaseOwnedControls)
    }
    func testWakeInvalidatesPreWakeSample() {
        var value = input(soc: 90); value.minimumSampleNanoseconds = now + 1
        XCTAssertEqual(PolicyReducer.evaluate(value).reason, .telemetryStale)
        value.minimumSampleNanoseconds = now
        XCTAssertNil(PolicyReducer.evaluate(value).reason)
    }
    func testThermalGuardHysteresisAndOverrideCannotBypassIt() throws {
        var value = input(soc: 75, policy: .init(enabled: true, temperatureGuardEnabled: true))
        value.activeOverride = try override(.allowCharging(untilPercent: 100))
        value.telemetry.batteryTemperatureCelsius = metric(40)
        var decision = PolicyReducer.evaluate(value)
        XCTAssertEqual(decision.effects, [.releaseOwnedControls, .holdChargingPreservingAC])
        value.priorLatch = decision.nextLatch; value.telemetry.batteryTemperatureCelsius = metric(38)
        decision = PolicyReducer.evaluate(value)
        XCTAssertEqual(decision.reason, .thermalGuardActive)
        value.priorLatch = decision.nextLatch; value.telemetry.batteryTemperatureCelsius = metric(37)
        decision = PolicyReducer.evaluate(value)
        XCTAssertNil(decision.reason); XCTAssertEqual(decision.desiredEffect, .releaseOwnedControls)
        XCTAssertFalse(decision.nextLatch.thermalHolding)
    }
    func testThermalMissingStaleAndOutsideBoundsYieldFault() {
        var value = input(policy: .init(enabled: true, temperatureGuardEnabled: true))
        for temp in [Metric<Double>.unavailable(), metric(35, at: now - 16_000_000_000), metric(99)] {
            value.telemetry.batteryTemperatureCelsius = temp
            XCTAssertEqual(PolicyReducer.evaluate(value).reason, .temperatureUnavailable)
            XCTAssertEqual(PolicyReducer.evaluate(value).effects, [.releaseOwnedControls])
        }
    }
    func testThermalStopsDischargeAndNeverUsesAdapterAsFallback() throws {
        var value = input(soc: 85); value.activeOverride = try override(.discharge(untilPercent: 70))
        value.telemetry.thermalPressure = metric(ThermalPressure.serious)
        let decision = PolicyReducer.evaluate(value)
        XCTAssertTrue(decision.cancelOverride); XCTAssertEqual(decision.effects.first, .releaseOwnedControls)
        XCTAssertEqual(decision.desiredEffect, .holdChargingPreservingAC)
        value.capabilities.canHoldChargePreservingAC = Capability()
        value.policy.enabled = false
        XCTAssertEqual(PolicyReducer.evaluate(value).effects, [.releaseOwnedControls])
    }
    func testExpiredChargingOverrideCanceledEvenDuringThermalHold() throws {
        var value = input(); value.activeOverride = try override(.holdCharging, seconds: 1)
        value.nowContinuousNanoseconds += 1_000_000_000
        value.telemetry.thermalPressure = metric(ThermalPressure.critical)
        XCTAssertTrue(PolicyReducer.evaluate(value).cancelOverride)
    }
    func testAdapterInhibitionRequiresIndependentRecoveryBound() throws {
        var value = input(soc: 85); value.activeOverride = try override(.discharge(untilPercent: 70))
        value.capabilities.canInhibitAdapter.crashRecoveryBoundSeconds = nil
        XCTAssertEqual(PolicyReducer.evaluate(value).reason, .unsupportedPlatform)
    }
    func testOverrideValidationAndDurationBound() throws {
        XCTAssertThrowsError(try OverrideRequest(goal: .discharge(untilPercent: 19)).validate(currentPercent: 85))
        XCTAssertThrowsError(try OverrideRequest(goal: .discharge(untilPercent: 85)).validate(currentPercent: 85))
        XCTAssertThrowsError(try OverrideRequest(goal: .holdCharging, expiresAfterSeconds: 86_401).validate(currentPercent: 85))
        XCTAssertThrowsError(try override(.holdCharging, seconds: .infinity))
        XCTAssertNoThrow(try OverrideRequest(goal: .allowCharging(untilPercent: 80)).validate(currentPercent: 85))
    }
    func testTemperaturePolicyRequiresVerifiedChargeGate() {
        var caps = capabilities(); caps.canHoldChargePreservingAC = Capability()
        let policy = RangePolicy(enabled: true, backend: .adapterCycling,
                                 adapterCyclingConsent: .init(disclosureVersion: "v1"), temperatureGuardEnabled: true)
        XCTAssertThrowsError(try policy.validate(capabilities: caps))
    }
}
