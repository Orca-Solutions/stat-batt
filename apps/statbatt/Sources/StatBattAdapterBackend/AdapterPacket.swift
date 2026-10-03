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
    public var failure: AdapterFailure?
    public var baselineKey: UInt8?
    public var transport: UInt32?
    public var smcResult: UInt8?
    public var smcStatus: UInt8?
    public var recoveryCause: AdapterRecoveryCause?
    public var holdSeconds: UInt16?
    public init(phase: String) { self.phase = phase }
}

public enum AdapterRecoveryCause: String, Codable, Sendable { case ownerEOF, sleep, deadline, hardwareFailure }

public enum AdapterFailure: String, Codable, Sendable {
    case identityOrGate, signature, platform, ownershipLock, ownershipJournal, inputChannel, ownerToken
    case sleepNotification, sleepAssertion, workerLaunch, writerUnreaped
    case batteryMissingOrStale, externalPowerMissingOrStale, reserveMissingOrStale, thermalNotNominalOrStale
    case backendBusy, missingIntent, dispatchFailed, deadline, hardware
    case powerSourceUnavailableOrUnexpected, temperatureMissingInvalidOrStale
}

public struct AdapterDiagnostic: Codable, Sendable {
    public let event: String
    public let at: UInt64
    public let phase: String?
    public let failure: AdapterFailure?
    public let key: UInt8?
    public let baselineKey: UInt8?
    public let outcome: UInt8?
    public let transport: UInt32?
    public let smcResult: UInt8?
    public let smcStatus: UInt8?
    public let adapter: Bool?
    public let battery: Bool?
    public let exitCode: Int32?
    public let recoveryCause: AdapterRecoveryCause?
    public let holdSeconds: UInt16?
    public init(event: String, at: UInt64, packet: AdapterPacket? = nil, failure: AdapterFailure? = nil, exitCode: Int32? = nil) {
        let events: Set<String> = ["admission", "launch", "dispatch", "packet", "exit", "timeout", "failed", "restoreLaunch"]
        let phases: Set<String> = ["inhibited", "restored", "inspection", "writerReady", "workerRestoring", "writerReaped", "writerUnreapedUnknown", "rejected"]
        self.event = events.contains(event) ? event : "failed"; self.at = at
        phase = packet.flatMap { phases.contains($0.phase) ? $0.phase : "rejected" }
        self.failure = failure ?? packet?.failure
        key = packet?.key; baselineKey = packet?.baselineKey; outcome = packet?.outcome
        transport = packet?.transport; smcResult = packet?.smcResult; smcStatus = packet?.smcStatus
        adapter = packet?.adapter; battery = packet?.battery; self.exitCode = exitCode
        recoveryCause = packet?.recoveryCause
        holdSeconds = packet?.holdSeconds
    }
}

public struct AdapterDiagnosticHistory: Sendable {
    public private(set) var entries: [AdapterDiagnostic] = []
    public init() {}
    public mutating func append(_ entry: AdapterDiagnostic) {
        if entries.count == 64 { entries.removeFirst() }
        entries.append(entry)
    }
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
