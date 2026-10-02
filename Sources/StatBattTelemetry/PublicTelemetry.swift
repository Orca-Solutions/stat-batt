import Foundation
import IOKit
import IOKit.ps
import Darwin
import StatBattDomain

public enum SampleClock {
    public static func nowNanoseconds() -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return UInt64(Double(mach_continuous_time()) * Double(info.numer) / Double(info.denom))
    }
}

/// Maps only documented public fields. No registry dictionaries or identities leave this boundary.
public enum PublicBatteryDecoder {
    public static func decode(_ fields: [String: Any]?, bootID: UUID, sequence: UInt64,
                              date: Date, nanoseconds: UInt64, source: PowerSource,
                              adapterWatts: Double?, acquisitionSucceeded: Bool = true) -> BatterySnapshot {
        let origin = "apple.iopowersources"
        var result = BatterySnapshot(bootID: bootID, sequence: sequence, sampledAtUTC: date,
                                     sampledAtContinuousNanoseconds: nanoseconds, source: origin)
        func metric<T: Codable & Sendable>(_ value: T?, quality: ValueQuality = .observed,
                                          reason: String = "notReported") -> Metric<T> {
            Metric(value: value, quality: value == nil ? .unavailable : quality,
                   sampledAtUTC: date, sampledAtContinuousNanoseconds: nanoseconds,
                   source: origin, unavailableReason: value == nil ? reason : nil)
        }
        result.supplyingSource = metric(source)
        result.adapterRatedWatts = metric(adapterWatts.flatMap { $0.isFinite && $0 > 0 ? $0 : nil })
        guard let fields else {
            result.batteryPresent = metric(acquisitionSucceeded ? false : nil, reason: "publicSnapshotUnavailable")
            return result
        }
        result.batteryPresent = metric(boolean(fields[kIOPSIsPresentKey]))
        guard result.batteryPresent.value == true else { return result }
        let current = number(fields[kIOPSCurrentCapacityKey])
        let maximum = number(fields[kIOPSMaxCapacityKey])
        if let current, let maximum, current >= 0, maximum > 0, current <= maximum {
            result.stateOfChargePercent = metric(current / maximum * 100, quality: .derived)
        }
        result.isCharging = metric(boolean(fields[kIOPSIsChargingKey]))
        // Supplying source is not proof of physical attachment. The reader obtains the
        // reported ExternalConnected flag separately; its meaning during adapter inhibition
        // still requires backend qualification before it can drive privileged policy.
        result.adapterAttached = metric(nil as Bool?, reason: "attachmentNotReported")
        result.operatingSystemCondition = metric(fields[kIOPSBatteryHealthKey] as? String)
        result.batteryVoltageMillivolts = metric(number(fields[kIOPSVoltageKey]).flatMap { $0 > 0 ? $0 : nil })
        // Public header supplies units but not a guaranteed current polarity for every provider.
        // Keep normalized current/power unavailable until the target sign convention is validated.
        result.batteryCurrentMilliamps = metric(nil as Double?, reason: "currentPolarityNotVerified")
        result.batteryPowerWatts = metric(nil as Double?, reason: "currentPolarityNotVerified")
        result.batteryTemperatureCelsius = metric(number(fields[kIOPSTemperatureKey]).flatMap {
            (-20...100).contains($0) ? $0 : nil
        })
        if source == .battery && result.isCharging.value == false {
            result.timeToEmpty = estimateMinutes(number(fields[kIOPSTimeToEmptyKey]), provenance: origin)
        }
        if result.isCharging.value == true {
            result.timeToFull = estimateMinutes(number(fields[kIOPSTimeToFullChargeKey]), provenance: origin)
        }
        return result
    }

    public static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
              value.doubleValue.isFinite else { return nil }
        return value.doubleValue
    }
    public static func boolean(_ value: Any?) -> Bool? {
        guard let value = value as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return value.boolValue
    }
    public static func estimateMinutes(_ minutes: Double?, provenance: String) -> TimeEstimate {
        guard let minutes else { return .unavailable(reason: "notReported") }
        if minutes == -1 { return .calculating }
        guard minutes > 0, minutes.isFinite, minutes <= 7 * 24 * 60 else { return .unavailable(reason: "invalidEstimate") }
        return .seconds(minutes * 60, provenance: provenance)
    }
}

@MainActor
public final class PublicTelemetry {
    private let platform = PlatformProbe.readOnly()
    private let bootID: UUID
    private var sequence: UInt64 = 0
    private var source: CFRunLoopSource?
    private var timer: Timer?
    private var pending: Task<Void, Never>?
    private var onUpdate: (@MainActor (BatterySnapshot) -> Void)?

    public init() { bootID = UUID(uuidString: Self.sysctlString("kern.bootsessionuuid") ?? "") ?? UUID() }

    public func snapshot() -> BatterySnapshot {
        sequence += 1
        let date = Date(), nanos = SampleClock.nowNanoseconds()
        var fields: [String: Any]?
        var supplying: PowerSource = .unknown
        var acquisitionSucceeded = false
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
            if let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String? {
                switch type {
                case kIOPSACPowerValue: supplying = .adapter
                case kIOPSBatteryPowerValue: supplying = .battery
                case "UPS Power": supplying = .ups
                default: break
                }
            }
            if let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
                acquisitionSucceeded = true
                for item in list {
                    if let description = IOPSGetPowerSourceDescription(info, item)?.takeUnretainedValue() as? [String: Any],
                       description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType {
                        fields = description
                        break
                    }
                }
            }
        }
        let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any]
        var result = PublicBatteryDecoder.decode(fields, bootID: bootID, sequence: sequence,
                            date: date, nanoseconds: nanos, source: supplying,
                            adapterWatts: PublicBatteryDecoder.number(adapter?[kIOPSPowerAdapterWattsKey]),
                            acquisitionSucceeded: acquisitionSucceeded)
        let battery = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if battery != 0 {
            defer { IOObjectRelease(battery) }
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(battery, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            func registryMetric<T: Codable & Sendable>(_ value: T, key: String) -> Metric<T> {
                Metric(value: value, quality: .observed, sampledAtUTC: date,
                       sampledAtContinuousNanoseconds: nanos, source: "apple.registry.AppleSmartBattery.\(key)")
            }
            if let attached = PublicBatteryDecoder.boolean(property("ExternalConnected")) {
                result.adapterAttached = registryMetric(attached, key: "ExternalConnected")
            }
            if let cycles = PublicBatteryDecoder.number(property("CycleCount")),
               cycles >= 0, cycles <= 100_000, cycles.rounded() == cycles {
                result.cycleCount = registryMetric(UInt64(cycles), key: "CycleCount")
            }
            // Registry temperature/capacity/current encodings stay unconverted until independently qualified.
        }
        let thermal: ThermalPressure
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .unknown
        }
        result.thermalPressure = Metric(value: thermal, quality: .observed, sampledAtUTC: date,
                                       sampledAtContinuousNanoseconds: nanos, source: "apple.processinfo")
        return RegistryTelemetry.enrich(snapshot: result, platform: platform)
    }

    public func start(onUpdate: @escaping @MainActor (BatterySnapshot) -> Void) {
        stop()
        self.onUpdate = onUpdate
        source = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let reader = Unmanaged<PublicTelemetry>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { reader.scheduleRefresh() }
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        timer?.tolerance = 3
        refresh()
    }
    public func refresh() { onUpdate?(snapshot()) }
    public func stop() {
        pending?.cancel(); pending = nil
        timer?.invalidate(); timer = nil
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        source = nil
        onUpdate = nil
    }
    private func scheduleRefresh() {
        guard pending == nil else { return }
        pending = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.pending = nil
            self?.refresh()
        }
    }
    public static func sysctlString(_ key: String) -> String? {
        var size: Int = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0, size < 1024 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
