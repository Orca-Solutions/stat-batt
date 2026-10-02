import Foundation

public enum MenuDisplay: String, Codable, CaseIterable, Sendable {
    case percentage, temperature, batteryWatts, timeRemaining
}

public enum TemperatureUnit: String, Codable, CaseIterable, Sendable {
    case celsius, fahrenheit
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var menuDisplay: MenuDisplay = .percentage
    public var temperatureUnit: TemperatureUnit = .celsius
    public var launchAtLogin = false
    public var historyEnabled = true
    public var notificationsEnabled = false
    public var notifyChargingTransitions = true
    public var notifyTemperature = true
    public var notifyFailures = true
    public var lowBatteryThresholdPercent = 20.0
    public var highTemperatureThresholdCelsius = 40.0

    public init() {}

    public func validate() throws {
        guard lowBatteryThresholdPercent.isFinite, (0...100).contains(lowBatteryThresholdPercent),
              highTemperatureThresholdCelsius.isFinite, (0...100).contains(highTemperatureThresholdCelsius) else {
            throw PreferencesStoreError.invalidPreferences
        }
    }
}

public enum PreferencesLoadStatus: Equatable, Sendable {
    case defaults, loaded, recoveredCorruption, unsupportedVersion
}

public struct PreferencesLoadResult: Sendable {
    public let preferences: AppPreferences
    public let status: PreferencesLoadStatus
}

public enum PreferencesStoreError: Error, Equatable {
    case invalidPreferences
    case fileTooLarge
}

/// Corruption returns safe defaults and an explicit status; the original file is
/// preserved until the user saves preferences. Filesystem failures are surfaced.
public struct PreferencesStore: Sendable {
    public let url: URL
    private static let maximumBytes = 64 * 1024
    private struct Envelope: Codable {
        var version: Int
        var preferences: AppPreferences
    }

    public init(url: URL) { self.url = url }

    public func load() throws -> PreferencesLoadResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return PreferencesLoadResult(preferences: AppPreferences(), status: .defaults)
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let count = attributes[.size] as? NSNumber, count.intValue > Self.maximumBytes {
            return PreferencesLoadResult(preferences: AppPreferences(), status: .recoveredCorruption)
        }
        let data = try Data(contentsOf: url)
        guard data.count <= Self.maximumBytes else {
            return PreferencesLoadResult(preferences: AppPreferences(), status: .recoveredCorruption)
        }
        do {
            // Inspect the version separately so newer documents need not decode
            // into the current model to report a migration requirement.
            struct Version: Decodable { let version: Int }
            let version = try JSONDecoder().decode(Version.self, from: data).version
            guard version == 1 else {
                return PreferencesLoadResult(preferences: AppPreferences(), status: .unsupportedVersion)
            }
            let envelope = try JSONDecoder().decode(Envelope.self, from: data)
            try envelope.preferences.validate()
            return PreferencesLoadResult(preferences: envelope.preferences, status: .loaded)
        } catch {
            return PreferencesLoadResult(preferences: AppPreferences(), status: .recoveredCorruption)
        }
    }

    public func save(_ preferences: AppPreferences) throws {
        try preferences.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Envelope(version: 1, preferences: preferences))
        guard data.count <= Self.maximumBytes else { throw PreferencesStoreError.fileTooLarge }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
