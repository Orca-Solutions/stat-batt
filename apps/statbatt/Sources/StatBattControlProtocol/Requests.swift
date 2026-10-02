import Foundation
import StatBattDomain

public struct VersionRange: Codable, Equatable, Sendable {
    public let major: UInt16
    public let minimumMinor: UInt16
    public let maximumMinor: UInt16
    public init(major: UInt16, minimumMinor: UInt16, maximumMinor: UInt16) {
        self.major = major; self.minimumMinor = minimumMinor; self.maximumMinor = maximumMinor
    }
}

public struct NegotiationRequest: WirePayload {
    public static let allowedFields: Set<String> = ["supportedVersions", "appVersion"]
    public let supportedVersions: [VersionRange]
    public let appVersion: String
    public init(supportedVersions: [VersionRange], appVersion: String) {
        self.supportedVersions = supportedVersions; self.appVersion = appVersion
    }
    public func validate() throws {
        guard !supportedVersions.isEmpty, supportedVersions.count <= 8,
              supportedVersions.allSatisfy({ $0.minimumMinor <= $0.maximumMinor }),
              !appVersion.isEmpty, appVersion.utf8.count <= 64,
              appVersion.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-+")).contains($0) }) else {
            throw WireFailure(.malformedRequest)
        }
    }
    public func chosenVersion() throws -> ProtocolVersion {
        try validate()
        guard supportedVersions.contains(where: { $0.major == 1 && $0.minimumMinor == 0 }) else {
            throw WireFailure(.protocolMismatch)
        }
        return ProtocolVersion(major: 1, minor: 0)
    }
}

public struct VersionedRequest: WirePayload {
    public static let allowedFields: Set<String> = ["protocolVersion"]
    public let protocolVersion: ProtocolVersion
    public init(protocolVersion: ProtocolVersion = ProtocolVersion(major: 1, minor: 0)) { self.protocolVersion = protocolVersion }
    public func validate() throws { try requireVersion(protocolVersion) }
}

public struct CommandContext: Codable, Equatable, Sendable {
    public let protocolVersion: ProtocolVersion
    public let commandID: UUID
    public let expected: StateVersion
    public let controlSessionID: UUID
    public init(protocolVersion: ProtocolVersion = ProtocolVersion(major: 1, minor: 0), commandID: UUID = UUID(), expected: StateVersion, controlSessionID: UUID) {
        self.protocolVersion = protocolVersion; self.commandID = commandID
        self.expected = expected; self.controlSessionID = controlSessionID
    }
    public func validate() throws { try requireVersion(protocolVersion) }
}

public struct AdminRecoveryContext: Codable, Sendable {
    public let protocolVersion: ProtocolVersion
    public let commandID: UUID
    public let externalAuthorizationForm: Data
    public init(protocolVersion: ProtocolVersion = ProtocolVersion(major: 1, minor: 0), commandID: UUID = UUID(), externalAuthorizationForm: Data) {
        self.protocolVersion = protocolVersion; self.commandID = commandID
        self.externalAuthorizationForm = externalAuthorizationForm
    }
    /// Length validation is not an Authorization Services right check. Never persist these bytes.
    public func validate() throws {
        try requireVersion(protocolVersion)
        guard externalAuthorizationForm.count == 32 else { throw WireFailure(.malformedRequest, field: "externalAuthorizationForm") }
    }
}

public enum RecoveryAuthority: Codable, Sendable {
    case owner(CommandContext)
    case admin(AdminRecoveryContext)
    public func validate() throws {
        switch self { case .owner(let context): try context.validate(); case .admin(let context): try context.validate() }
    }
}

public struct CommandRequest: WirePayload {
    public static let allowedFields: Set<String> = ["context"]
    public let context: CommandContext
    public init(context: CommandContext) { self.context = context }
    public func validate() throws { try context.validate() }
}

public struct SetPolicyRequest: WirePayload {
    public static let allowedFields: Set<String> = ["context", "policy"]
    public let context: CommandContext
    public let policy: RangePolicy
    public init(context: CommandContext, policy: RangePolicy) { self.context = context; self.policy = policy }
    public func validate() throws {
        try context.validate()
        do { try policy.validate() } catch let error as APIError { throw WireFailure(error.code, field: error.details["field"]) }
        if let pause = policy.maximumBatteryTemperatureCelsius, !pause.isFinite { throw WireFailure(.invalidConfiguration, field: "maximumBatteryTemperatureCelsius") }
        if let resume = policy.resumeBatteryTemperatureCelsius, !resume.isFinite { throw WireFailure(.invalidConfiguration, field: "resumeBatteryTemperatureCelsius") }
        // Exact sensor bounds, readback/restoration and consent provenance are checked by the policy engine.
    }
}

public struct StartOverrideRequest: WirePayload {
    public static let allowedFields: Set<String> = ["context", "request"]
    public let context: CommandContext
    public let request: OverrideRequest
    public init(context: CommandContext, request: OverrideRequest) { self.context = context; self.request = request }
    public func validate() throws {
        try context.validate()
        guard request.expiresAfterSeconds.isFinite, request.expiresAfterSeconds > 0, request.expiresAfterSeconds <= 86_400 else {
            throw WireFailure(.invalidConfiguration, field: "expiresAfterSeconds")
        }
        switch request.goal {
        case .allowCharging(let target): try requireFinite(target, range: 0...100, field: "untilPercent")
        case .discharge(let target): try requireFinite(target, range: 20...100, field: "untilPercent")
        case .holdCharging: break
        }
        // Fresh SOC, reserve and mode capability checks remain on the trusted coordinator side.
    }
}

public enum StopReason: String, Codable, Sendable { case userRequested, applicationQuit, update, recovery }
public struct StopRequest: WirePayload {
    public static let allowedFields: Set<String> = ["authority", "reason"]
    public let authority: RecoveryAuthority
    public let reason: StopReason
    public init(authority: RecoveryAuthority, reason: StopReason) { self.authority = authority; self.reason = reason }
    public func validate() throws { try authority.validate() }
}

public enum SessionRole: String, Codable, Sendable { case read, control }
public struct OpenSessionRequest: WirePayload {
    public static let allowedFields: Set<String> = ["protocolVersion", "role"]
    public let protocolVersion: ProtocolVersion
    public let role: SessionRole
    public init(protocolVersion: ProtocolVersion = ProtocolVersion(major: 1, minor: 0), role: SessionRole) { self.protocolVersion = protocolVersion; self.role = role }
    public func validate() throws { try requireVersion(protocolVersion) }
}

public enum EnrollmentIntent: String, Codable, Sendable { case enroll, transfer }
public struct EnrollOwnerRequest: WirePayload {
    public static let allowedFields: Set<String> = ["context", "expected", "intent"]
    public static var nestedFields: [String: Set<String>] {
        var schemas = WireSchemas.commandObjects
        schemas["$.context"] = WireSchemas.admin
        return schemas
    }
    public let context: AdminRecoveryContext
    public let expected: StateVersion
    public let intent: EnrollmentIntent
    public init(context: AdminRecoveryContext, expected: StateVersion, intent: EnrollmentIntent) {
        self.context = context; self.expected = expected; self.intent = intent
    }
    public func validate() throws { try context.validate() }
}

public struct OperationRequest: WirePayload {
    public static let allowedFields: Set<String> = ["protocolVersion", "operationID"]
    public let protocolVersion: ProtocolVersion
    public let operationID: UUID
    public init(protocolVersion: ProtocolVersion = ProtocolVersion(major: 1, minor: 0), operationID: UUID) {
        self.protocolVersion = protocolVersion; self.operationID = operationID
    }
    public func validate() throws { try requireVersion(protocolVersion) }
}

public struct EventCursor: Codable, Equatable, Sendable {
    public let daemonInstanceID: UUID
    public let sequence: UInt64
    public init(daemonInstanceID: UUID, sequence: UInt64) { self.daemonInstanceID = daemonInstanceID; self.sequence = sequence }
}
public struct SubscribeRequest: WirePayload {
    public static let allowedFields: Set<String> = ["protocolVersion", "cursor"]
    public let protocolVersion: ProtocolVersion
    public let cursor: EventCursor?
    public init(protocolVersion: ProtocolVersion = ProtocolVersion(major: 1, minor: 0), cursor: EventCursor? = nil) {
        self.protocolVersion = protocolVersion; self.cursor = cursor
    }
    public func validate() throws { try requireVersion(protocolVersion) }
}
public struct SubscriptionRequest: WirePayload {
    public static let allowedFields: Set<String> = ["protocolVersion", "subscriptionID", "deliveredCursor"]
    public let protocolVersion: ProtocolVersion
    public let subscriptionID: UUID
    public let deliveredCursor: EventCursor?
    public init(protocolVersion: ProtocolVersion = ProtocolVersion(major: 1, minor: 0), subscriptionID: UUID, deliveredCursor: EventCursor? = nil) {
        self.protocolVersion = protocolVersion; self.subscriptionID = subscriptionID; self.deliveredCursor = deliveredCursor
    }
    public func validate() throws { try requireVersion(protocolVersion) }
}

/// Interface declaration only. There is deliberately no XPC listener or installed helper in this build.
@objc public protocol PowerControlService {
    func negotiate(_ request: Data, reply: @escaping (Data) -> Void)
    func getCapabilities(_ request: Data, reply: @escaping (Data) -> Void)
    func getState(_ request: Data, reply: @escaping (Data) -> Void)
    func enrollOwner(_ request: Data, reply: @escaping (Data) -> Void)
    func openControlSession(_ request: Data, reply: @escaping (Data) -> Void)
    func beginNativeDelegation(_ request: Data, reply: @escaping (Data) -> Void)
    func resolveNativeDelegation(_ request: Data, reply: @escaping (Data) -> Void)
    func setPolicy(_ request: Data, reply: @escaping (Data) -> Void)
    func startOverride(_ request: Data, reply: @escaping (Data) -> Void)
    func cancelOverride(_ request: Data, reply: @escaping (Data) -> Void)
    func stopAndRestore(_ request: Data, reply: @escaping (Data) -> Void)
    func getOperation(_ request: Data, reply: @escaping (Data) -> Void)
    func subscribe(_ request: Data, reply: @escaping (Data) -> Void)
    func acknowledgeEvents(_ request: Data, reply: @escaping (Data) -> Void)
    func unsubscribe(_ request: Data, reply: @escaping (Data) -> Void)
    func prepareUninstall(_ request: Data, reply: @escaping (Data) -> Void)
    func finalizeUninstall(_ request: Data, reply: @escaping (Data) -> Void)
}
@objc public protocol PowerControlEvents { func receive(_ event: Data) }
