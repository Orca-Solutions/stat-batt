import Foundation
import IOKit
import StatBattDomain

public struct DiagnosticReport: Codable, Sendable {
    public let schemaVersion: Int
    public let applicationVersion: String
    public let generatedAtUTC: Date
    public let platform: PlatformFingerprint
    public let capabilities: CapabilitySnapshot
    public let telemetry: BatterySnapshot
    public let helperState: String
    public let nativeState: String
    public let limitations: [String]

    public init(platform: PlatformFingerprint, telemetry: BatterySnapshot,
                capabilities: CapabilitySnapshot? = nil, nativeState: String = "notConfigured") {
        schemaVersion = 1
        applicationVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        generatedAtUTC = Date(); self.platform = platform; self.telemetry = telemetry
        self.capabilities = capabilities ?? CapabilityProbe.readOnly(platform: platform, snapshot: telemetry)
        self.nativeState = nativeState
        helperState = "notQueried"
        limitations = ["This read-only report does not query temperature-control service admission. Configured trusted user shortcuts request Apple limits on the qualified target; command completion is not a current-limit reading.",
                       "Pack temperature is estimated on the qualified target; current polarity remains unverified. Health is derived from reported physical capacities.",
                       "Public battery readings do not reveal why macOS paused charging.",
                       "This diagnostic does not query helper installation or perform SMC writes. Native reconciliation is user-confirmed; precise physical charge cutoff is not established."]
    }
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, output in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            var container = output.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return try encoder.encode(self)
    }
}

@MainActor
public enum PlatformProbe {
    public static func readOnly() -> PlatformFingerprint {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        #if arch(arm64)
        let architecture = "arm64"
        #else
        let architecture = "unsupportedArchitecture"
        #endif
        // These fixed reads exclude serial numbers and machine UUIDs.
        let model = PublicTelemetry.sysctlString("hw.model") ?? "unknown"
        let build = PublicTelemetry.sysctlString("kern.osversion") ?? "unknown"
        let chosen = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/chosen")
        var firmware = "unknown"
        if chosen != 0 {
            defer { IOObjectRelease(chosen) }
            if let data = IORegistryEntryCreateCFProperty(chosen, "system-firmware-version" as CFString,
                                                          kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data,
               let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters),
               !text.isEmpty, text.count < 100 {
                firmware = text
            }
        }
        return PlatformFingerprint(model: model, architecture: architecture,
            operatingSystemVersion: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            operatingSystemBuild: build, firmwareVersion: firmware, providerVersion: "public-telemetry-0.1.0")
    }
}

public enum CapabilityProbe {
    public static func readOnly(platform: PlatformFingerprint, snapshot: BatterySnapshot) -> CapabilitySnapshot {
        var result = CapabilitySnapshot(platform: platform)
        result.capabilityRevision = 1
        if snapshot.batteryPresent.value == true && snapshot.stateOfChargePercent.value != nil {
            result.canMonitorInternalBattery = Capability(status: .verified, scope: .awakeOnly,
                reasonCode: nil, evidence: [EvidenceReference(identifier: "public-snapshot",
                    provenance: "observed", reference: "IOPowerSources")], verifiedAtUTC: Date())
        }
        result.canSetNativeChargeLimit = Capability(status: .unknown,
            reasonCode: "Native80%/100% setting/readback passed on the recorded target; trusted runtime setup and manual reconciliation are required.")
        result.canHoldChargePreservingAC.reasonCode = "No charge-gate backend has passed exact-device verification."
        result.canInhibitAdapter = Capability(status: .unknown, reasonCode: "Consult the authenticated temperature-control service for exact-build admission; this report does not query it.")
        result.canReadControlState = Capability(status: .unknown, reasonCode: "This report does not query the privileged control readback provider.")
        result.canRestoreOwnedControl = Capability(status: .unknown, reasonCode: "This report does not query owned control or recovery state.")
        result.canObserveBatteryTemperature = Capability(status: .unknown,
            reasonCode: "Pack temperature remains estimated; optional convenience-policy admission is separate from verified sensor accuracy.")
        return result
    }
}
