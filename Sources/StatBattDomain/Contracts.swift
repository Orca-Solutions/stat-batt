import Foundation

public struct ProtocolVersion: Codable, Equatable, Sendable {
    public var major: UInt16
    public var minor: UInt16
    public init(major: UInt16 = 1, minor: UInt16 = 0) { self.major = major; self.minor = minor }
    public static let current = Self()
}
public struct StateVersion: Codable, Equatable, Sendable {
    public var generation: UUID
    public var revision: UInt64
    public init(generation: UUID = UUID(), revision: UInt64 = 0) { self.generation = generation; self.revision = revision }
}
public enum ErrorCode: String, Codable, Sendable, Error {
    case unauthenticatedPeer, authorizationDenied, ownerConflict, controlSessionExpired
    case protocolMismatch, malformedRequest, payloadTooLarge, revisionConflict, idempotencyConflict
    case unsupportedPlatform, capabilityRestricted, capabilityChanged, helperRequiresApproval, helperUnavailable
    case invalidConfiguration, unsafeReserve, temperatureUnavailable, noInternalBattery, adapterUnavailable
    case telemetryStale, thermalGuardActive, ownershipConflict, providerReadFailed, providerWriteFailed
    case verificationFailed, recoveryRequired, restoreFailed, outcomeUnknown, rateLimited, operationNotFound
    case resyncRequired, uninstallNotReady, nativeLimitUnobservable, nativeShortcutUnavailable, nativeModeFenced
}
public struct APIError: Codable, Sendable, Error {
    public var code: ErrorCode
    public var retryable: Bool
    public var retryAfterSeconds: Double?
    public var details: [String: String]
    public init(code: ErrorCode, retryable: Bool = false, retryAfterSeconds: Double? = nil, details: [String: String] = [:]) {
        self.code = code; self.retryable = retryable; self.retryAfterSeconds = retryAfterSeconds; self.details = details
    }
}

public enum CustomBackend: String, Codable, Sendable { case trueChargeHold, adapterCycling }
public struct ConsentRecord: Codable, Sendable {
    public var recordedAtUTC: Date
    public var disclosureVersion: String
    public init(recordedAtUTC: Date = Date(), disclosureVersion: String) {
        self.recordedAtUTC = recordedAtUTC; self.disclosureVersion = disclosureVersion
    }
}
public struct RangePolicy: Codable, Sendable {
    public var enabled: Bool
    public var resumeAtPercent: Double
    public var holdAtPercent: Double
    public var reserveFloorPercent: Double
    public var backend: CustomBackend
    public var adapterCyclingConsent: ConsentRecord?
    public var temperatureGuardEnabled: Bool
    public var maximumBatteryTemperatureCelsius: Double?
    public var resumeBatteryTemperatureCelsius: Double?
    public init(enabled: Bool = false, resumeAtPercent: Double = 70, holdAtPercent: Double = 80,
                reserveFloorPercent: Double = 20, backend: CustomBackend = .trueChargeHold,
                adapterCyclingConsent: ConsentRecord? = nil, temperatureGuardEnabled: Bool = false,
                maximumBatteryTemperatureCelsius: Double? = 40, resumeBatteryTemperatureCelsius: Double? = 37) {
        self.enabled = enabled; self.resumeAtPercent = resumeAtPercent; self.holdAtPercent = holdAtPercent
        self.reserveFloorPercent = reserveFloorPercent; self.backend = backend; self.adapterCyclingConsent = adapterCyclingConsent
        self.temperatureGuardEnabled = temperatureGuardEnabled; self.maximumBatteryTemperatureCelsius = maximumBatteryTemperatureCelsius
        self.resumeBatteryTemperatureCelsius = resumeBatteryTemperatureCelsius
    }
    /// Structural validation is independent of platform verification and does not silently clamp.
    public func validate() throws {
        guard resumeAtPercent.isFinite, resumeAtPercent >= 10, resumeAtPercent < holdAtPercent else { throw invalid("resumeAtPercent") }
        guard holdAtPercent.isFinite, holdAtPercent <= 100,
              holdAtPercent - resumeAtPercent >= (backend == .trueChargeHold ? 2 : 5) else { throw invalid("holdAtPercent") }
        guard reserveFloorPercent.isFinite, reserveFloorPercent >= 20, reserveFloorPercent <= 100 else { throw invalid("reserveFloorPercent") }
        if backend == .adapterCycling {
            guard resumeAtPercent >= reserveFloorPercent else { throw invalid("resumeAtPercent") }
            guard let consent = adapterCyclingConsent, !consent.disclosureVersion.isEmpty else { throw invalid("adapterCyclingConsent") }
        }
        if temperatureGuardEnabled {
            guard let pause = maximumBatteryTemperatureCelsius, pause.isFinite else { throw invalid("maximumBatteryTemperatureCelsius") }
            guard let resume = resumeBatteryTemperatureCelsius, resume.isFinite, resume < pause else { throw invalid("resumeBatteryTemperatureCelsius") }
        }
    }
    public func validate(capabilities: CapabilitySnapshot) throws {
        try validate()
        guard enabled else { return }
        let supported = backend == .trueChargeHold ? capabilities.supportsTrueHold : capabilities.supportsBoundedAdapterInhibition
        guard supported else { throw APIError(code: .unsupportedPlatform, details: ["field": "backend"]) }
        if temperatureGuardEnabled {
            guard capabilities.supportsTrueHold, capabilities.canObserveBatteryTemperature.isVerified,
                  let bounds = capabilities.verifiedBatteryTemperatureBoundsCelsius,
                  let pause = maximumBatteryTemperatureCelsius, bounds.contains(pause),
                  let resume = resumeBatteryTemperatureCelsius, bounds.contains(resume) else {
                throw APIError(code: .temperatureUnavailable, details: ["field": "temperatureGuardEnabled"])
            }
        }
    }
    private func invalid(_ field: String) -> APIError { APIError(code: .invalidConfiguration, details: ["field": field]) }
}

public enum OverrideGoal: Codable, Equatable, Sendable {
    case allowCharging(untilPercent: Double)
    case holdCharging
    case discharge(untilPercent: Double)
}
public struct OverrideRequest: Codable, Sendable {
    public var goal: OverrideGoal
    public var expiresAfterSeconds: Double
    public init(goal: OverrideGoal, expiresAfterSeconds: Double = 7_200) { self.goal = goal; self.expiresAfterSeconds = expiresAfterSeconds }
    public func validate(currentPercent: Double, reserveFloorPercent: Double = 20) throws {
        guard expiresAfterSeconds.isFinite, expiresAfterSeconds > 0, expiresAfterSeconds <= 86_400 else {
            throw APIError(code: .invalidConfiguration, details: ["field": "expiresAfterSeconds"])
        }
        guard currentPercent.isFinite, (0...100).contains(currentPercent), reserveFloorPercent.isFinite,
              (20...100).contains(reserveFloorPercent) else { throw APIError(code: .invalidConfiguration, details: ["field": "currentPercent"]) }
        switch goal {
        case .allowCharging(let target):
            guard target.isFinite, (0...100).contains(target) else { throw APIError(code: .invalidConfiguration, details: ["field": "untilPercent"]) }
        case .holdCharging: break
        case .discharge(let target):
            guard target.isFinite, target >= reserveFloorPercent else { throw APIError(code: .unsafeReserve, details: ["field": "untilPercent"]) }
            guard target < currentPercent else { throw APIError(code: .invalidConfiguration, details: ["field": "untilPercent"]) }
        }
    }
}

public struct ActiveOverride: Codable, Sendable {
    public var id: UUID
    public var goal: OverrideGoal
    public var bootID: UUID
    public var startedAtContinuousNanoseconds: UInt64
    public var deadlineContinuousNanoseconds: UInt64
    public var expiresAtUTC: Date
    public init(id: UUID = UUID(), request: OverrideRequest, bootID: UUID, nowContinuousNanoseconds: UInt64, nowUTC: Date) throws {
        guard request.expiresAfterSeconds.isFinite, request.expiresAfterSeconds > 0, request.expiresAfterSeconds <= 86_400 else {
            throw APIError(code: .invalidConfiguration, details: ["field": "expiresAfterSeconds"])
        }
        let duration = UInt64(request.expiresAfterSeconds * 1_000_000_000)
        let deadline = nowContinuousNanoseconds.addingReportingOverflow(duration)
        guard !deadline.overflow else { throw APIError(code: .invalidConfiguration, details: ["field": "expiresAfterSeconds"]) }
        self.id = id; goal = request.goal; self.bootID = bootID; startedAtContinuousNanoseconds = nowContinuousNanoseconds
        deadlineContinuousNanoseconds = deadline.partialValue; expiresAtUTC = nowUTC.addingTimeInterval(request.expiresAfterSeconds)
    }
    public func isExpired(bootID: UUID, nowContinuousNanoseconds: UInt64, nowUTC: Date) -> Bool {
        self.bootID != bootID || nowContinuousNanoseconds < startedAtContinuousNanoseconds ||
        nowContinuousNanoseconds >= deadlineContinuousNanoseconds || nowUTC >= expiresAtUTC
    }
}
