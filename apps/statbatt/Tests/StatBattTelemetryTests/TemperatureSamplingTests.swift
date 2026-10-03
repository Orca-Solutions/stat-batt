import Foundation
import Testing
import StatBattDomain
@testable import StatBattTelemetry

private func sample(_ second: UInt64, _ raw: Double?, qualified: Bool = true) -> TemperatureSample {
    TemperatureSample(acquiredAtUTC: Date(timeIntervalSince1970: Double(second)),
        start: second * 1_000_000_000, end: second * 1_000_000_000 + 1,
        packRaw: raw, publicCelsius: nil,
        app: Metric(value: raw.map { $0 / 100 }, quality: .estimated, source: "fixture"), qualifiedTuple: qualified)
}
@Test func temperatureDiagnosticDoesNotQualifyItsOwnConversion() {
    #expect(sample(0, 3450).candidateCelsius == 34.5)
    #expect(sample(0, 3450).appQuality == .estimated)
    #expect(sample(0, 3450, qualified: false).candidateCelsius == nil)
    for raw in [Double.nan, .infinity, -2001, 10001, 34.5] {
        #expect(TemperatureSample.candidate(from: raw) == nil)
    }
}
@Test func repeatedTemperatureValuesDoNotInventSensorCadence() {
    let summary = TemperatureSamplingSummary(samples: [sample(0, 3400), sample(1, 3400), sample(2, 3400)])
    #expect(summary.distinctCandidateCount == 1)
    #expect(summary.valueChangeObservationIntervalsSeconds.isEmpty)
    #expect(summary.publicTemperatureSampleCount == 0)
}
@Test func temperatureObservationIntervalsNeverBridgeGaps() {
    let summary = TemperatureSamplingSummary(samples: [sample(0, 3400), sample(1, 3401), sample(2, 3401),
        sample(3, 3402), sample(4, nil), sample(5, 3403), sample(6, 3404), sample(20, 3405), sample(21, 3406)])
    #expect(summary.valueChangeObservationIntervalsSeconds == [2])
    #expect(summary.missingOrInvalidCount == 1)
}
