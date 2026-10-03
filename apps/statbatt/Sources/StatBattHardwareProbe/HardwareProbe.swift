import Foundation
import CStatBattSMCReadOnly
import StatBattDomain

public enum ProbeKey: String, CaseIterable, Codable, Sendable {
    case chargeEnable = "CHTE", legacyCharge = "CH0C", adapterInhibit = "CHIE", legacyAdapter = "CH0J"
    case legacyChargeAlternate = "CH0B", firmwareUpper = "bfF0", firmwareLower = "bfD0", firmwareEnable = "bfE0"

    public var expectedSize: UInt32? {
        switch self {
        case .chargeEnable: 4
        case .legacyCharge, .adapterInhibit, .legacyAdapter: 1
        default: nil
        }
    }
    public var expectedType: UInt32? {
        switch self {
        case .chargeEnable: 0x75693332 // ui32
        case .legacyCharge, .adapterInhibit: 0x6865785f // hex_
        case .legacyAdapter: 0x75693820 // ui8(space)
        default: nil
        }
    }
}

public enum ProbeFinding: String, Codable, Sendable {
    case accessDenied, transportFailed, malformedResponse, smcRejected, zeroSizePlaceholder
    case unexpectedLayout, metadataOnly, readableCandidate, readFailed
}

/// This report deliberately contains no control capability or supported-operation field.
public struct KeyObservation: Codable, Sendable {
    public let key: ProbeKey
    public let metadataIOReturn: UInt32
    public let metadataResponseLength: UInt32
    public let metadataSMCResult: UInt8
    public let metadataSMCStatus: UInt8
    public let dataSize: UInt32
    public let dataTypeCode: UInt32
    public let dataAttributes: UInt8
    public let readIOReturn: UInt32?
    public let readResponseLength: UInt32?
    public let readSMCResult: UInt8?
    public let readSMCStatus: UInt8?
    public let baselineHex: String?
    public let finding: ProbeFinding

    public init(key: ProbeKey, metadataIOReturn: UInt32 = 0, metadataResponseLength: UInt32 = 80,
                metadataSMCResult: UInt8 = 0, metadataSMCStatus: UInt8 = 0,
                dataSize: UInt32, dataTypeCode: UInt32, dataAttributes: UInt8,
                readIOReturn: UInt32? = nil, readResponseLength: UInt32? = nil,
                readSMCResult: UInt8? = nil, readSMCStatus: UInt8? = nil, value: [UInt8]? = nil) {
        self.key = key; self.metadataIOReturn = metadataIOReturn
        self.metadataResponseLength = metadataResponseLength
        self.metadataSMCResult = metadataSMCResult; self.metadataSMCStatus = metadataSMCStatus
        self.dataSize = dataSize; self.dataTypeCode = dataTypeCode; self.dataAttributes = dataAttributes
        self.readIOReturn = readIOReturn; self.readResponseLength = readResponseLength
        self.readSMCResult = readSMCResult; self.readSMCStatus = readSMCStatus
        var result: ProbeFinding
        if metadataIOReturn == 0xe00002c1 { result = .accessDenied }
        else if metadataIOReturn != 0 { result = .transportFailed }
        else if metadataResponseLength != 80 { result = .malformedResponse }
        else if metadataSMCResult != 0 { result = .smcRejected }
        else if dataSize == 0 { result = .zeroSizePlaceholder }
        else if key.expectedSize == nil { result = .metadataOnly }
        else if dataSize != key.expectedSize || dataTypeCode != key.expectedType || dataAttributes != 0xD4 {
            result = .unexpectedLayout
        } else if readIOReturn == 0xe00002c1 { result = .accessDenied }
        else if readIOReturn == 0, readResponseLength == 80, readSMCResult == 0,
                let value, value.count == Int(dataSize) { result = .readableCandidate }
        else { result = .readFailed }
        finding = result
        // Never emit raw bytes from a denied, malformed, unknown, or metadata-only key.
        baselineHex = result == .readableCandidate ? value?.map { String(format: "%02x", $0) }.joined() : nil
    }
}

public struct ConnectionObservation: Codable, Sendable {
    public let serviceOpenIOReturn: UInt32
    public let clientOpenIOReturn: UInt32
    public let clientCloseIOReturn: UInt32
    public let serviceCloseIOReturn: UInt32
}

public struct HardwareProbeReport: Codable, Sendable {
    public let schemaVersion: Int
    public let generatedAtUTC: Date
    public let platform: PlatformFingerprint
    public let operation: String
    public let targetMatches: Bool
    public let connection: ConnectionObservation?
    public let observations: [KeyObservation]
    public let limitations: [String]

    public static func targetMatches(_ platform: PlatformFingerprint) -> Bool {
        platform.model == "Mac16,13" && platform.architecture == "arm64"
        && platform.operatingSystemVersion == "27.0.1" && platform.operatingSystemBuild == "26A434"
        && platform.firmwareVersion == "mBoot-20457.1.29"
    }

    init(platform: PlatformFingerprint, connection: ConnectionObservation?, observations: [KeyObservation]) {
        schemaVersion = 1; generatedAtUTC = Date(); self.platform = platform
        operation = "fixed-key read-only SMC metadata and conditional baseline read"
        targetMatches = Self.targetMatches(platform); self.connection = connection; self.observations = observations
        limitations = [
            "No SMC key was written; no helper was installed; no shortcut was executed.",
            "Readable metadata and baseline bytes establish neither write permission nor charging behavior, restoration, crash recovery, or thermal protection.",
            "CHIE and CH0J are adapter-inhibit candidates, distinct from charge hold retaining external power.",
            "Permission denial is a stop condition. No entitlement or SIP bypass is attempted.",
            "This diagnostic never enables a charging capability. Unqualified controls remain disabled."
        ]
    }
    public func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

@MainActor
public enum HardwareProbe {
    /// Normal-user only. A mismatched machine tuple returns without opening AppleSMC.
    public static func readOnly(platform: PlatformFingerprint) -> HardwareProbeReport {
        guard HardwareProbeReport.targetMatches(platform) else {
            return HardwareProbeReport(platform: platform, connection: nil, observations: [])
        }
        var rows = [SBReadOnlyKeyObservation](repeating: SBReadOnlyKeyObservation(), count: 8)
        let rawConnection = rows.withUnsafeMutableBufferPointer { buffer in sb_smc_read_only_probe(buffer.baseAddress!) }
        let connection = ConnectionObservation(serviceOpenIOReturn: rawConnection.service_open_return,
            clientOpenIOReturn: rawConnection.client_open_return, clientCloseIOReturn: rawConnection.client_close_return,
            serviceCloseIOReturn: rawConnection.service_close_return)
        let observations = rows.prefix(min(8, Int(rawConnection.observed_count))).enumerated().map { index, row in
            var tuple = row.value
            let value: [UInt8] = withUnsafeBytes(of: &tuple) { bytes in Array(bytes.prefix(min(4, Int(row.value_count)))) }
            return KeyObservation(key: ProbeKey.allCases[index], metadataIOReturn: row.metadata_return,
                metadataResponseLength: row.metadata_length, metadataSMCResult: row.metadata_result,
                metadataSMCStatus: row.metadata_status, dataSize: row.data_size,
                dataTypeCode: row.data_type, dataAttributes: row.attributes,
                readIOReturn: row.read_attempted == 1 ? row.read_return : nil,
                readResponseLength: row.read_attempted == 1 ? row.read_length : nil,
                readSMCResult: row.read_attempted == 1 ? row.read_result : nil,
                readSMCStatus: row.read_attempted == 1 ? row.read_status : nil,
                value: row.read_attempted == 1 ? value : nil)
        }
        return HardwareProbeReport(platform: platform, connection: connection, observations: observations)
    }
}
