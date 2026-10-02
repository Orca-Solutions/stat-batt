import Foundation
import IOKit
import StatBattDomain

/// Read-only telemetry qualification. It conveys no charge-control or thermal-policy support.
public enum RegistryBatteryDecoder {
    fileprivate static func hasUsableBatteryPresence(_ snapshot: BatterySnapshot) -> Bool {
        snapshot.batteryPresent.value == true &&
        [.observed, .derived, .estimated].contains(snapshot.batteryPresent.quality)
    }

    public static func isQualified(_ platform: PlatformFingerprint) -> Bool {
        platform.model == "Mac16,13" && platform.architecture == "arm64" &&
        platform.operatingSystemVersion == "27.0.1" && platform.operatingSystemBuild == "26A434" &&
        platform.firmwareVersion == "mBoot-20457.1.29"
    }

    /// Dictionaries are already restricted to fixed measurement keys by the reader.
    /// macOS 27 moved physical capacities to AppleSmartBattery.BatteryData and temperature
    /// to AppleSmartBatteryPack.BatteryData. MaxCapacity/CurrentCapacity remain percentages;
    /// neither is a physical capacity. NominalChargeCapacity is not FullChargeCapacity.
    public static func enrich(snapshot: BatterySnapshot, batteryData: [String: Any]?,
                              packData: [String: Any]?, platform: PlatformFingerprint) -> BatterySnapshot {
        var result = snapshot
        let date = snapshot.batteryPresent.sampledAtUTC
        let nanos = snapshot.batteryPresent.sampledAtContinuousNanoseconds
        func invalidateOwned(_ metric: Metric<Double>, sourcePrefix: String) -> Metric<Double> {
            guard metric.source.hasPrefix(sourcePrefix) else { return metric }
            return .unavailable(reason: "registryMeasurementNotRefreshed", sampledAtUTC: date,
                                sampledAtContinuousNanoseconds: nanos, source: metric.source)
        }
        // Reused snapshots must not carry an earlier registry measurement through a failed
        // acquisition or a capability downgrade. Independently acquired public fields survive.
        result.fullChargeCapacityMilliampHours = invalidateOwned(result.fullChargeCapacityMilliampHours,
            sourcePrefix: "apple.registry.AppleSmartBattery.BatteryData.FullChargeCapacity")
        result.designCapacityMilliampHours = invalidateOwned(result.designCapacityMilliampHours,
            sourcePrefix: "apple.registry.AppleSmartBattery.BatteryData.DesignCapacity")
        result.healthPercent = invalidateOwned(result.healthPercent,
            sourcePrefix: "derived.registry.FullChargeCapacity.dividedBy.DesignCapacity")
        result.batteryTemperatureCelsius = invalidateOwned(result.batteryTemperatureCelsius,
            sourcePrefix: "apple.registry.AppleSmartBatteryPack.BatteryData.Temperature")
        guard isQualified(platform), hasUsableBatteryPresence(snapshot) else { return result }
        func measurement(_ value: Double, quality: ValueQuality = .observed, source: String) -> Metric<Double> {
            Metric(value: value, quality: quality, sampledAtUTC: date,
                   sampledAtContinuousNanoseconds: nanos, source: source)
        }
        let full = positiveCapacity(batteryData?["FullChargeCapacity"])
        let design = positiveCapacity(batteryData?["DesignCapacity"])
        if let full {
            result.fullChargeCapacityMilliampHours = measurement(full,
                source: "apple.registry.AppleSmartBattery.BatteryData.FullChargeCapacity.mAh")
        }
        if let design {
            result.designCapacityMilliampHours = measurement(design,
                source: "apple.registry.AppleSmartBattery.BatteryData.DesignCapacity.mAh")
        }
        if let full, let design {
            result.healthPercent = measurement(full / design * 100, quality: .derived,
                source: "derived.registry.FullChargeCapacity.dividedBy.DesignCapacity")
        }
        if let raw = number(packData?["Temperature"]), raw.rounded() == raw,
           (-2_000...10_000).contains(raw) {
            // Centi-C is supported by the macOS 27 consumer-source path and local raw read.
            // Quality stays estimated pending independent comparison. This range is
            // plausibility filtering, not verified safety bounds.
            result.batteryTemperatureCelsius = measurement(raw / 100, quality: .estimated,
                source: "apple.registry.AppleSmartBatteryPack.BatteryData.Temperature.centiC")
        }
        // Zero current at full charge cannot establish either polarity. No conversion of
        // current or net power is enabled here until nonzero input/output is qualified.
        return result
    }

    private static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite else { return nil }
        return value.doubleValue
    }
    private static func positiveCapacity(_ value: Any?) -> Double? {
        guard let value = number(value), value > 100, value <= 100_000, value.rounded() == value else { return nil }
        return value
    }
}

@MainActor
public enum RegistryTelemetry {
    public static func enrich(snapshot: BatterySnapshot, platform: PlatformFingerprint) -> BatterySnapshot {
        guard RegistryBatteryDecoder.isQualified(platform), RegistryBatteryDecoder.hasUsableBatteryPresence(snapshot) else {
            return RegistryBatteryDecoder.enrich(snapshot: snapshot, batteryData: nil, packData: nil, platform: platform)
        }
        // The OS returns BatteryData as a dictionary. Only these fixed measurement fields
        // survive this private scope; identities, vendor metadata and opaque buffers do not.
        func read(_ serviceName: String, keys: [String]) -> [String: Any]? {
            let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(serviceName))
            guard service != 0 else { return nil }
            defer { IOObjectRelease(service) }
            guard let data = IORegistryEntryCreateCFProperty(service, "BatteryData" as CFString,
                         kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] else { return nil }
            var fields: [String: Any] = [:]
            for key in keys { fields[key] = data[key] }
            return fields
        }
        let battery = read("AppleSmartBattery", keys: ["FullChargeCapacity", "DesignCapacity"])
        let pack = read("AppleSmartBatteryPack", keys: ["Temperature"])
        return RegistryBatteryDecoder.enrich(snapshot: snapshot, batteryData: battery, packData: pack, platform: platform)
    }
}
