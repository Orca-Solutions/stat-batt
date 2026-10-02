import Foundation
import XCTest
import StatBattDomain
@testable import StatBattTelemetry

final class RegistryTelemetryTests: XCTestCase {
    var platform: PlatformFingerprint {
        PlatformFingerprint(model: "Mac16,13", architecture: "arm64", operatingSystemVersion: "27.0.1",
                            operatingSystemBuild: "26A434", firmwareVersion: "mBoot-20457.1.29", providerVersion: "synthetic-test")
    }
    var snapshot: BatterySnapshot {
        var value = BatterySnapshot(bootID: UUID())
        value.batteryPresent = Metric(value: true, quality: .observed, sampledAtUTC: Date(timeIntervalSince1970: 10),
                                     sampledAtContinuousNanoseconds: 10, source: "test.synthetic")
        return value
    }
    func decode(_ battery: [String: Any]?, _ pack: [String: Any]? = ["Temperature": NSNumber(value: 3450)],
                platform candidate: PlatformFingerprint? = nil) -> BatterySnapshot {
        RegistryBatteryDecoder.enrich(snapshot: snapshot, batteryData: battery, packData: pack, platform: candidate ?? platform)
    }
    func testQualifiedNestedPhysicalCapacityAndTemperature() {
        let result = decode(["FullChargeCapacity": NSNumber(value: 5582), "DesignCapacity": NSNumber(value: 5760),
                             "NominalChargeCapacity": NSNumber(value: 5726)])
        XCTAssertEqual(result.fullChargeCapacityMilliampHours.value, 5582)
        XCTAssertEqual(result.designCapacityMilliampHours.value, 5760)
        XCTAssertEqual(result.healthPercent.value!, 96.9097222222, accuracy: 0.000001)
        XCTAssertEqual(result.healthPercent.quality, .derived)
        XCTAssertEqual(result.batteryTemperatureCelsius.value, 34.5)
        XCTAssertEqual(result.batteryTemperatureCelsius.quality, .estimated)
        XCTAssertTrue(result.batteryTemperatureCelsius.source.contains("AppleSmartBatteryPack.BatteryData"))
        XCTAssertNil(result.batteryCurrentMilliamps.value); XCTAssertNil(result.batteryPowerWatts.value)
    }
    func testEveryUnknownFingerprintComponentDisablesEnrichment() {
        var candidates: [PlatformFingerprint] = []
        var value = platform; value.model = "Mac16,12"; candidates.append(value)
        value = platform; value.architecture = "x86_64"; candidates.append(value)
        value = platform; value.operatingSystemVersion = "27.1.0"; candidates.append(value)
        value = platform; value.operatingSystemBuild = "26A435"; candidates.append(value)
        value = platform; value.firmwareVersion = "unknown"; candidates.append(value)
        for candidate in candidates {
            let result = decode(["FullChargeCapacity": NSNumber(value: 5582), "DesignCapacity": NSNumber(value: 5760)], platform: candidate)
            XCTAssertNil(result.fullChargeCapacityMilliampHours.value)
            XCTAssertNil(result.batteryTemperatureCelsius.value)
        }
    }
    func testNoFallbackToPercentagesOrNominalCapacity() {
        let result = decode(["MaxCapacity": NSNumber(value: 100), "CurrentCapacity": NSNumber(value: 100),
                             "NominalChargeCapacity": NSNumber(value: 5726), "DesignCapacity": NSNumber(value: 5760)])
        XCTAssertNil(result.fullChargeCapacityMilliampHours.value); XCTAssertNil(result.healthPercent.value)
    }
    func testMissingNestedDataRetainsUnavailable() {
        let result = decode(nil, nil)
        XCTAssertNil(result.fullChargeCapacityMilliampHours.value)
        XCTAssertNil(result.designCapacityMilliampHours.value)
        XCTAssertNil(result.healthPercent.value)
        XCTAssertNil(result.batteryTemperatureCelsius.value)
    }
    func testRejectsInvalidCapacityNumericEncodings() {
        for bad: Any in [NSNumber(value: true), NSNumber(value: 0), NSNumber(value: 100), NSNumber(value: -1),
                         NSNumber(value: 1_000_000), NSNumber(value: Double.nan), NSNumber(value: Double.infinity),
                         NSNumber(value: 5582.5), "5582"] {
            let result = decode(["FullChargeCapacity": bad, "DesignCapacity": NSNumber(value: 5760)])
            XCTAssertNil(result.fullChargeCapacityMilliampHours.value); XCTAssertNil(result.healthPercent.value)
        }
    }
    func testInvalidTemperatureNeverBecomesCoolOrZero() {
        for bad: Any in [NSNumber(value: true), NSNumber(value: Double.nan), NSNumber(value: 10_001),
                         NSNumber(value: -2_001), NSNumber(value: 3450.5), "3450"] {
            XCTAssertNil(decode(nil, ["Temperature": bad]).batteryTemperatureCelsius.value)
        }
        XCTAssertEqual(decode(nil, ["Temperature": NSNumber(value: 0)]).batteryTemperatureCelsius.value, 0)
    }
    func testHealthOver100IsNotClamped() {
        let result = decode(["FullChargeCapacity": NSNumber(value: 6100), "DesignCapacity": NSNumber(value: 6000)])
        XCTAssertGreaterThan(result.healthPercent.value!, 100)
    }
    func testHealthDoesNotMixPriorCapacityWithNewPartialRead() {
        var previous = snapshot
        previous.fullChargeCapacityMilliampHours = .init(value: 5582, quality: .stale,
            sampledAtContinuousNanoseconds: 10, source: "test.previous")
        let result = RegistryBatteryDecoder.enrich(snapshot: previous,
            batteryData: ["DesignCapacity": NSNumber(value: 5760)], packData: nil, platform: platform)
        XCTAssertNil(result.healthPercent.value)
    }
    func testNoInternalBatteryDoesNotReadPackMetrics() {
        var absent = snapshot
        absent.batteryPresent = .init(value: false, quality: .observed, source: "test.synthetic")
        let result = RegistryBatteryDecoder.enrich(snapshot: absent,
            batteryData: ["FullChargeCapacity": NSNumber(value: 5582), "DesignCapacity": NSNumber(value: 5760)],
            packData: ["Temperature": NSNumber(value: 3450)], platform: platform)
        XCTAssertNil(result.fullChargeCapacityMilliampHours.value)
        XCTAssertNil(result.batteryTemperatureCelsius.value)
    }
    var priorEnrichedSnapshot: BatterySnapshot {
        decode(["FullChargeCapacity": NSNumber(value: 5582), "DesignCapacity": NSNumber(value: 5760)])
    }
    func assertRegistryUnavailable(_ result: BatterySnapshot, file: StaticString = #filePath, line: UInt = #line) {
        for metric in [result.fullChargeCapacityMilliampHours, result.designCapacityMilliampHours,
                       result.healthPercent, result.batteryTemperatureCelsius] {
            XCTAssertNil(metric.value, file: file, line: line)
            XCTAssertEqual(metric.quality, .unavailable, file: file, line: line)
        }
    }
    func testPriorEnrichedValuesClearedWhenNestedDataDisappears() {
        let result = RegistryBatteryDecoder.enrich(snapshot: priorEnrichedSnapshot,
            batteryData: nil, packData: nil, platform: platform)
        assertRegistryUnavailable(result)
    }
    func testPriorEnrichedValuesClearedOnMalformedMeasurements() {
        let result = RegistryBatteryDecoder.enrich(snapshot: priorEnrichedSnapshot,
            batteryData: ["FullChargeCapacity": NSNumber(value: true), "DesignCapacity": NSNumber(value: 0)],
            packData: ["Temperature": "3450"], platform: platform)
        assertRegistryUnavailable(result)
    }
    func testPartialRefreshReplacesOnlyValidFieldsAndClearsOldHealth() {
        let result = RegistryBatteryDecoder.enrich(snapshot: priorEnrichedSnapshot,
            batteryData: ["DesignCapacity": NSNumber(value: 5760)], packData: nil, platform: platform)
        XCTAssertEqual(result.designCapacityMilliampHours.value, 5760)
        XCTAssertNil(result.fullChargeCapacityMilliampHours.value)
        XCTAssertNil(result.healthPercent.value)
        XCTAssertNil(result.batteryTemperatureCelsius.value)
    }
    func testPriorEnrichedValuesClearedWhenProfileBecomesUnknown() {
        let result = RegistryBatteryDecoder.enrich(snapshot: priorEnrichedSnapshot,
            batteryData: ["FullChargeCapacity": NSNumber(value: 5582), "DesignCapacity": NSNumber(value: 5760)],
            packData: ["Temperature": NSNumber(value: 3450)], platform: .unknown)
        assertRegistryUnavailable(result)
    }
    func testWrapperInvalidatesPriorValuesBeforeUnknownProfileReturn() async {
        let prior = priorEnrichedSnapshot
        let result = await MainActor.run { RegistryTelemetry.enrich(snapshot: prior, platform: .unknown) }
        assertRegistryUnavailable(result)
    }
    func testStaleInvalidAndUnavailablePresenceDoNotEnrich() {
        for quality in [ValueQuality.stale, .invalid, .unavailable] {
            var prior = priorEnrichedSnapshot
            prior.batteryPresent.quality = quality
            let result = RegistryBatteryDecoder.enrich(snapshot: prior,
                batteryData: ["FullChargeCapacity": NSNumber(value: 5582), "DesignCapacity": NSNumber(value: 5760)],
                packData: ["Temperature": NSNumber(value: 3450)], platform: platform)
            assertRegistryUnavailable(result)
        }
    }
    func testInvalidationPreservesIndependentPublicTemperature() {
        var prior = priorEnrichedSnapshot
        prior.batteryTemperatureCelsius = .init(value: 31, quality: .observed,
            sampledAtContinuousNanoseconds: 11, source: "apple.iopowersources")
        let result = RegistryBatteryDecoder.enrich(snapshot: prior,
            batteryData: nil, packData: nil, platform: .unknown)
        XCTAssertEqual(result.batteryTemperatureCelsius, prior.batteryTemperatureCelsius)
        XCTAssertNil(result.healthPercent.value)
    }
}
