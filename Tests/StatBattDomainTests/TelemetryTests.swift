import Foundation
import XCTest
@testable import StatBattDomain

final class TelemetryTests: XCTestCase {
    func metric(_ value: Double, quality: ValueQuality = .observed, time: UInt64 = 10) -> Metric<Double> {
        Metric(value: value, quality: quality, sampledAtContinuousNanoseconds: time, source: "test.synthetic")
    }
    func testUnknownMetricsAreNotZeroAndRoundTrip() throws {
        let snapshot = BatterySnapshot(bootID: UUID())
        XCTAssertNil(snapshot.stateOfChargePercent.value)
        XCTAssertEqual(snapshot.stateOfChargePercent.quality, .unavailable)
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(BatterySnapshot.self, from: data)
        XCTAssertNil(decoded.batteryCurrentMilliamps.value)
        XCTAssertEqual(decoded.bootID, snapshot.bootID)
    }
    func testSignedNetPowerAndMatchingTimestamps() {
        XCTAssertEqual(MetricDerivation.batteryPower(current: metric(-1_000), voltage: metric(12_000)).value, -12)
        XCTAssertNil(MetricDerivation.batteryPower(current: metric(1_000), voltage: metric(12_000, time: 11)).value)
        XCTAssertNil(MetricDerivation.batteryPower(current: metric(1_000, quality: .stale), voltage: metric(12_000)).value)
        XCTAssertNil(MetricDerivation.batteryPower(current: metric(.infinity), voltage: metric(12_000)).value)
    }
    func testHealthRatioCanExceed100AndRejectsZeroDesign() {
        XCTAssertEqual(MetricDerivation.health(full: metric(5_100), design: metric(5_000)).value, 102)
        XCTAssertNil(MetricDerivation.health(full: metric(5_000), design: metric(0)).value)
    }
    func testUnavailableCannotContainValueInDecodedDTO() throws {
        var metric = metric(0); metric.quality = .unavailable
        let data = try JSONEncoder().encode(metric)
        XCTAssertThrowsError(try JSONDecoder().decode(Metric<Double>.self, from: data))
    }
    func testStalenessBoundaryFutureAndWake() {
        let sample = metric(80, time: 100)
        XCTAssertTrue(sample.isFresh(at: 15_000_000_100))
        XCTAssertFalse(sample.isFresh(at: 15_000_000_101))
        XCTAssertFalse(sample.isFresh(at: 99))
        XCTAssertFalse(sample.isFresh(at: 100, minimumSampleNanoseconds: 101))
    }
}
