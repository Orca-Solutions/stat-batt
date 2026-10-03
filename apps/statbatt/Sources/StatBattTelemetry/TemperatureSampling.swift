import Foundation
import IOKit
import IOKit.ps
import StatBattDomain

/// Fixed-property, normal-user diagnostic. Acquisition time is not sensor conversion time.
public struct TemperatureSample: Codable, Sendable {
    public let acquiredAtUTC: Date
    public let acquisitionStartNanoseconds: UInt64
    public let acquisitionEndNanoseconds: UInt64
    public let packRaw: Double?
    public let candidateCelsius: Double?
    public let publicIOPSCelsius: Double?
    public let appCelsius: Double?
    public let appQuality: ValueQuality
    public let appAcquiredAtNanoseconds: UInt64
    public init(acquiredAtUTC: Date, start: UInt64, end: UInt64, packRaw: Double?, publicCelsius: Double?,
                app: Metric<Double>, qualifiedTuple: Bool) {
        self.acquiredAtUTC = acquiredAtUTC; acquisitionStartNanoseconds = start; acquisitionEndNanoseconds = end
        self.packRaw = packRaw.flatMap { $0.isFinite ? $0 : nil }
        candidateCelsius = qualifiedTuple ? Self.candidate(from: packRaw) : nil
        publicIOPSCelsius = publicCelsius.flatMap { $0.isFinite && (-20...100).contains($0) ? $0 : nil }
        appCelsius = app.value; appQuality = app.quality; appAcquiredAtNanoseconds = app.sampledAtContinuousNanoseconds
    }
    public static func candidate(from raw: Double?) -> Double? {
        guard let raw, raw.isFinite, raw.rounded() == raw, (-2000...10000).contains(raw) else { return nil }
        return raw / 100
    }
}

public struct TemperatureSamplingSummary: Codable, Sendable {
    public let sampleCount: Int
    public let validCandidateCount: Int
    public let missingOrInvalidCount: Int
    public let distinctCandidateCount: Int
    public let minimumCandidateCelsius: Double?
    public let maximumCandidateCelsius: Double?
    public let valueChangeObservationIntervalsSeconds: [Double]
    public let publicTemperatureSampleCount: Int
    public let intervalLimitations: String
    public init(samples: [TemperatureSample]) {
        sampleCount = samples.count
        let values = samples.compactMap(\.candidateCelsius)
        validCandidateCount = values.count; missingOrInvalidCount = samples.count - values.count
        distinctCandidateCount = Set(values).count
        minimumCandidateCelsius = values.min(); maximumCandidateCelsius = values.max()
        publicTemperatureSampleCount = samples.filter { $0.publicIOPSCelsius != nil }.count
        var previous: TemperatureSample?
        var lastChange: UInt64?
        var intervals: [Double] = []
        for sample in samples {
            guard sample.candidateCelsius != nil, sample.acquisitionEndNanoseconds >= sample.acquisitionStartNanoseconds else {
                previous = nil; lastChange = nil; continue
            }
            if let prior = previous {
                guard sample.acquisitionStartNanoseconds > prior.acquisitionEndNanoseconds else {
                    previous = nil; lastChange = nil; continue
                }
                // Do not bridge a missing sample, sleep or scheduling gap as a normal 1 Hz observation.
                if sample.acquisitionStartNanoseconds - prior.acquisitionStartNanoseconds > 2_000_000_000 {
                    lastChange = nil
                } else if prior.candidateCelsius != sample.candidateCelsius {
                    if let lastChange {
                        intervals.append(Double(sample.acquisitionStartNanoseconds - lastChange) / 1_000_000_000)
                    }
                    lastChange = sample.acquisitionStartNanoseconds
                }
            }
            previous = sample
        }
        valueChangeObservationIntervalsSeconds = intervals
        intervalLimitations = "Intervals separate observed value changes, not sensor conversions. Repeated values do not prove fresh or stale sensor data; true sensor age/calibration remain unknown."
    }
}

@MainActor public enum TemperatureSampler {
    public static func sample(reader: PublicTelemetry, platform: PlatformFingerprint) -> TemperatureSample {
        let start = SampleClock.nowNanoseconds(), date = Date()
        var raw: Double?
        let pack = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBatteryPack"))
        if pack != 0 {
            defer { IOObjectRelease(pack) }
            if let fields = IORegistryEntryCreateCFProperty(pack, "BatteryData" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                raw = PublicBatteryDecoder.number(fields["Temperature"])
            }
        }
        // Independent public field lookup, before StatBatt's registry enrichment can replace it.
        var publicCelsius: Double?
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for item in list {
                if let fields = IOPSGetPowerSourceDescription(info, item)?.takeUnretainedValue() as? [String: Any],
                   fields[kIOPSTypeKey] as? String == kIOPSInternalBatteryType {
                    publicCelsius = PublicBatteryDecoder.number(fields[kIOPSTemperatureKey]); break
                }
            }
        }
        let app = reader.snapshot().batteryTemperatureCelsius
        return TemperatureSample(acquiredAtUTC: date, start: start, end: SampleClock.nowNanoseconds(),
            packRaw: raw, publicCelsius: publicCelsius, app: app, qualifiedTuple: RegistryBatteryDecoder.isQualified(platform))
    }
}
