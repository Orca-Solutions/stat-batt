import Foundation

public enum SupportStatus: String, Codable, Sendable { case unsupported, unknown, restricted, verified, temporarilyUnavailable }
public enum EnforcementScope: String, Codable, Sendable { case none, appleDelegated, awakeOnly, hardwarePersistentVerified }

public struct PlatformFingerprint: Codable, Equatable, Sendable {
    public var model: String
    public var architecture: String
    public var operatingSystemVersion: String
    public var operatingSystemBuild: String
    public var firmwareVersion: String
    public var providerVersion: String
    public init(model: String, architecture: String, operatingSystemVersion: String,
                operatingSystemBuild: String, firmwareVersion: String, providerVersion: String) {
        self.model = model; self.architecture = architecture; self.operatingSystemVersion = operatingSystemVersion
        self.operatingSystemBuild = operatingSystemBuild; self.firmwareVersion = firmwareVersion; self.providerVersion = providerVersion
    }
    public static let unknown = Self(model: "unknown", architecture: "unknown", operatingSystemVersion: "unknown",
                                     operatingSystemBuild: "unknown", firmwareVersion: "unknown", providerVersion: "unknown")
}

public struct EvidenceReference: Codable, Equatable, Sendable {
    public var identifier: String
    public var provenance: String
    public var reference: String?
    public init(identifier: String, provenance: String, reference: String? = nil) {
        self.identifier = identifier; self.provenance = provenance; self.reference = reference
    }
}

public struct Restriction: Codable, Equatable, Sendable {
    public var operation: String
    public var reasonCode: String
    public var provenance: String
    public var reference: String?
    public init(operation: String, reasonCode: String, provenance: String, reference: String? = nil) {
        self.operation = operation; self.reasonCode = reasonCode; self.provenance = provenance; self.reference = reference
    }
}

public struct ClosedBounds: Codable, Equatable, Sendable {
    public var lower: Double
    public var upper: Double
    public init(lower: Double, upper: Double) { self.lower = lower; self.upper = upper }
    public func contains(_ value: Double) -> Bool {
        lower.isFinite && upper.isFinite && lower <= upper && value.isFinite && value >= lower && value <= upper
    }
}

public struct Capability: Codable, Equatable, Sendable {
    public var status: SupportStatus
    public var scope: EnforcementScope
    public var reasonCode: String?
    public var evidence: [EvidenceReference]
    public var verifiedAtUTC: Date?
    public var maximumObservedActuationLatencySeconds: Double?
    public var restorationVerified: Bool
    public var crashRecoveryBoundSeconds: Double?
    public init(status: SupportStatus = .unsupported, scope: EnforcementScope = .none,
                reasonCode: String? = "No exact-platform verification", evidence: [EvidenceReference] = [],
                verifiedAtUTC: Date? = nil, maximumObservedActuationLatencySeconds: Double? = nil,
                restorationVerified: Bool = false, crashRecoveryBoundSeconds: Double? = nil) {
        self.status = status; self.scope = scope; self.reasonCode = reasonCode; self.evidence = evidence
        self.verifiedAtUTC = verifiedAtUTC; self.maximumObservedActuationLatencySeconds = maximumObservedActuationLatencySeconds
        self.restorationVerified = restorationVerified; self.crashRecoveryBoundSeconds = crashRecoveryBoundSeconds
    }
    public var isVerified: Bool { status == .verified && scope != .none && !evidence.isEmpty && verifiedAtUTC != nil }
}

public struct CapabilitySnapshot: Codable, Sendable {
    public var capabilityRevision: UInt64 = 0
    public var platform: PlatformFingerprint
    public var canMonitorInternalBattery = Capability()
    public var canHoldChargePreservingAC = Capability()
    public var canInhibitAdapter = Capability()
    public var canReadControlState = Capability()
    public var canRestoreOwnedControl = Capability()
    public var canSetNativeChargeLimit = Capability()
    public var allowedNativeLimitsPercent: [Double] = []
    public var nativeCurrentLimitReadable = false
    public var nativeRestorationMode = "none"
    public var canObserveBatteryTemperature = Capability()
    public var verifiedBatteryTemperatureBoundsCelsius: ClosedBounds?
    public var restrictions: [Restriction] = []
    public init(platform: PlatformFingerprint = .unknown) { self.platform = platform }

    public var supportsOwnedControl: Bool {
        canReadControlState.isVerified && canRestoreOwnedControl.isVerified && canRestoreOwnedControl.restorationVerified
    }
    public var supportsTrueHold: Bool {
        supportsOwnedControl && canHoldChargePreservingAC.isVerified && canHoldChargePreservingAC.restorationVerified
    }
    public var supportsBoundedAdapterInhibition: Bool {
        guard supportsOwnedControl, canInhibitAdapter.isVerified, canInhibitAdapter.restorationVerified,
              let recovery = canInhibitAdapter.crashRecoveryBoundSeconds, recovery.isFinite, recovery > 0 else { return false }
        return true
    }
}
