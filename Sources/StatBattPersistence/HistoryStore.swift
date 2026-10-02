import CSQLite
import Foundation

public enum HistoryPowerSource: String, Codable, Sendable {
    case battery, adapter, unknown
}

/// A numeric, nonidentifying observation. Missing measurements remain missing.
public struct HistoryPoint: Equatable, Sendable {
    public var timestamp: Date
    public var percentage: Double?
    public var temperatureCelsius: Double?
    public var batteryWatts: Double?
    public var isCharging: Bool?
    public var source: HistoryPowerSource

    public init(timestamp: Date, percentage: Double?, temperatureCelsius: Double? = nil,
                batteryWatts: Double? = nil, isCharging: Bool? = nil,
                source: HistoryPowerSource = .unknown) {
        self.timestamp = timestamp
        self.percentage = percentage
        self.temperatureCelsius = temperatureCelsius
        self.batteryWatts = batteryWatts
        self.isCharging = isCharging
        self.source = source
    }
}

public enum HistoryGapReason: String, Codable, Sendable {
    case sleep, samplingInterrupted, recordingDisabled
}

public struct HistoryGap: Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var reason: HistoryGapReason

    public init(start: Date, end: Date, reason: HistoryGapReason = .sleep) {
        self.start = start
        self.end = end
        self.reason = reason
    }
}

public enum HistoryStoreError: Error, Equatable {
    case databaseFailure
    case unsupportedSchema
    case invalidMeasurement
    case invalidDate
}

/// The caller serializes access (the application uses its MainActor store).
/// Only normalized measurements enter this database; no identifiers or raw telemetry do.
public final class HistoryStore {
    public static let retention: TimeInterval = 7 * 24 * 60 * 60
    public static let maximumPoints = 7 * 24 * 60
    public var recordingEnabled: Bool
    private var database: OpaquePointer?

    public init(url: URL, recordingEnabled: Bool = true) throws {
        self.recordingEnabled = recordingEnabled
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }
            database = nil
            throw HistoryStoreError.databaseFailure
        }
        do {
            try execute("PRAGMA busy_timeout = 1000")
            let version = try scalarInteger("PRAGMA user_version")
            guard (0...1).contains(version) else { throw HistoryStoreError.unsupportedSchema }
            try execute("""
                CREATE TABLE IF NOT EXISTS minutes (
                    minute INTEGER PRIMARY KEY,
                    percent_sum REAL NOT NULL, percent_count INTEGER NOT NULL,
                    temperature_sum REAL NOT NULL, temperature_count INTEGER NOT NULL,
                    watts_sum REAL NOT NULL, watts_count INTEGER NOT NULL,
                    last_sample REAL NOT NULL, charging INTEGER, source TEXT NOT NULL
                );
                CREATE TABLE IF NOT EXISTS gaps (
                    start REAL NOT NULL, end REAL NOT NULL, reason TEXT NOT NULL,
                    PRIMARY KEY(start, end, reason)
                );
                PRAGMA user_version = 1;
                """)
        } catch {
            sqlite3_close(database)
            database = nil
            throw error
        }
    }

    deinit { sqlite3_close(database) }

    public func record(_ point: HistoryPoint, now: Date? = nil) throws {
        guard recordingEnabled else { return }
        let current = now ?? point.timestamp
        try validateDate(current)
        try validateDate(point.timestamp)
        guard point.percentage.map({ $0.isFinite && (0...100).contains($0) }) ?? true,
              point.temperatureCelsius.map({ $0.isFinite && (-273.15...1000).contains($0) }) ?? true,
              point.batteryWatts.map({ $0.isFinite && abs($0) <= 1_000_000 }) ?? true else {
            throw HistoryStoreError.invalidMeasurement
        }
        guard point.timestamp <= current,
              minute(point.timestamp) >= oldestMinute(current) else { return }
        try transaction {
            let statement = try prepare("""
                INSERT INTO minutes VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(minute) DO UPDATE SET
                    percent_sum = percent_sum + excluded.percent_sum,
                    percent_count = percent_count + excluded.percent_count,
                    temperature_sum = temperature_sum + excluded.temperature_sum,
                    temperature_count = temperature_count + excluded.temperature_count,
                    watts_sum = watts_sum + excluded.watts_sum,
                    watts_count = watts_count + excluded.watts_count,
                    charging = CASE WHEN excluded.last_sample >= last_sample THEN excluded.charging ELSE charging END,
                    source = CASE WHEN excluded.last_sample >= last_sample THEN excluded.source ELSE source END,
                    last_sample = MAX(last_sample, excluded.last_sample)
                """)
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, minute(point.timestamp))
            bindMeasurement(point.percentage, statement, 2)
            bindMeasurement(point.temperatureCelsius, statement, 4)
            bindMeasurement(point.batteryWatts, statement, 6)
            sqlite3_bind_double(statement, 8, point.timestamp.timeIntervalSince1970)
            if let charging = point.isCharging { sqlite3_bind_int(statement, 9, charging ? 1 : 0) }
            else { sqlite3_bind_null(statement, 9) }
            bindText(point.source.rawValue, statement, 10)
            try stepDone(statement)
            try prune(now: current)
        }
    }

    public func recordGap(_ gap: HistoryGap, now: Date? = nil) throws {
        guard recordingEnabled else { return }
        let current = now ?? gap.end
        try validateDate(current)
        try validateDate(gap.start)
        try validateDate(gap.end)
        guard gap.start <= gap.end, gap.end <= current else { throw HistoryStoreError.invalidDate }
        guard gap.end >= current.addingTimeInterval(-Self.retention) else { return }
        try transaction {
            let statement = try prepare("INSERT OR IGNORE INTO gaps VALUES (?, ?, ?)")
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_double(statement, 1, max(gap.start.timeIntervalSince1970, current.timeIntervalSince1970 - Self.retention))
            sqlite3_bind_double(statement, 2, gap.end.timeIntervalSince1970)
            bindText(gap.reason.rawValue, statement, 3)
            try stepDone(statement)
            try prune(now: current)
        }
    }

    public func points(now: Date = Date()) throws -> [HistoryPoint] {
        try validateDate(now)
        try prune(now: now)
        let statement = try prepare("SELECT minute, percent_sum, percent_count, temperature_sum, temperature_count, watts_sum, watts_count, charging, source FROM minutes WHERE minute <= ? ORDER BY minute")
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, minute(now))
        var points: [HistoryPoint] = []
        while try stepRow(statement) {
            let charging = sqlite3_column_type(statement, 7) == SQLITE_NULL ? nil : sqlite3_column_int(statement, 7) != 0
            points.append(HistoryPoint(timestamp: Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 0))),
                percentage: mean(statement, 1), temperatureCelsius: mean(statement, 3),
                batteryWatts: mean(statement, 5), isCharging: charging,
                source: HistoryPowerSource(rawValue: text(statement, 8)) ?? .unknown))
        }
        return points
    }

    public func gaps(now: Date = Date()) throws -> [HistoryGap] {
        try validateDate(now)
        try prune(now: now)
        let statement = try prepare("SELECT start, end, reason FROM gaps WHERE end <= ? ORDER BY start")
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_double(statement, 1, now.timeIntervalSince1970)
        var gaps: [HistoryGap] = []
        while try stepRow(statement) {
            gaps.append(HistoryGap(start: Date(timeIntervalSince1970: max(sqlite3_column_double(statement, 0), now.timeIntervalSince1970 - Self.retention)),
                end: Date(timeIntervalSince1970: sqlite3_column_double(statement, 1)),
                reason: HistoryGapReason(rawValue: text(statement, 2)) ?? .samplingInterrupted))
        }
        return gaps
    }

    public func clear() throws {
        try transaction { try execute("DELETE FROM minutes; DELETE FROM gaps;") }
        // Reclaim old pages rather than retaining deleted history in the freelist.
        try execute("VACUUM")
    }

    /// Explicit UTC/unit columns; empty cells preserve unavailable measurements.
    public func exportCSV(now: Date = Date()) throws -> String {
        let points = try points(now: now)
        let gaps = try gaps(now: now)
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        var rows: [(Date, String)] = points.map { point in
            let row = ["sample", formatter.string(from: point.timestamp), "", number(point.percentage),
                       number(point.temperatureCelsius), number(point.batteryWatts),
                       point.isCharging.map { $0 ? "true" : "false" } ?? "", point.source.rawValue, ""].joined(separator: ",")
            return (point.timestamp, row)
        }
        rows += gaps.map { ($0.start, ["gap", formatter.string(from: $0.start), formatter.string(from: $0.end),
                                      "", "", "", "", "", $0.reason.rawValue].joined(separator: ",")) }
        return "kind,timestamp_utc,gap_end_utc,percentage_percent,temperature_celsius,net_battery_watts,is_charging,power_source,gap_reason\n" +
            rows.sorted { $0.0 < $1.0 }.map(\.1).joined(separator: "\n") + (rows.isEmpty ? "" : "\n")
    }

    private func prune(now: Date) throws {
        let statement = try prepare("DELETE FROM minutes WHERE minute < ?")
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, oldestMinute(now))
        try stepDone(statement)
        let gapStatement = try prepare("DELETE FROM gaps WHERE end < ?")
        defer { sqlite3_finalize(gapStatement) }
        sqlite3_bind_double(gapStatement, 1, now.timeIntervalSince1970 - Self.retention)
        try stepDone(gapStatement)
        if try scalarInteger("SELECT COUNT(*) FROM minutes") > Self.maximumPoints {
            try execute("DELETE FROM minutes WHERE minute NOT IN (SELECT minute FROM minutes ORDER BY minute DESC LIMIT 10080)")
        }
        if try scalarInteger("SELECT COUNT(*) FROM gaps") > Self.maximumPoints {
            try execute("DELETE FROM gaps WHERE rowid NOT IN (SELECT rowid FROM gaps ORDER BY end DESC LIMIT 10080)")
        }
    }

    private func minute(_ date: Date) -> Int64 { Int64(floor(date.timeIntervalSince1970 / 60)) * 60 }
    private func oldestMinute(_ now: Date) -> Int64 { minute(now) - Int64(Self.retention) + 60 }
    private func validateDate(_ date: Date) throws {
        // A deliberately broad finite range avoids Int64 conversion traps on hostile input.
        guard date.timeIntervalSince1970.isFinite, abs(date.timeIntervalSince1970) < 1e12 else { throw HistoryStoreError.invalidDate }
    }
    private func number(_ value: Double?) -> String { value.map { String($0) } ?? "" }
    private func mean(_ statement: OpaquePointer, _ index: Int32) -> Double? {
        let count = sqlite3_column_int64(statement, index + 1)
        return count == 0 ? nil : sqlite3_column_double(statement, index) / Double(count)
    }
    private func text(_ statement: OpaquePointer, _ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }
    private func bindMeasurement(_ value: Double?, _ statement: OpaquePointer, _ index: Int32) {
        sqlite3_bind_double(statement, index, value ?? 0)
        sqlite3_bind_int(statement, index + 1, value == nil ? 0 : 1)
    }
    private func bindText(_ value: String, _ statement: OpaquePointer, _ index: Int32) {
        _ = value.withCString { sqlite3_bind_text(statement, index, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
    }
    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw HistoryStoreError.databaseFailure }
        return statement
    }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw HistoryStoreError.databaseFailure }
    }
    private func scalarInteger(_ sql: String) throws -> Int32 {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard try stepRow(statement) else { throw HistoryStoreError.databaseFailure }
        return sqlite3_column_int(statement, 0)
    }
    private func stepDone(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else { throw HistoryStoreError.databaseFailure }
    }
    private func stepRow(_ statement: OpaquePointer) throws -> Bool {
        switch sqlite3_step(statement) {
        case SQLITE_ROW: return true
        case SQLITE_DONE: return false
        default: throw HistoryStoreError.databaseFailure
        }
    }
    private func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE")
        do { try body(); try execute("COMMIT") }
        catch { try? execute("ROLLBACK"); throw error }
    }
}
