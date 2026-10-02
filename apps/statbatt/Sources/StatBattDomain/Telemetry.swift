import Foundation

public enum ValueQuality: String, Codable, Sendable {
    case observed, derived, estimated, unavailable, stale, invalid
}

/// Values retain acquisition time and provenance. Unavailable and invalid are never zero.
public struct Metric<Value: Codable & Sendable>: Codable, Sendable {
    public var value: Value?
    public var quality: ValueQuality
    public var sampledAtUTC: Date
    public var sampledAtContinuousNanoseconds: UInt64
    public var source: String
    public var unavailableReason: String?

    public init(value: Value?, quality: ValueQuality, sampledAtUTC: Date = Date(),
                sampledAtContinuousNanoseconds: UInt64 = 0, source: String,
                unavailableReason: String? = nil) {
        self.value = quality == .unavailable || quality == .invalid ? nil : value
        self.quality = quality
        self.sampledAtUTC = sampledAtUTC
        self.sampledAtContinuousNanoseconds = sampledAtContinuousNanoseconds
        self.source = source
        self.unavailableReason = unavailableReason
    }

    public static func unavailable(reason: String = "Not provided", sampledAtUTC: Date = Date(),
                                   sampledAtContinuousNanoseconds: UInt64 = 0,
                                   source: String = "unavailable") -> Self {
        Self(value: nil, quality: .unavailable, sampledAtUTC: sampledAtUTC,
             sampledAtContinuousNanoseconds: sampledAtContinuousNanoseconds,
             source: source, unavailableReason: reason)
    }

    private enum CodingKeys: String, CodingKey {
        case value, quality, sampledAtUTC, sampledAtContinuousNanoseconds, source, unavailableReason
    }
    public init(from decoder: any Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        quality = try fields.decode(ValueQuality.self, forKey: .quality)
        value = try fields.decodeIfPresent(Value.self, forKey: .value)
        if (quality == .unavailable || quality == .invalid) && value != nil {
            throw DecodingError.dataCorruptedError(forKey: .value, in: fields, debugDescription: "Unavailable/invalid metric must have nil value")
        }
        sampledAtUTC = try fields.decode(Date.self, forKey: .sampledAtUTC)
        sampledAtContinuousNanoseconds = try fields.decode(UInt64.self, forKey: .sampledAtContinuousNanoseconds)
        source = try fields.decode(String.self, forKey: .source)
        unavailableReason = try fields.decodeIfPresent(String.self, forKey: .unavailableReason)
    }

    public func isFresh(at now: UInt64, maximumAgeSeconds: Double = 15,
                        minimumSampleNanoseconds: UInt64 = 0) -> Bool {
        guard [.observed, .derived, .estimated].contains(quality), value != nil,
              sampledAtContinuousNanoseconds >= minimumSampleNanoseconds,
              now >= sampledAtContinuousNanoseconds else { return false }
        return Double(now - sampledAtContinuousNanoseconds) / 1_000_000_000 <= maximumAgeSeconds
    }
}

extension Metric: Equatable where Value: Equatable {}

public enum PowerSource: String, Codable, Sendable { case battery, adapter, ups, unknown }
public enum ThermalPressure: String, Codable, Sendable { case nominal, fair, serious, critical, unknown }

public enum TimeEstimate: Codable, Equatable, Sendable {
    case seconds(Double, provenance: String)
    case unlimited, calculating, unavailable(reason: String)
}

public struct BatterySnapshot: Codable, Sendable {
    public var bootID: UUID
    public var sequence: UInt64
    public var batteryPresent: Metric<Bool>
    public var stateOfChargePercent: Metric<Double>
    public var rawStateOfChargePercent: Metric<Double>
    public var isCharging: Metric<Bool>
    public var adapterAttached: Metric<Bool>
    public var supplyingSource: Metric<PowerSource>
    public var batteryCurrentMilliamps: Metric<Double>
    public var batteryVoltageMillivolts: Metric<Double>
    public var batteryPowerWatts: Metric<Double>
    public var adapterRatedWatts: Metric<Double>
    public var adapterObservedInputWatts: Metric<Double>
    public var batteryTemperatureCelsius: Metric<Double>
    public var cycleCount: Metric<UInt64>
    public var fullChargeCapacityMilliampHours: Metric<Double>
    public var designCapacityMilliampHours: Metric<Double>
    public var healthPercent: Metric<Double>
    public var operatingSystemCondition: Metric<String>
    public var timeToEmpty: TimeEstimate
    public var timeToFull: TimeEstimate
    public var thermalPressure: Metric<ThermalPressure>

    public init(bootID: UUID, sequence: UInt64 = 0, sampledAtUTC: Date = Date(),
                sampledAtContinuousNanoseconds: UInt64 = 0, source: String = "unavailable") {
        self.bootID = bootID
        self.sequence = sequence
        func missing<T: Codable & Sendable>() -> Metric<T> {
            .unavailable(sampledAtUTC: sampledAtUTC,
                         sampledAtContinuousNanoseconds: sampledAtContinuousNanoseconds, source: source)
        }
        batteryPresent = missing(); stateOfChargePercent = missing(); rawStateOfChargePercent = missing()
        isCharging = missing(); adapterAttached = missing(); supplyingSource = missing()
        batteryCurrentMilliamps = missing(); batteryVoltageMillivolts = missing(); batteryPowerWatts = missing()
        adapterRatedWatts = missing(); adapterObservedInputWatts = missing(); batteryTemperatureCelsius = missing()
        cycleCount = missing(); fullChargeCapacityMilliampHours = missing(); designCapacityMilliampHours = missing()
        healthPercent = missing(); operatingSystemCondition = missing(); thermalPressure = missing()
        timeToEmpty = .unavailable(reason: "Not provided"); timeToFull = .unavailable(reason: "Not provided")
    }
}

public protocol TelemetryProvider: Sendable {
    func snapshot() async -> BatterySnapshot
    func updates() -> AsyncStream<BatterySnapshot>
}

public enum MetricDerivation {
    /// Net battery flow only; positive is into the battery, never total charger delivery.
    public static func batteryPower(current: Metric<Double>, voltage: Metric<Double>) -> Metric<Double> {
        guard let milliamps = current.value, let millivolts = voltage.value,
              milliamps.isFinite, millivolts.isFinite, millivolts > 0,
              [.observed, .derived].contains(current.quality), [.observed, .derived].contains(voltage.quality),
              current.sampledAtContinuousNanoseconds == voltage.sampledAtContinuousNanoseconds else {
            return .unavailable(reason: "Current and voltage must be valid contemporaneous samples", source: "derived.batteryPower")
        }
        let watts = milliamps * millivolts / 1_000_000
        guard watts.isFinite else { return .unavailable(reason: "Invalid power", source: "derived.batteryPower") }
        return Metric(value: watts, quality: .derived, sampledAtUTC: current.sampledAtUTC,
                      sampledAtContinuousNanoseconds: current.sampledAtContinuousNanoseconds, source: "derived.batteryPower")
    }

    public static func health(full: Metric<Double>, design: Metric<Double>) -> Metric<Double> {
        guard let capacity = full.value, let denominator = design.value, capacity.isFinite,
              denominator.isFinite, capacity >= 0, denominator > 0,
              [.observed, .derived].contains(full.quality), [.observed, .derived].contains(design.quality),
              full.sampledAtContinuousNanoseconds == design.sampledAtContinuousNanoseconds else {
            return .unavailable(reason: "Valid capacity and positive design capacity required", source: "derived.capacityHealth")
        }
        let percent = capacity / denominator * 100
        guard percent.isFinite else { return .unavailable(reason: "Invalid health ratio", source: "derived.capacityHealth") }
        return Metric(value: percent, quality: .derived, sampledAtUTC: full.sampledAtUTC,
                      sampledAtContinuousNanoseconds: full.sampledAtContinuousNanoseconds, source: "derived.capacityHealth")
    }
}
