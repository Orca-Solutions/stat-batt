import Foundation
import Testing
import StatBattDomain
@testable import StatBattTelemetry

struct TelemetryTests {
    private func decode(_ fields: [String: Any]?, source: PowerSource = .battery) -> BatterySnapshot {
        PublicBatteryDecoder.decode(fields, bootID: UUID(), sequence: 1, date: Date(timeIntervalSince1970: 0),
                                    nanoseconds: 42, source: source, adapterWatts: nil)
    }
    @Test func capacitiesAreNotPhysicalMilliampHours() {
        let result = decode(["Is Present": true, "Current Capacity": 42, "Max Capacity": 100])
        #expect(result.stateOfChargePercent.value == 42)
        #expect(result.fullChargeCapacityMilliampHours.value == nil)
        #expect(result.healthPercent.value == nil)
    }
    @Test func unknownAndInvalidRemainMissing() {
        let result = decode(["Is Present": true, "Current Capacity": 101, "Max Capacity": 100,
                             "Temperature": 400, "Voltage": -1])
        #expect(result.stateOfChargePercent.value == nil)
        #expect(result.batteryTemperatureCelsius.value == nil)
        #expect(result.batteryVoltageMillivolts.value == nil)
        #expect(result.isCharging.value == nil)
        #expect(result.adapterAttached.value == nil)
    }
    @Test func zeroChargeAndBooleanTypeAreDistinct() {
        #expect(decode(["Is Present": true, "Current Capacity": 0, "Max Capacity": 100]).stateOfChargePercent.value == 0)
        #expect(PublicBatteryDecoder.number(true) == nil)
        #expect(PublicBatteryDecoder.boolean(1) == nil)
        #expect(decode(["Is Present": true, "Current Capacity": true, "Max Capacity": 100]).stateOfChargePercent.value == nil)
    }
    @Test func etaUnitsAndStateValidity() {
        let result = decode(["Is Present": true, "Is Charging": false, "Time to Empty": 30, "Time to Full Charge": 40])
        if case .seconds(let seconds, _) = result.timeToEmpty { #expect(seconds == 1800) }
        else { Issue.record("Expected a valid battery ETA") }
        if case .unavailable = result.timeToFull {} else { Issue.record("Charging ETA invalid while discharging") }
        if case .calculating = PublicBatteryDecoder.estimateMinutes(-1, provenance: "test") {}
        else { Issue.record("Sentinel must remain calculating") }
    }
    @Test func extremeEstimatesRemainUnavailable() {
        for value in [Double.greatestFiniteMagnitude, Double.infinity, Double.nan, 10_081] {
            if case .unavailable = PublicBatteryDecoder.estimateMinutes(value, provenance: "test") {}
            else { Issue.record("Unbounded estimate must be unavailable") }
        }
    }
    @Test func failedSnapshotDoesNotClaimBatteryAbsent() {
        let result = PublicBatteryDecoder.decode(nil, bootID: UUID(), sequence: 1,
            date: Date(), nanoseconds: 42, source: .unknown, adapterWatts: nil, acquisitionSucceeded: false)
        #expect(result.batteryPresent.value == nil)
        #expect(result.batteryPresent.quality == .unavailable)
    }
    @Test func unknownCapabilitiesNeverEnableControls() {
        let caps = CapabilityProbe.readOnly(platform: .unknown, snapshot: decode(nil))
        #expect(!caps.supportsTrueHold)
        #expect(!caps.supportsBoundedAdapterInhibition)
        #expect(caps.allowedNativeLimitsPercent.isEmpty)
        #expect(!caps.canSetNativeChargeLimit.isVerified)
    }
    @Test func attachmentIsNotInferredFromSource() {
        let result = decode(["Is Present": true, "Is Charging": false], source: .adapter)
        #expect(result.supplyingSource.value == .adapter)
        #expect(result.adapterAttached.value == nil)
        #expect(result.batteryCurrentMilliamps.value == nil)
        #expect(result.batteryPowerWatts.value == nil)
    }
}
