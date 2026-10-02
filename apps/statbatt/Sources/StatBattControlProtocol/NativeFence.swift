import Foundation
import StatBattDomain

public enum NativeFencePhase: String, Codable, Sendable { case restoringCustom, readyForNative, nativeDelegated, nativeOutcomeUnknown }
public enum NativeBaselineProvenance: String, Codable, Sendable { case observed, explicitUserConfirmation }
public struct NativeIntent: Codable, Sendable {
    public let limitPercent: Double
    public let agreedReturnLimitPercent: Double
    public let baselineProvenance: NativeBaselineProvenance
    public init(limitPercent: Double, agreedReturnLimitPercent: Double, baselineProvenance: NativeBaselineProvenance) {
        self.limitPercent = limitPercent; self.agreedReturnLimitPercent = agreedReturnLimitPercent; self.baselineProvenance = baselineProvenance
    }
    public func validate() throws {
        try requireFinite(limitPercent, range: 80...100, field: "limitPercent")
        try requireFinite(agreedReturnLimitPercent, range: 80...100, field: "agreedReturnLimitPercent")
        // The trusted coordinator must additionally check the exact verified discrete target allowlist.
    }
}
public struct BeginNativeDelegationRequest: WirePayload {
    public static let allowedFields: Set<String> = ["context", "intent"]
    public static var nestedFields: [String: Set<String>] {
        var schemas = WireSchemas.commandObjects
        schemas["$.intent"] = ["limitPercent", "agreedReturnLimitPercent", "baselineProvenance"]
        return schemas
    }
    public let context: CommandContext
    public let intent: NativeIntent
    public init(context: CommandContext, intent: NativeIntent) { self.context = context; self.intent = intent }
    public func validate() throws { try context.validate(); try intent.validate() }
}

public struct NativeFenceRecord: Codable, Sendable {
    public let fenceID: UUID
    public let ownerUID: UInt32
    public let generation: UUID
    public let commandID: UUID
    public let intent: NativeIntent
    public var phase: NativeFencePhase
}

public enum NativeReconciliation: Codable, Sendable {
    case observedLimit(percent: Double)
    case visibleUserConfirmation(percent: Double, disclosureVersion: String)
    fileprivate func matches(_ expected: Double) -> Bool {
        switch self {
        case .observedLimit(let percent): return percent.isFinite && percent == expected
        case .visibleUserConfirmation(let percent, let disclosure): return percent.isFinite && percent == expected && !disclosure.isEmpty && disclosure.utf8.count <= 64
        }
    }
}

/// Serializable state-transition contract; callers must persist each result before its effect.
/// No shortcut runs here. No TTL, disconnect, reboot or session change clears a fence.
public struct NativeFenceContract: Codable, Sendable {
    public private(set) var fence: NativeFenceRecord?
    public private(set) var customPolicyEnabled = false
    public init() {}
    private enum CodingKeys: String, CodingKey { case fence, customPolicyEnabled }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fence = try container.decodeIfPresent(NativeFenceRecord.self, forKey: .fence)
        customPolicyEnabled = try container.decode(Bool.self, forKey: .customPolicyEnabled)
        if let fence {
            try fence.intent.validate()
            guard !customPolicyEnabled else { throw WireFailure(.recoveryRequired) }
        }
    }
    public var customActivationAllowed: Bool { fence == nil }
    public mutating func enableCustomPolicy() throws {
        guard customActivationAllowed else { throw WireFailure(.nativeModeFenced) }
        customPolicyEnabled = true
    }
    public mutating func begin(ownerUID: UInt32, version: StateVersion, commandID: UUID, intent: NativeIntent) throws -> UUID {
        try intent.validate()
        guard fence == nil else { throw WireFailure(.nativeModeFenced) }
        customPolicyEnabled = false
        let id = UUID()
        fence = NativeFenceRecord(fenceID: id, ownerUID: ownerUID, generation: version.generation, commandID: commandID, intent: intent, phase: .restoringCustom)
        return id
    }
    public mutating func customRestorationCompleted(verified: Bool) throws {
        guard var record = fence, record.phase == .restoringCustom else { throw WireFailure(.recoveryRequired) }
        guard verified else { throw WireFailure(.restoreFailed) }
        record.phase = .readyForNative
        fence = record
    }
    public mutating func recordOwnerNativeOutcome(requesterUID: UInt32, fenceID: UUID, generation: UUID, settingObserved: Bool) throws {
        guard var record = fence, record.fenceID == fenceID, record.generation == generation else { throw WireFailure(.revisionConflict) }
        guard record.ownerUID == requesterUID else { throw WireFailure(.ownerConflict) }
        guard record.phase == .readyForNative || record.phase == .nativeOutcomeUnknown else { throw WireFailure(.recoveryRequired) }
        record.phase = settingObserved ? .nativeDelegated : .nativeOutcomeUnknown
        fence = record
    }
    public mutating func reconcileOwner(requesterUID: UInt32, fenceID: UUID, generation: UUID, evidence: NativeReconciliation) throws {
        guard let record = fence, record.fenceID == fenceID, record.generation == generation else { throw WireFailure(.revisionConflict) }
        guard record.ownerUID == requesterUID else { throw WireFailure(.ownerConflict) }
        try reconcile(fenceID: fenceID, generation: generation, evidence: evidence)
    }
    /// Invoke only after the trusted helper independently checks its fixed fresh-admin right.
    /// This narrow transition cannot apply a native intent, change attribution or enable custom.
    public mutating func reconcileAfterAdminAuthorization(fenceID: UUID, generation: UUID, evidence: NativeReconciliation) throws {
        try reconcile(fenceID: fenceID, generation: generation, evidence: evidence)
    }
    private mutating func reconcile(fenceID: UUID, generation: UUID, evidence: NativeReconciliation) throws {
        guard let record = fence, record.fenceID == fenceID, record.generation == generation else { throw WireFailure(.revisionConflict) }
        guard record.phase != .restoringCustom else { throw WireFailure(.restoreFailed) }
        guard evidence.matches(record.intent.agreedReturnLimitPercent) else { throw WireFailure(.nativeLimitUnobservable) }
        fence = nil
        customPolicyEnabled = false
    }
    public mutating func stopCustom() { customPolicyEnabled = false }
    public func checkUninstallReadiness() throws {
        guard fence == nil else { throw WireFailure(.uninstallNotReady) }
    }
}
