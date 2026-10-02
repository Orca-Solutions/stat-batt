import Foundation
import StatBattDomain

public enum CommandKind: String, Codable, Sendable { case setPolicy, startOverride, cancelOverride, stopAndRestore, beginNativeDelegation, resolveNativeDelegation, prepareUninstall }
public enum CommandOutcome: String, Codable, Sendable { case acceptedPending, appliedVerified, noChange, rejected, partialFailure, outcomeUnknown }

/// The complete typed owner intent. Admission derives its own canonical replay identity;
/// callers cannot omit a field or accidentally include a connection-bound session token.
public enum OwnerCommand: Sendable {
    case setPolicy(SetPolicyRequest)
    case startOverride(StartOverrideRequest)
    case cancelOverride(CommandRequest)
    case stopAndRestore(context: CommandContext, reason: StopReason)
    case beginNativeDelegation(BeginNativeDelegationRequest)

    public var context: CommandContext {
        switch self {
        case .setPolicy(let request): return request.context
        case .startOverride(let request): return request.context
        case .cancelOverride(let request): return request.context
        case .stopAndRestore(let context, _): return context
        case .beginNativeDelegation(let request): return request.context
        }
    }
    public var kind: CommandKind {
        switch self {
        case .setPolicy: return .setPolicy
        case .startOverride: return .startOverride
        case .cancelOverride: return .cancelOverride
        case .stopAndRestore: return .stopAndRestore
        case .beginNativeDelegation: return .beginNativeDelegation
        }
    }
    fileprivate func normalizedPayload() throws -> Data {
        let body: NormalizedOwnerIntent.Body
        switch self {
        case .setPolicy(let request): try request.validate(); body = .policy(request.policy)
        case .startOverride(let request): try request.validate(); body = .override(request.request)
        case .cancelOverride(let request): try request.validate(); body = .cancelOverride
        case .stopAndRestore(let context, let reason): try context.validate(); body = .stop(reason)
        case .beginNativeDelegation(let request): try request.validate(); body = .native(request.intent)
        }
        return try BoundedCodec().encode(NormalizedOwnerIntent(protocolVersion: context.protocolVersion,
            commandID: context.commandID, expected: context.expected, kind: kind, body: body))
    }
}

/// A session authorizes this delivery, while expected lineage/revision and every actual intent
/// field identify the durable command across reconnects. Never persist authorization forms.
private struct NormalizedOwnerIntent: WirePayload {
    enum Body: Codable, Sendable {
        case policy(RangePolicy)
        case override(OverrideRequest)
        case cancelOverride
        case stop(StopReason)
        case native(NativeIntent)
    }
    static let allowedFields: Set<String> = ["protocolVersion", "commandID", "expected", "kind", "body"]
    let protocolVersion: ProtocolVersion
    let commandID: UUID
    let expected: StateVersion
    let kind: CommandKind
    let body: Body
    func validate() throws { try requireVersion(protocolVersion) }
}

/// Server-side credentials. These must come from a successfully authenticated XPC connection,
/// never a request body. This package does not install or authenticate a connection.
public struct ConnectionCredentials: Sendable {
    public let connectionID: UUID
    public let effectiveUID: UInt32
    public let auditSessionID: UInt32
    public init(connectionID: UUID, effectiveUID: UInt32, auditSessionID: UInt32) {
        self.connectionID = connectionID; self.effectiveUID = effectiveUID; self.auditSessionID = auditSessionID
    }
}

public struct AdmissionReceipt: Codable, Equatable, Sendable {
    public let commandID: UUID
    public let operationID: UUID
    public let version: StateVersion
    public var outcome: CommandOutcome
}

public struct AdmissionRecord: Codable, Sendable {
    public let ownerUID: UInt32
    public let kind: CommandKind
    public let expected: StateVersion
    public let normalizedPayload: Data
    public let acceptedAtUTC: Date
    public var receipt: AdmissionReceipt
}

public struct AdmissionCheckpoint: Codable, Sendable {
    public var version: StateVersion
    public let ownerUID: UInt32
    public var records: [AdmissionRecord]
    public init(version: StateVersion, ownerUID: UInt32, records: [AdmissionRecord] = []) {
        self.version = version; self.ownerUID = ownerUID; self.records = records
    }
}

public struct CommandAdmission: Sendable {
    public let receipt: AdmissionReceipt
    public let isReplay: Bool
}

/// Serialized, non-actuating contract harness. Production must atomically durably persist the
/// returned checkpoint before any effect, and resolve interrupted writes by journal/readback.
/// An admission is never evidence of a hardware change. This actor has no provider or XPC listener.
public actor CommandAdmissionLedger {
    private struct Session: Sendable { let id: UUID; let credentials: ConnectionCredentials }
    private var state: AdmissionCheckpoint
    private var sessions: [UUID: Session] = [:]
    private var outstanding: [UUID: Set<UUID>] = [:]
    public static let retentionSeconds: TimeInterval = 7 * 24 * 60 * 60

    public init(version: StateVersion, ownerUID: UInt32) { state = AdmissionCheckpoint(version: version, ownerUID: ownerUID) }
    public init(restoring checkpoint: AdmissionCheckpoint) {
        state = checkpoint
        // Never replay an interrupted actuation merely because a reply was lost.
        for index in state.records.indices where state.records[index].receipt.outcome == .acceptedPending {
            state.records[index].receipt.outcome = .outcomeUnknown
        }
    }

    public func checkpoint() -> AdmissionCheckpoint { state }
    public func openOwnerSession(for credentials: ConnectionCredentials) throws -> UUID {
        guard credentials.effectiveUID == state.ownerUID else { throw WireFailure(.ownerConflict) }
        let token = UUID()
        sessions[credentials.connectionID] = Session(id: token, credentials: credentials)
        return token
    }
    public func disconnect(_ connectionID: UUID) { sessions[connectionID] = nil; outstanding[connectionID] = nil }

    public func admit(_ command: OwnerCommand, credentials: ConnectionCredentials, nowUTC: Date) throws -> CommandAdmission {
        let context = command.context
        let kind = command.kind
        try context.validate()
        guard credentials.effectiveUID == state.ownerUID else { throw WireFailure(.ownerConflict) }
        guard let session = sessions[credentials.connectionID], session.id == context.controlSessionID,
              session.credentials.effectiveUID == credentials.effectiveUID,
              session.credentials.auditSessionID == credentials.auditSessionID else { throw WireFailure(.controlSessionExpired) }
        guard nowUTC.timeIntervalSinceReferenceDate.isFinite else { throw WireFailure(.malformedRequest) }
        let normalizedPayload = try command.normalizedPayload()
        state.records.removeAll { nowUTC.timeIntervalSince($0.acceptedAtUTC) >= Self.retentionSeconds }
        if let prior = state.records.first(where: { $0.ownerUID == credentials.effectiveUID && $0.kind == kind && $0.receipt.commandID == context.commandID }) {
            guard prior.normalizedPayload == normalizedPayload, prior.expected == context.expected else { throw WireFailure(.idempotencyConflict) }
            return CommandAdmission(receipt: prior.receipt, isReplay: true)
        }
        guard kind == .stopAndRestore || context.expected == state.version else { throw WireFailure(.revisionConflict) }
        // Safety Stop must remain available when ordinary command admission is saturated.
        guard kind == .stopAndRestore || outstanding[credentials.connectionID, default: []].count < TransportLimits.maximumOutstandingCommands else { throw WireFailure(.rateLimited) }
        guard state.version.revision < UInt64.max else { throw WireFailure(.recoveryRequired) }
        state.version.revision += 1
        let receipt = AdmissionReceipt(commandID: context.commandID, operationID: UUID(), version: state.version, outcome: .acceptedPending)
        state.records.append(AdmissionRecord(ownerUID: credentials.effectiveUID, kind: kind, expected: context.expected, normalizedPayload: normalizedPayload, acceptedAtUTC: nowUTC, receipt: receipt))
        outstanding[credentials.connectionID, default: []].insert(receipt.operationID)
        return CommandAdmission(receipt: receipt, isReplay: false)
    }

    public func recordOutcome(operationID: UUID, outcome: CommandOutcome) throws -> AdmissionReceipt {
        guard outcome != .acceptedPending,
              let index = state.records.firstIndex(where: { $0.receipt.operationID == operationID }) else { throw WireFailure(.operationNotFound) }
        state.records[index].receipt.outcome = outcome
        for connection in Array(outstanding.keys) { outstanding[connection]?.remove(operationID) }
        return state.records[index].receipt
    }
}
