import Foundation
import StatBattDomain

public enum NativeLimitPhase: String, Codable, Sendable {
    case notConfigured, ready, requested, acknowledgedUnverified, outcomeUnknown
    case manuallyConfirmed80, restoredUserConfirmed100
}

public enum NativeLimitFailure: String, Error, Codable, Sendable {
    case unqualifiedTarget, shortcutMissing, shortcutAmbiguous, shortcutIdentityChanged
    case transportUnavailable, malformedListing, outputTooLarge, controllerConflict
    case preflightUnavailable, manualRecoveryRequired, journalUnavailable, anotherInstance
    case invalidConfirmation, executionInProgress, trustNotApproved
    case controllersNotConfirmedStopped
}

public enum NativePreflightResult: Sendable { case clear, conflictingController, unavailable }
public enum NativeTrustAcknowledgement: String, Codable, Sendable { case approvedMutableUserWorkflow }

public struct NativeLimitStatus: Sendable {
    public let phase: NativeLimitPhase
    public let lastError: NativeLimitFailure?
    public let shortcutUUID: UUID?
    public let baselinePercent: Double?
    public let operationID: UUID?
    public let trustApprovedAtUTC: Date?
    public let qualifiedTarget: Bool
    public let journalHealthy: Bool
    public let requiresManualRecovery: Bool
    public let canRequest80: Bool
}

public enum NativeTargetQualification {
    public static func qualifies(_ platform: PlatformFingerprint) -> Bool {
        platform.model == "Mac16,13" && platform.architecture == "arm64" &&
        platform.operatingSystemVersion == "27.0.1" && platform.operatingSystemBuild == "26A434" &&
        platform.firmwareVersion == "mBoot-20457.1.29"
    }
}

public struct NativeShortcutIdentity: Sendable, Equatable {
    public let id: UUID
    public let name: String
    public init(id: UUID, name: String) { self.id = id; self.name = name }
}

/// Only the coordinator can construct this token after checking approved setup and identity.
/// It represents the owner's mutable-workflow trust, not verified action content.
public struct TrustedNative80Shortcut: Sendable {
    public let id: UUID
    init(id: UUID) { self.id = id }
}

public enum NativeExecutionResult: Sendable, Equatable {
    case acknowledged
    case failed
    case timedOut
    case cancelled
    case outputOverflow
    case notLaunched
}

public protocol NativeShortcutTransport: Sendable {
    func listShortcuts() async throws -> [NativeShortcutIdentity]
    func executeTrusted80(_ shortcut: TrustedNative80Shortcut) async -> NativeExecutionResult
}

public struct NativeTrustRecord: Codable, Sendable {
    public let shortcutUUID: UUID
    public let expectedName: String
    public let acknowledgement: NativeTrustAcknowledgement
    public let approvedAtUTC: Date
    public let confirmedBaselinePercent: Double
    public let confirmedOtherControllersStopped: Bool
    public let platform: PlatformFingerprint
}

public struct NativeLimitJournal: Codable, Sendable {
    public let schemaVersion: UInt16
    public let ownerUID: UInt32
    public var trust: NativeTrustRecord?
    public var phase: NativeLimitPhase
    public var operationID: UUID?
    public var requestedAtUTC: Date?
    public var confirmedAtUTC: Date?
    public var priorShortcutCompletedOrStoppedAtUTC: Date?
    public init(ownerUID: UInt32) {
        schemaVersion = 1; self.ownerUID = ownerUID; trust = nil; phase = .notConfigured
        operationID = nil; requestedAtUTC = nil; confirmedAtUTC = nil
        priorShortcutCompletedOrStoppedAtUTC = nil
    }
    public func validate(ownerUID: UInt32) throws {
        guard schemaVersion == 1, self.ownerUID == ownerUID else { throw NativeLimitFailure.journalUnavailable }
        if let trust {
            guard trust.expectedName == NativeLimitCoordinator.expectedShortcutName,
                  trust.confirmedBaselinePercent == 100, NativeTargetQualification.qualifies(trust.platform),
                  trust.confirmedOtherControllersStopped,
                  trust.approvedAtUTC.timeIntervalSinceReferenceDate.isFinite else { throw NativeLimitFailure.journalUnavailable }
        }
        guard (trust != nil) == (phase != .notConfigured) else { throw NativeLimitFailure.journalUnavailable }
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
    /// Must atomically replace and durably flush the journal before reporting success.
    func save(_ journal: NativeLimitJournal) throws
}

public protocol NativeLimitInstanceLock: Sendable {
    /// Hold the same-account advisory lock for the coordinator's lifetime.
    func acquire() throws
}
