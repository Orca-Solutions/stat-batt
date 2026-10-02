import Foundation
import XCTest
@testable import StatBattDomain

final class NotificationTests: XCTestCase {
    private let boot = UUID()
    private let second: UInt64 = 1_000_000_000
    private func sample(_ sequence: UInt64, seconds: UInt64, percent: Double = 50,
                        temperature: Double = 35, charging: Bool = true,
                        source: PowerSource = .adapter) -> BatterySnapshot {
        let now = seconds * second
        var result = BatterySnapshot(bootID: boot, sequence: sequence,
            sampledAtContinuousNanoseconds: now)
        func metric<T: Codable & Sendable>(_ value: T) -> Metric<T> {
            Metric(value: value, quality: .observed, sampledAtContinuousNanoseconds: now, source: "fixture")
        }
        result.batteryPresent = metric(true); result.stateOfChargePercent = metric(percent)
        result.batteryTemperatureCelsius = metric(temperature); result.isCharging = metric(charging)
        result.supplyingSource = metric(source)
        return result
    }
    private func enabled() -> BatteryNotificationReducer {
        BatteryNotificationReducer(settings: .init(enabled: true))
    }

    func testStartupAndEnableDoNotInventCrossings() {
        var reducer = BatteryNotificationReducer()
        reducer.observe(sample(1, seconds: 1, percent: 10, temperature: 45), nowNanoseconds: second)
        XCTAssertTrue(reducer.drain(nowNanoseconds: second).isEmpty)
        reducer.configure(.init(enabled: true))
        reducer.observe(sample(2, seconds: 2, percent: 10, temperature: 45), nowNanoseconds: 2 * second)
        XCTAssertTrue(reducer.drain(nowNanoseconds: 2 * second).isEmpty)
    }

    func testChargingAndBatterySourceTransitionsShareDelivery() {
        var reducer = enabled()
        reducer.observe(sample(1, seconds: 1), nowNanoseconds: second)
        reducer.observe(sample(2, seconds: 2, charging: false, source: .battery), nowNanoseconds: 2 * second)
        let result = reducer.drain(nowNanoseconds: 2 * second)
        XCTAssertEqual(result.map(\.category), [.charging, .powerSource])
        XCTAssertTrue(result.last!.message.contains("battery power"))
        XCTAssertTrue(reducer.drain(nowNanoseconds: 3 * second).isEmpty)
    }

    func testCooldownPreservesThresholdCrossingsAndAllCategories() {
        var reducer = enabled()
        reducer.observe(sample(1, seconds: 1), nowNanoseconds: second)
        reducer.observe(sample(2, seconds: 2, charging: false), nowNanoseconds: 2 * second)
        XCTAssertEqual(reducer.drain(nowNanoseconds: 2 * second).map(\.category), [.charging])
        reducer.observe(sample(3, seconds: 10, percent: 20, temperature: 40, charging: false), nowNanoseconds: 10 * second)
        reducer.recordFailure(id: "storage", message: "Recovery record unavailable.")
        XCTAssertTrue(reducer.drain(nowNanoseconds: 10 * second).isEmpty)
        reducer.observe(sample(4, seconds: 40, percent: 19, temperature: 41, charging: false), nowNanoseconds: 40 * second)
        XCTAssertTrue(reducer.drain(nowNanoseconds: 61 * second).isEmpty)
        XCTAssertEqual(reducer.drain(nowNanoseconds: 62 * second).map(\.category), [.failure, .temperature, .lowBattery])
    }

    func testRepeatedThresholdCrossingsRemainBoundedAndLatestSourceWins() {
        var reducer = enabled()
        reducer.observe(sample(1, seconds: 1), nowNanoseconds: second)
        reducer.observe(sample(2, seconds: 2, source: .battery), nowNanoseconds: 2 * second)
        _ = reducer.drain(nowNanoseconds: 2 * second)
        for index in 3...30 {
            reducer.observe(sample(UInt64(index), seconds: UInt64(index), percent: index % 2 == 0 ? 19 : 21,
                source: index % 2 == 0 ? .battery : .adapter), nowNanoseconds: UInt64(index) * second)
        }
        let alerts = reducer.drain(nowNanoseconds: 62 * second)
        XCTAssertEqual(alerts.map(\.category), [.lowBattery, .powerSource])
        XCTAssertTrue(alerts.last!.message.contains("battery power"))
    }

    func testFailureDeduplicatesUntilReconciled() {
        var reducer = enabled()
        reducer.recordFailure(id: "unknown", message: "Review required.")
        XCTAssertEqual(reducer.drain(nowNanoseconds: second).count, 1)
        reducer.recordFailure(id: "unknown", message: "Review required.")
        XCTAssertTrue(reducer.drain(nowNanoseconds: 100 * second).isEmpty)
        reducer.clearFailure()
        reducer.recordFailure(id: "unknown", message: "Review required.")
        XCTAssertEqual(reducer.drain(nowNanoseconds: 100 * second).count, 1)
    }

    func testMutedCategoriesAndDisableClearPending() {
        var reducer = BatteryNotificationReducer(settings: .init(enabled: true, chargingTransitions: false,
            temperature: false, failures: false))
        reducer.observe(sample(1, seconds: 1), nowNanoseconds: second)
        reducer.observe(sample(2, seconds: 2, percent: 19, temperature: 45, charging: false, source: .battery), nowNanoseconds: 2 * second)
        reducer.recordFailure(id: "failure", message: "Unavailable.")
        XCTAssertEqual(reducer.drain(nowNanoseconds: 2 * second).map(\.category), [.lowBattery])
        reducer.observe(sample(3, seconds: 3, percent: 21), nowNanoseconds: 3 * second)
        reducer.observe(sample(4, seconds: 4, percent: 19), nowNanoseconds: 4 * second)
        reducer.configure(.init(enabled: false))
        XCTAssertTrue(reducer.drain(nowNanoseconds: 100 * second).isEmpty)
    }

    func testSleepClearsQueuedCrossingsAndWakeBaseline() {
        var reducer = enabled()
        reducer.observe(sample(1, seconds: 1), nowNanoseconds: second)
        reducer.observe(sample(2, seconds: 2, charging: false), nowNanoseconds: 2 * second)
        _ = reducer.drain(nowNanoseconds: 2 * second)
        reducer.observe(sample(3, seconds: 3, percent: 19), nowNanoseconds: 3 * second)
        reducer.suspend()
        reducer.observe(sample(4, seconds: 100, percent: 10, charging: false, source: .battery), nowNanoseconds: 100 * second)
        XCTAssertTrue(reducer.drain(nowNanoseconds: 100 * second).isEmpty)
    }

    func testUnavailableStaleAndFutureSamplesCannotAlertOrBridge() {
        for quality in [ValueQuality.unavailable, .invalid, .stale] {
            var reducer = enabled()
            reducer.observe(sample(1, seconds: 1), nowNanoseconds: second)
            var missing = sample(2, seconds: 2, percent: 19, temperature: 45, charging: false, source: .battery)
            missing.batteryPresent.quality = quality
            reducer.observe(missing, nowNanoseconds: 2 * second)
            reducer.observe(sample(3, seconds: 3, percent: 19, temperature: 45, charging: false, source: .battery), nowNanoseconds: 3 * second)
            XCTAssertTrue(reducer.drain(nowNanoseconds: 3 * second).isEmpty)
        }
        var reducer = enabled()
        reducer.observe(sample(1, seconds: 1), nowNanoseconds: second)
        reducer.observe(sample(2, seconds: 2, percent: 19), nowNanoseconds: 100 * second)
        XCTAssertTrue(reducer.drain(nowNanoseconds: 100 * second).isEmpty)
        reducer.observe(sample(3, seconds: 200, percent: 10), nowNanoseconds: 101 * second)
        XCTAssertTrue(reducer.drain(nowNanoseconds: 101 * second).isEmpty)
    }

    func testMissingTemperatureDoesNotBridgeAndEstimatedTemperatureCanNotify() {
        var reducer = enabled()
        reducer.observe(sample(1, seconds: 1), nowNanoseconds: second)
        var missing = sample(2, seconds: 2)
        missing.batteryTemperatureCelsius = .unavailable()
        reducer.observe(missing, nowNanoseconds: 2 * second)
        reducer.observe(sample(3, seconds: 3, temperature: 45), nowNanoseconds: 3 * second)
        XCTAssertTrue(reducer.drain(nowNanoseconds: 3 * second).isEmpty)
        reducer.observe(sample(4, seconds: 4, temperature: 35), nowNanoseconds: 4 * second)
        var estimated = sample(5, seconds: 5, temperature: 45)
        estimated.batteryTemperatureCelsius.quality = .estimated
        reducer.observe(estimated, nowNanoseconds: 5 * second)
        XCTAssertEqual(reducer.drain(nowNanoseconds: 5 * second).map(\.category), [.temperature])
    }

    func testOutOfOrderAndNewBootDoNotCreateFalseCrossings() {
        var reducer = enabled()
        reducer.observe(sample(2, seconds: 2, percent: 19), nowNanoseconds: 2 * second)
        reducer.observe(sample(1, seconds: 1, percent: 50), nowNanoseconds: 3 * second)
        reducer.observe(sample(3, seconds: 3, percent: 19), nowNanoseconds: 3 * second)
        XCTAssertTrue(reducer.drain(nowNanoseconds: 3 * second).isEmpty)
        var restarted = sample(1, seconds: 4, percent: 10, temperature: 45)
        restarted.bootID = UUID()
        reducer.observe(restarted, nowNanoseconds: 4 * second)
        XCTAssertTrue(reducer.drain(nowNanoseconds: 4 * second).isEmpty)
    }
}
