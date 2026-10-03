import Foundation
import StatBattDomain

@objc public protocol ThermalControlService {
    func perform(_ request: Data, reply: @escaping (Data?, NSError?) -> Void)
}
@objc public protocol ThermalCombinedService: ThermalStatusService, ThermalControlService {}

public enum ThermalControlAction: String, Codable, Sendable {
    case status, start, heartbeat, stop, prepareNative, finishNative, prepareUninstall, qualifyAdapterOneShot, reconcileNative
}
public enum ThermalControlPhase: String, Codable, Sendable {
    case unavailable, off, watching, paused, restoring, recoveryRequired, qualifying
}
private let thermalPolicyFields: Set<String> = ["enabled", "disconnectAtCelsius", "reconnectAtCelsius", "reservePercent", "maximumPauseSeconds", "cooldownSeconds"]

public struct ThermalControlRequest: WirePayload {
    public static let allowedFields: Set<String> = ["version", "action", "policy"]
    public static var nestedFields: [String: Set<String>] { ["$.policy": thermalPolicyFields] }
    public let version: UInt16
    public let action: ThermalControlAction
    public let policy: ThermalAdapterPolicy?
    public init(action: ThermalControlAction, policy: ThermalAdapterPolicy? = nil) {
        version = 1; self.action = action; self.policy = policy
    }
    public func validate() throws {
        guard version == 1 else { throw WireFailure(.protocolMismatch) }
        guard action == .start ? (policy?.isValid == true && policy?.enabled == true) : policy == nil else {
            throw WireFailure(.malformedRequest)
        }
    }
}

public struct ThermalControlStatus: WirePayload {
    public static let allowedFields: Set<String> = ["version", "phase", "controlAvailable", "qualificationAvailable", "nativeMayProceed", "adapterRestored", "safeToExit", "message", "temperatureCelsius", "estimatedTemperature", "policy", "qualificationResult", "nativeReconciliationRequired"]
    public static var nestedFields: [String: Set<String>] { ["$.policy": thermalPolicyFields] }
    public let version: UInt16
    public let phase: ThermalControlPhase
    public let controlAvailable: Bool
    public let qualificationAvailable: Bool
    public let nativeMayProceed: Bool
    public let adapterRestored: Bool
    public let safeToExit: Bool
    public let message: String
    public let temperatureCelsius: Double?
    public let estimatedTemperature: Bool
    public let policy: ThermalAdapterPolicy?
    public let qualificationResult: String?
    public let nativeReconciliationRequired: Bool?
    public init(phase: ThermalControlPhase, controlAvailable: Bool, qualificationAvailable: Bool = false, nativeMayProceed: Bool = false,
                adapterRestored: Bool = false, safeToExit: Bool = false, message: String, temperatureCelsius: Double? = nil,
                estimatedTemperature: Bool = true, policy: ThermalAdapterPolicy? = nil, qualificationResult: String? = nil, nativeReconciliationRequired: Bool? = nil) {
        version = 1; self.phase = phase; self.controlAvailable = controlAvailable
        self.qualificationAvailable = qualificationAvailable
        self.nativeMayProceed = nativeMayProceed; self.adapterRestored = adapterRestored
        self.safeToExit = safeToExit
        self.message = message; self.temperatureCelsius = temperatureCelsius
        self.estimatedTemperature = estimatedTemperature; self.policy = policy
        self.qualificationResult = qualificationResult
        self.nativeReconciliationRequired = nativeReconciliationRequired
    }
    public func validate() throws {
        guard version == 1 else { throw WireFailure(.protocolMismatch) }
        guard message.utf8.count <= 1024, qualificationResult.map({ $0.utf8.count <= 1024 }) ?? true, policy?.isValid != false,
              temperatureCelsius.map({ $0.isFinite && (-40...120).contains($0) }) ?? true,
              !nativeMayProceed || (!qualificationAvailable && nativeReconciliationRequired != true && (phase == .off || phase == .unavailable)),
              !(phase == .watching || phase == .paused) || controlAvailable else {
            throw WireFailure(.malformedRequest)
        }
    }
}
