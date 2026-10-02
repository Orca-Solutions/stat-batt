import Foundation
import CoreFoundation
import StatBattDomain

/// DTO validation is a decoding boundary, not peer authentication or capability approval.
public protocol WirePayload: Codable, Sendable {
    static var allowedFields: Set<String> { get }
    static var nestedFields: [String: Set<String>] { get }
    func validate() throws
}

public extension WirePayload {
    static var nestedFields: [String: Set<String>] { WireSchemas.commandObjects }
}

enum WireSchemas {
    static let version: Set<String> = ["major", "minor"]
    static let state: Set<String> = ["generation", "revision"]
    static let context: Set<String> = ["protocolVersion", "commandID", "expected", "controlSessionID"]
    static let admin: Set<String> = ["protocolVersion", "commandID", "externalAuthorizationForm"]
    static let commandObjects: [String: Set<String>] = [
        "$.protocolVersion": version, "$.expected": state,
        "$.context": context, "$.context.protocolVersion": version, "$.context.expected": state,
        "$.authority": ["owner", "admin"], "$.authority.owner": ["_0"], "$.authority.admin": ["_0"],
        "$.authority.owner._0": context, "$.authority.admin._0": admin,
        "$.authority.owner._0.protocolVersion": version, "$.authority.owner._0.expected": state,
        "$.authority.admin._0.protocolVersion": version,
        "$.policy": ["enabled", "resumeAtPercent", "holdAtPercent", "reserveFloorPercent", "backend", "adapterCyclingConsent", "temperatureGuardEnabled", "maximumBatteryTemperatureCelsius", "resumeBatteryTemperatureCelsius"],
        "$.policy.adapterCyclingConsent": ["recordedAtUTC", "disclosureVersion"],
        "$.request": ["goal", "expiresAfterSeconds"], "$.request.goal": ["allowCharging", "holdCharging", "discharge"],
        "$.request.goal.allowCharging": ["untilPercent"], "$.request.goal.holdCharging": [], "$.request.goal.discharge": ["untilPercent"],
        "$.cursor": ["daemonInstanceID", "sequence"], "$.deliveredCursor": ["daemonInstanceID", "sequence"],
        "$.supportedVersions[]": ["major", "minimumMinor", "maximumMinor"]
    ]
}

public struct WireFailure: Error, Equatable, Sendable {
    public let code: ErrorCode
    public let field: String?
    public init(_ code: ErrorCode, field: String? = nil) {
        self.code = code
        self.field = field
    }
}

public enum TransportLimits {
    public static let maximumPayloadBytes = 64 * 1_024
    public static let maximumOutstandingCommands = 32
    public static let maximumSubscriptions = 1
    public static let maximumRetainedEvents = 256
    public static let maximumExportBytes = 1_024 * 1_024
}

/// Bounded versioned JSON. Construct a fresh decoder per call; no shared mutable decoder.
public struct BoundedCodec: Sendable {
    public init() {}

    public func decode<T: WirePayload>(_ type: T.Type, from data: Data) throws -> T {
        guard data.count <= TransportLimits.maximumPayloadBytes else { throw WireFailure(.payloadTooLarge) }
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let fields = object as? [String: Any], Set(fields.keys).isSubset(of: T.allowedFields) else {
                throw WireFailure(.malformedRequest)
            }
            var nodes = 0
            try inspectJSON(object, path: "$", schemas: T.nestedFields, depth: 0, nodes: &nodes)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let text = try container.decode(String.self)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                guard let date = formatter.date(from: text), text.hasSuffix("Z") else {
                    throw WireFailure(.malformedRequest)
                }
                return date
            }
            let value = try decoder.decode(type, from: data)
            try value.validate()
            return value
        } catch let failure as WireFailure {
            throw failure
        } catch {
            throw WireFailure(.malformedRequest)
        }
    }

    public func encode<T: WirePayload>(_ value: T) throws -> Data {
        try value.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            guard date.timeIntervalSinceReferenceDate.isFinite else { throw WireFailure(.malformedRequest) }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        do {
            let data = try encoder.encode(value)
            guard data.count <= TransportLimits.maximumPayloadBytes else { throw WireFailure(.payloadTooLarge) }
            var nodes = 0
            try inspectJSON(JSONSerialization.jsonObject(with: data), path: "$", schemas: T.nestedFields, depth: 0, nodes: &nodes)
            return data
        } catch let failure as WireFailure {
            throw failure
        } catch {
            throw WireFailure(.malformedRequest)
        }
    }

    private func inspectJSON(_ value: Any, path: String, schemas: [String: Set<String>], depth: Int, nodes: inout Int) throws {
        nodes += 1
        guard depth <= 24, nodes <= 8_192 else { throw WireFailure(.malformedRequest) }
        if let object = value as? [String: Any] {
            if let allowed = schemas[path], !Set(object.keys).isSubset(of: allowed) { throw WireFailure(.malformedRequest) }
            for (key, child) in object {
                guard key.utf8.count <= 128 else { throw WireFailure(.malformedRequest) }
                try inspectJSON(child, path: path + "." + key, schemas: schemas, depth: depth + 1, nodes: &nodes)
            }
        } else if let array = value as? [Any] {
            for child in array { try inspectJSON(child, path: path + "[]", schemas: schemas, depth: depth + 1, nodes: &nodes) }
        } else if let string = value as? String {
            guard string.utf8.count <= 4_096 else { throw WireFailure(.malformedRequest) }
        } else if let number = value as? NSNumber {
            guard CFGetTypeID(number) == CFBooleanGetTypeID() || number.doubleValue.isFinite else {
                throw WireFailure(.malformedRequest)
            }
        }
    }
}

func requireFinite(_ value: Double, range: ClosedRange<Double>, field: String) throws {
    guard value.isFinite, range.contains(value) else { throw WireFailure(.invalidConfiguration, field: field) }
}

func requireVersion(_ version: ProtocolVersion) throws {
    guard version.major == 1, version.minor == 0 else { throw WireFailure(.protocolMismatch) }
}
