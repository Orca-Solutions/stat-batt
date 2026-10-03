import Foundation
import StatBattDomain

/// Closed targets; decoding any other percentage fails before execution.
public enum NativeFixedLimit: UInt8, Codable, CaseIterable, Sendable {
    case eighty = 80, hundred = 100
    public var percent: Double { Double(rawValue) }
    public var expectedShortcutName: String { "StatBatt — Apple Limit \(rawValue)" }
}

public enum NativeLimitPhase: String, Codable, Sendable {
    case notConfigured, ready, requested, acknowledgedUnverified, outcomeUnknown, ownerReconciled
}
public enum NativeLimitFailure: String, Error, Codable, Sendable {
    case unqualifiedTarget, shortcutMissing, shortcutAmbiguous, shortcutIdentityChanged
    case transportUnavailable, malformedListing, outputTooLarge, controllerConflict
    case preflightUnavailable, manualRecoveryRequired, journalUnavailable, anotherInstance
    case invalidConfirmation, executionInProgress, trustNotApproved
    case controllersNotConfirmedStopped, qualificationAlreadyAttempted
}
public enum NativePreflightResult: Sendable { case clear, conflictingController, unavailable }
public enum NativeTrustAcknowledgement: String, Codable, Sendable { case approvedMutableUserWorkflow }

public struct NativeLimitStatus: Sendable {
    public let phase: NativeLimitPhase
    public let lastError: NativeLimitFailure?
    public let shortcut80UUID: UUID?
    public let shortcut100UUID: UUID?
    public let operationID: UUID?
    public let lastRequestedLimit: NativeFixedLimit?
    public let requestedAtUTC: Date?
    public let lastObservedLimit: NativeFixedLimit?
    public let confirmedAtUTC: Date?
    public let qualifiedTarget: Bool
    public let qualifiedLimits: Set<NativeFixedLimit>
    public let trustedLimits: Set<NativeFixedLimit>
    public let journalHealthy: Bool
    public let requiresManualRecovery: Bool
    public let canRequest80: Bool
    public let canRequest100: Bool
    public let canRunSupervised100Qualification: Bool
    public let qualification100AttemptedAtUTC: Date?
}

public enum NativeTargetQualification {
    public static func qualifies(_ platform: PlatformFingerprint) -> Bool {
        platform.model == "Mac16,13" && platform.architecture == "arm64" &&
        platform.operatingSystemVersion == "27.0.1" && platform.operatingSystemBuild == "26A434" &&
        platform.firmwareVersion == "mBoot-20457.1.29"
    }
    /// A supervised trial is deliberately excluded from this production evidence allowlist.
    public static func qualifiedLimits(_ platform: PlatformFingerprint) -> Set<NativeFixedLimit> {
        qualifies(platform) ? [.eighty] : []
    }
}
public struct NativeShortcutIdentity: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public init(id: UUID, name: String) { self.id = id; self.name = name }
}
/// Only the coordinator constructs this after owner trust and fresh identity checks.
/// It does not establish immutable workflow content integrity.
public struct TrustedNativeShortcut: Sendable {
    public let id: UUID
    public let limit: NativeFixedLimit
    init(id: UUID, limit: NativeFixedLimit) { self.id = id; self.limit = limit }
}
public enum NativeExecutionResult: Sendable, Equatable {
    case acknowledged, failed, timedOut, cancelled, outputOverflow, notLaunched
}
public protocol NativeShortcutTransport: Sendable {
    func listShortcuts() async throws -> [NativeShortcutIdentity]
    func executeTrusted(_ shortcut: TrustedNativeShortcut) async -> NativeExecutionResult
}
public struct NativeTrustRecord: Codable, Sendable {
    public let limit: NativeFixedLimit
    public let shortcutUUID: UUID
    public let expectedName: String
    public let acknowledgement: NativeTrustAcknowledgement
    public let approvedAtUTC: Date
    /// Historical setup evidence retained when migrating schema1; new setup needs no return loop.
    public let confirmedBaselinePercent: Double?
    public let confirmedOtherControllersStopped: Bool
    public let platform: PlatformFingerprint
}
public struct NativeLimitJournal: Codable, Sendable {
    public let schemaVersion: UInt16
    public let ownerUID: UInt32
    public var trust80: NativeTrustRecord?
    public var trust100: NativeTrustRecord?
    public var phase: NativeLimitPhase
    public var operationID: UUID?
    public var requestedLimit: NativeFixedLimit?
    public var requestedAtUTC: Date?
    public var observedLimit: NativeFixedLimit?
    public var confirmedAtUTC: Date?
    public var priorShortcutCompletedOrStoppedAtUTC: Date?
    public var qualification100AttemptedAtUTC: Date?
    // Decoder metadata only: migration must be durably saved before requests become eligible.
    var needsMigration = false
    private enum CodingKeys: String, CodingKey {
        case schemaVersion, ownerUID, trust80, trust100, phase, operationID, requestedLimit
        case requestedAtUTC, observedLimit, confirmedAtUTC, priorShortcutCompletedOrStoppedAtUTC
        case qualification100AttemptedAtUTC
    }
    public init(ownerUID: UInt32) {
        schemaVersion = 2; self.ownerUID = ownerUID; phase = .notConfigured
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(UInt16.self, forKey: .schemaVersion)
        self.init(ownerUID: try container.decode(UInt32.self, forKey: .ownerUID))
        if version == 1 {
            let legacy = try LegacyNativeLimitJournal(from: decoder)
            try legacy.validate()
            needsMigration = true
            if let trust = legacy.trust {
                trust80 = NativeTrustRecord(limit: .eighty, shortcutUUID: trust.shortcutUUID,
                    expectedName: trust.expectedName, acknowledgement: trust.acknowledgement,
                    approvedAtUTC: trust.approvedAtUTC, confirmedBaselinePercent: trust.confirmedBaselinePercent,
                    confirmedOtherControllersStopped: trust.confirmedOtherControllersStopped, platform: trust.platform)
            }
            operationID = legacy.operationID
            requestedAtUTC = legacy.requestedAtUTC
            requestedLimit = operationID == nil ? nil : .eighty
            confirmedAtUTC = legacy.confirmedAtUTC
            priorShortcutCompletedOrStoppedAtUTC = legacy.priorShortcutCompletedOrStoppedAtUTC
            switch legacy.phase {
            case .notConfigured: phase = .notConfigured
            case .ready: phase = .ready
            case .requested, .outcomeUnknown: phase = .outcomeUnknown
            case .acknowledgedUnverified: phase = .acknowledgedUnverified
            case .manuallyConfirmed80:
                // Schema1 allowed confirming80 after an unknown result, without a finished check.
                phase = .outcomeUnknown; observedLimit = .eighty
            case .restoredUserConfirmed100: phase = .ownerReconciled; observedLimit = .hundred
            }
            return
        }
        guard version == 2 else { throw NativeLimitFailure.journalUnavailable }
        trust80 = try container.decodeIfPresent(NativeTrustRecord.self, forKey: .trust80)
        trust100 = try container.decodeIfPresent(NativeTrustRecord.self, forKey: .trust100)
        phase = try container.decode(NativeLimitPhase.self, forKey: .phase)
        operationID = try container.decodeIfPresent(UUID.self, forKey: .operationID)
        requestedLimit = try container.decodeIfPresent(NativeFixedLimit.self, forKey: .requestedLimit)
        requestedAtUTC = try container.decodeIfPresent(Date.self, forKey: .requestedAtUTC)
        observedLimit = try container.decodeIfPresent(NativeFixedLimit.self, forKey: .observedLimit)
        confirmedAtUTC = try container.decodeIfPresent(Date.self, forKey: .confirmedAtUTC)
        priorShortcutCompletedOrStoppedAtUTC = try container.decodeIfPresent(Date.self, forKey: .priorShortcutCompletedOrStoppedAtUTC)
        qualification100AttemptedAtUTC = try container.decodeIfPresent(Date.self, forKey: .qualification100AttemptedAtUTC)
    }
    public func trust(for limit: NativeFixedLimit) -> NativeTrustRecord? { limit == .eighty ? trust80 : trust100 }
    public var requiresManualRecovery: Bool { phase == .requested || phase == .outcomeUnknown }
    public func validate(ownerUID: UInt32) throws {
        guard schemaVersion == 2, self.ownerUID == ownerUID else { throw NativeLimitFailure.journalUnavailable }
        for limit in NativeFixedLimit.allCases {
            if let trust = trust(for: limit) {
                guard trust.limit == limit, trust.expectedName == limit.expectedShortcutName,
                      trust.confirmedBaselinePercent == nil || trust.confirmedBaselinePercent == 100,
                      NativeTargetQualification.qualifies(trust.platform), trust.confirmedOtherControllersStopped,
                      trust.approvedAtUTC.timeIntervalSinceReferenceDate.isFinite else { throw NativeLimitFailure.journalUnavailable }
            }
        }
        if let trust80, let trust100, trust80.shortcutUUID == trust100.shortcutUUID { throw NativeLimitFailure.journalUnavailable }
        guard (trust80 != nil || trust100 != nil) == (phase != .notConfigured),
              (operationID == nil) == (requestedAtUTC == nil),
              (operationID == nil) == (requestedLimit == nil),
              (observedLimit == nil) == (confirmedAtUTC == nil) else { throw NativeLimitFailure.journalUnavailable }
        if let requestedLimit { guard trust(for: requestedLimit) != nil else { throw NativeLimitFailure.journalUnavailable } }
        if [.requested, .acknowledgedUnverified, .outcomeUnknown].contains(phase) {
            guard operationID != nil else { throw NativeLimitFailure.journalUnavailable }
        }
        if phase == .ownerReconciled {
            guard observedLimit != nil, priorShortcutCompletedOrStoppedAtUTC != nil else { throw NativeLimitFailure.journalUnavailable }
        }
        for date in [requestedAtUTC, confirmedAtUTC, priorShortcutCompletedOrStoppedAtUTC, qualification100AttemptedAtUTC].compactMap({ $0 }) {
            guard date.timeIntervalSinceReferenceDate.isFinite else { throw NativeLimitFailure.journalUnavailable }
        }
    }
}

private struct LegacyNativeLimitJournal: Decodable {
    enum Phase: String, Decodable { case notConfigured, ready, requested, acknowledgedUnverified, outcomeUnknown, manuallyConfirmed80, restoredUserConfirmed100 }
    struct Trust: Decodable {
        let shortcutUUID: UUID
        let expectedName: String
        let acknowledgement: NativeTrustAcknowledgement
        let approvedAtUTC: Date
        let confirmedBaselinePercent: Double
        let confirmedOtherControllersStopped: Bool
        let platform: PlatformFingerprint
    }
    let schemaVersion: UInt16
    let ownerUID: UInt32
    let trust: Trust?
    let phase: Phase
    let operationID: UUID?
    let requestedAtUTC: Date?
    let confirmedAtUTC: Date?
    let priorShortcutCompletedOrStoppedAtUTC: Date?
    func validate() throws {
        guard schemaVersion == 1, (trust != nil) == (phase != .notConfigured) else { throw NativeLimitFailure.journalUnavailable }
        if let trust {
            guard trust.expectedName == NativeFixedLimit.eighty.expectedShortcutName,
                  trust.confirmedBaselinePercent == 100, NativeTargetQualification.qualifies(trust.platform),
                  trust.confirmedOtherControllersStopped,
                  trust.approvedAtUTC.timeIntervalSinceReferenceDate.isFinite else { throw NativeLimitFailure.journalUnavailable }
        }
        if [.requested, .acknowledgedUnverified, .outcomeUnknown, .manuallyConfirmed80].contains(phase) {
            guard operationID != nil, requestedAtUTC != nil else { throw NativeLimitFailure.journalUnavailable }
        }
        if [.manuallyConfirmed80, .restoredUserConfirmed100].contains(phase) {
            guard confirmedAtUTC != nil else { throw NativeLimitFailure.journalUnavailable }
        }
        if phase == .restoredUserConfirmed100 {
            guard priorShortcutCompletedOrStoppedAtUTC != nil else { throw NativeLimitFailure.journalUnavailable }
        }
        for date in [requestedAtUTC, confirmedAtUTC, priorShortcutCompletedOrStoppedAtUTC].compactMap({ $0 }) {
            guard date.timeIntervalSinceReferenceDate.isFinite else { throw NativeLimitFailure.journalUnavailable }
        }
    }
}
public protocol NativeLimitJournalStorage: Sendable {
    func load() throws -> NativeLimitJournal?
    /// Must atomically replace and durably flush before reporting success.
    func save(_ journal: NativeLimitJournal) throws
}
public protocol NativeLimitInstanceLock: Sendable {
    /// Hold the same-account advisory lock for the coordinator's lifetime.
    func acquire() throws
}
