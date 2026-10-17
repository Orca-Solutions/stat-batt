import Foundation
import Testing
@testable import StatBattDomain

struct MonitorReadingsTests {
    private func sample(at nanos: UInt64 = 1_000_000_000) -> BatterySnapshot {
        var result = BatterySnapshot(bootID: UUID(), sampledAtContinuousNanoseconds: nanos)
        result.stateOfChargePercent = Metric(value: 80, quality: .observed, sampledAtContinuousNanoseconds: nanos, source: "synthetic")
        result.isCharging = Metric(value: false, quality: .observed, sampledAtContinuousNanoseconds: nanos, source: "synthetic")
        result.supplyingSource = Metric(value: .adapter, quality: .observed, sampledAtContinuousNanoseconds: nanos, source: "synthetic")
        result.timeToFull = .seconds(600, provenance: "synthetic")
        return result
    }

    @Test func idleCadenceAndMissedSamplesHaveDistinctFreshnessFromControl() {
        let snapshot = sample()
        #expect(!snapshot.stateOfChargePercent.isFresh(at: 31_000_000_000))
        #expect(MonitorReadings.validated(snapshot, at: 31_000_000_000).stateOfChargePercent.value == 80)
        #expect(MonitorReadings.validated(snapshot, at: 61_000_000_000).stateOfChargePercent.value == 80)
        let expired = MonitorReadings.validated(snapshot, at: 61_000_000_001)
        #expect(expired.stateOfChargePercent.value == nil)
        #expect(expired.supplyingSource.value == nil)
        #expect(expired.timeToFull == .unavailable(reason: "monitorSampleExpired"))
    }

    @Test func preWakeAndFutureSamplesCannotLookCurrent() {
        let snapshot = sample()
        #expect(MonitorReadings.validated(snapshot, at: 1_000_000_001, minimumSampleNanoseconds: 1_000_000_001).stateOfChargePercent.value == nil)
        #expect(MonitorReadings.validated(snapshot, at: 999_999_999).isCharging.value == nil)
    }

    @Test func mutatedInvalidNumbersNeverReachIntegerOrChartFormatting() {
        var snapshot = sample()
        snapshot.stateOfChargePercent.value = .infinity
        snapshot.fullChargeCapacityMilliampHours = Metric(value: Double.greatestFiniteMagnitude, quality: .observed,
            sampledAtContinuousNanoseconds: 1_000_000_000, source: "synthetic")
        snapshot.batteryTemperatureCelsius = Metric(value: 0, quality: .estimated,
            sampledAtContinuousNanoseconds: 1_000_000_000, source: "synthetic")
        let result = MonitorReadings.validated(snapshot, at: 1_000_000_000)
        #expect(result.stateOfChargePercent.value == nil)
        #expect(result.fullChargeCapacityMilliampHours.value == nil)
        #expect(result.batteryTemperatureCelsius.value == 0)
        #expect(result.batteryTemperatureCelsius.quality == .estimated)
    }

    @Test func staleAndUnavailablePayloadsAreNotResurrected() {
        var snapshot = sample()
        snapshot.stateOfChargePercent.quality = .stale
        snapshot.isCharging.quality = .unavailable
        let result = MonitorReadings.validated(snapshot, at: 1_000_000_000)
        #expect(result.stateOfChargePercent.value == nil)
        #expect(result.isCharging.value == nil)
    }
}
