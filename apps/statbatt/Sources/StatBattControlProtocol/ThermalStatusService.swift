import Foundation
import Security

/// Diagnostic-only bootstrap. Neither endpoint nor status advertises hardware control.
public enum ThermalServiceContract {
    public static let machServiceName = "dev.statbatt.thermal-status"
    public static let appIdentifier = "dev.statbatt.local"
    public static let daemonIdentifier = "dev.statbatt.control-daemon"
    public static let daemonPlistName = "dev.statbatt.control-daemon.plist"
    public static let maximumStatusRequestBytes = 256
}

@objc public protocol ThermalStatusService {
    func getStatus(_ request: Data, reply: @escaping (Data?, NSError?) -> Void)
}

public struct ThermalStatusRequest: WirePayload {
    public static let allowedFields: Set<String> = ["version"]
    public static let nestedFields: [String: Set<String>] = [:]
    public let version: UInt16
    public init(version: UInt16 = 1) { self.version = version }
    public func validate() throws {
        guard version == 1 else { throw WireFailure(.protocolMismatch) }
    }
}

public struct ThermalStatusResponse: WirePayload {
    public static let allowedFields: Set<String> = ["version", "actuationDisabled"]
    public static let nestedFields: [String: Set<String>] = [:]
    public let version: UInt16
    public let actuationDisabled: Bool
    public init() { version = 1; actuationDisabled = true }
    public func validate() throws {
        guard version == 1, actuationDisabled else { throw WireFailure(.protocolMismatch) }
    }
}

public enum ThermalStatusEndpoint {
    /// Runs only after connection authentication; repeats a small payload bound before parsing.
    public static func response(to request: Data) throws -> Data {
        guard request.count <= ThermalServiceContract.maximumStatusRequestBytes else {
            throw WireFailure(.payloadTooLarge)
        }
        _ = try BoundedCodec().decode(ThermalStatusRequest.self, from: request)
        return try BoundedCodec().encode(ThermalStatusResponse())
    }
}

public enum ThermalSigningError: Error { case missingIdentity, invalidIdentity, invalidRequirement, untrustedCode }

public enum ThermalServiceSigning {
    /// Reject metacharacters rather than trying to escape arbitrary requirement-language input.
    public static func requirement(teamIdentifier: String?, identifier: String?) throws -> String {
        guard let team = teamIdentifier, let identifier, !team.isEmpty, !identifier.isEmpty else {
            throw ThermalSigningError.missingIdentity
        }
        let teamAllowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".utf8)
        let idAllowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-_".utf8)
        guard team.utf8.count == 10, team.utf8.allSatisfy(teamAllowed.contains),
              identifier.utf8.count <= 128, identifier.utf8.allSatisfy(idAllowed.contains) else {
            throw ThermalSigningError.invalidIdentity
        }
        return "anchor apple generic and certificate leaf[subject.OU] = \"\(team)\" and identifier \"\(identifier)\""
    }

    /// Cryptographic identity discovery. Signing metadata alone is never accepted as proof.
    /// Caller supplies fixed product identifiers, never XPC payload fields or environment values.
    public static func peerRequirement(ownIdentifier: String, peerIdentifier: String) throws -> String {
        var ownCode: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &ownCode) == errSecSuccess, let ownCode else {
            throw ThermalSigningError.missingIdentity
        }
        let apple = try compiledRequirement("anchor apple generic")
        guard SecCodeCheckValidity(ownCode, SecCSFlags(), apple) == errSecSuccess else {
            throw ThermalSigningError.untrustedCode
        }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(ownCode, SecCSFlags(), &staticCode) == errSecSuccess, let staticCode else {
            throw ThermalSigningError.missingIdentity
        }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let fields = information as? [String: Any],
              let team = fields[kSecCodeInfoTeamIdentifier as String] as? String,
              let identifier = fields[kSecCodeInfoIdentifier as String] as? String,
              identifier == ownIdentifier else { throw ThermalSigningError.missingIdentity }
        let ownRequirement = try requirement(teamIdentifier: team, identifier: ownIdentifier)
        guard SecCodeCheckValidity(ownCode, SecCSFlags(), try compiledRequirement(ownRequirement)) == errSecSuccess else {
            throw ThermalSigningError.untrustedCode
        }
        let peer = try requirement(teamIdentifier: team, identifier: peerIdentifier)
        _ = try compiledRequirement(peer) // Never pass malformed strings to throwing ObjC APIs.
        return peer
    }

    private static func compiledRequirement(_ text: String) throws -> SecRequirement {
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, SecCSFlags(), &requirement) == errSecSuccess,
              let requirement else { throw ThermalSigningError.invalidRequirement }
        return requirement
    }
}
