import Foundation
import Security
import Darwin
import StatBattControlProtocol

/// Internal process protocol, never accepted from XPC. No key/value/path fields.
public struct AdapterPacket: Codable, Sendable {
    public var phase: String
    public var key: UInt8?
    public var outcome: UInt8?
    public var sampledAt: UInt64?
    public var sourceAt: UInt64?
    public var adapter: Bool?
    public var battery: Bool?
    public var reaped: Bool?
    public var temperatureCelsius: Double?
    public var temperatureEstimated: Bool?
    public var stateOfCharge: Double?
    public init(phase: String) { self.phase = phase }
}

public enum AdapterExecutableIdentity {
    public static let identifier = "dev.statbatt.adapter-guardian"
    public static func verify(url: URL, ownIdentifier: String) throws {
        // Signed, immutable root-owned installation is mandatory for actuation.
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0, metadata.st_uid == 0,
              metadata.st_mode & S_IFMT == S_IFREG, metadata.st_mode & 0o022 == 0 else {
            throw ThermalSigningError.untrustedCode
        }
        var ancestor = url.deletingLastPathComponent()
        while true {
            var info = stat()
            guard lstat(ancestor.path, &info) == 0, info.st_uid == 0, info.st_mode & S_IFMT == S_IFDIR,
                  info.st_mode & 0o022 == 0 else { throw ThermalSigningError.untrustedCode }
            if ancestor.path == "/" { break }
            ancestor.deleteLastPathComponent()
        }
        let requirementText = try ThermalServiceSigning.peerRequirement(ownIdentifier: ownIdentifier, peerIdentifier: identifier)
        var requirement: SecRequirement?
        var code: SecStaticCode?
        guard SecRequirementCreateWithString(requirementText as CFString, SecCSFlags(), &requirement) == errSecSuccess,
              SecStaticCodeCreateWithPath(url as CFURL, SecCSFlags(), &code) == errSecSuccess,
              let code, let requirement,
              SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), requirement) == errSecSuccess else {
            throw ThermalSigningError.untrustedCode
        }
    }
}
