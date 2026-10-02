import Foundation
import XCTest
@testable import StatBattPersistence

final class PersistenceTests: XCTestCase {
    private let instant = Date(timeIntervalSince1970: 1_800_000_030)

    private func temporaryURL(_ name: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StatBattTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent(name)
    }

    func testMinuteAveragesPreserveMissingValuesAndLatestState() throws {
        let store = try HistoryStore(url: temporaryURL("history.sqlite"))
        try store.record(HistoryPoint(timestamp: instant, percentage: 50, batteryWatts: -10, isCharging: false, source: .battery))
        try store.record(HistoryPoint(timestamp: instant.addingTimeInterval(10), percentage: 70, temperatureCelsius: 30, isCharging: true, source: .adapter))
        // An older event may contribute measurements but must not reverse latest state.
        try store.record(HistoryPoint(timestamp: instant.addingTimeInterval(5), percentage: nil, batteryWatts: 0, isCharging: false, source: .battery), now: instant.addingTimeInterval(10))
        let points = try store.points(now: instant.addingTimeInterval(10))
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points.first?.percentage, 60)
        XCTAssertEqual(points.first?.temperatureCelsius, 30)
        XCTAssertEqual(points.first?.batteryWatts, -5)
        XCTAssertEqual(points.first?.isCharging, true)
        XCTAssertEqual(points.first?.source, .adapter)
    }

    func testDisabledRecordingAndClearIncludeGaps() throws {
        let store = try HistoryStore(url: temporaryURL("history.sqlite"), recordingEnabled: false)
        let gap = HistoryGap(start: instant.addingTimeInterval(-300), end: instant)
        try store.record(HistoryPoint(timestamp: instant, percentage: 55))
        try store.recordGap(gap)
        XCTAssertTrue(try store.points(now: instant).isEmpty)
        XCTAssertTrue(try store.gaps(now: instant).isEmpty)
        store.recordingEnabled = true
        try store.record(HistoryPoint(timestamp: instant, percentage: nil))
        try store.recordGap(gap)
        XCTAssertEqual(try store.gaps(now: instant), [gap])
        store.recordingEnabled = false
        XCTAssertEqual(try store.points(now: instant).count, 1, "Disabling preserves prior history until explicit clear")
        try store.clear()
        XCTAssertTrue(try store.points(now: instant).isEmpty)
        XCTAssertTrue(try store.gaps(now: instant).isEmpty)
    }

    func testRetentionDropsOldRecordsAndBoundsOneMinuteRows() throws {
        let store = try HistoryStore(url: temporaryURL("history.sqlite"))
        let old = instant.addingTimeInterval(-HistoryStore.retention - 60)
        try store.record(HistoryPoint(timestamp: old, percentage: 11))
        try store.recordGap(HistoryGap(start: old.addingTimeInterval(-60), end: old))
        try store.record(HistoryPoint(timestamp: instant, percentage: 80))
        XCTAssertEqual(try store.points(now: instant).map(\.percentage), [80])
        XCTAssertTrue(try store.gaps(now: instant).isEmpty)
        // More than one observation per minute does not grow the row count.
        for offset in 0..<180 {
            let date = instant.addingTimeInterval(Double(offset))
            try store.record(HistoryPoint(timestamp: date, percentage: 80))
        }
        XCTAssertEqual(try store.points(now: instant.addingTimeInterval(179)).count, 4)
        XCTAssertTrue(try store.points(now: instant.addingTimeInterval(HistoryStore.retention + 180)).isEmpty)
    }

    func testReopeningDatabaseAndUTCUnitExportDoNotExposePaths() throws {
        let url = try temporaryURL("private-owner-history.sqlite")
        do {
            let store = try HistoryStore(url: url)
            try store.record(HistoryPoint(timestamp: instant, percentage: 80, batteryWatts: -2.5, source: .battery))
            try store.recordGap(HistoryGap(start: instant.addingTimeInterval(-60), end: instant))
        }
        let reopened = try HistoryStore(url: url)
        XCTAssertEqual(try reopened.points(now: instant).count, 1)
        let csv = try reopened.exportCSV(now: instant)
        XCTAssertTrue(csv.hasPrefix("kind,timestamp_utc,gap_end_utc,percentage_percent,temperature_celsius,net_battery_watts"))
        XCTAssertTrue(csv.contains("Z,"))
        XCTAssertTrue(csv.contains(",80.0,,-2.5,,battery,"))
        XCTAssertTrue(csv.contains(",sleep\n"))
        XCTAssertFalse(csv.contains(url.path))
        XCTAssertFalse(csv.contains("private-owner"))
        XCTAssertEqual(csv.split(separator: "\n").count, 3)
        XCTAssertTrue(csv.split(separator: "\n").allSatisfy { $0.split(separator: ",", omittingEmptySubsequences: false).count == 9 })
    }

    func testInvalidMeasurementsAndDatesCannotPoisonHistory() throws {
        let store = try HistoryStore(url: temporaryURL("history.sqlite"))
        for percent in [-1.0, 101, .nan, .infinity] {
            XCTAssertThrowsError(try store.record(HistoryPoint(timestamp: instant, percentage: percent)))
        }
        XCTAssertThrowsError(try store.record(HistoryPoint(timestamp: Date(timeIntervalSince1970: .infinity), percentage: 50)))
        XCTAssertThrowsError(try store.record(HistoryPoint(timestamp: instant, percentage: 50, temperatureCelsius: .greatestFiniteMagnitude)))
        XCTAssertThrowsError(try store.record(HistoryPoint(timestamp: instant, percentage: 50, batteryWatts: .greatestFiniteMagnitude)))
        XCTAssertThrowsError(try store.recordGap(HistoryGap(start: instant, end: instant.addingTimeInterval(-1))))
        try store.record(HistoryPoint(timestamp: instant.addingTimeInterval(60), percentage: 50), now: instant)
        XCTAssertTrue(try store.points(now: instant).isEmpty)
    }

    func testRetentionBoundaryAndGapOverlapAreExplicit() throws {
        let store = try HistoryStore(url: temporaryURL("history.sqlite"))
        let firstMinute = Date(timeIntervalSince1970: floor(instant.timeIntervalSince1970 / 60) * 60 - HistoryStore.retention + 60)
        try store.record(HistoryPoint(timestamp: firstMinute.addingTimeInterval(-60), percentage: 10), now: instant)
        try store.record(HistoryPoint(timestamp: firstMinute, percentage: 20), now: instant)
        XCTAssertEqual(try store.points(now: instant).map(\.percentage), [20])
        let start = instant.addingTimeInterval(-HistoryStore.retention - 300)
        try store.recordGap(HistoryGap(start: start, end: instant.addingTimeInterval(-60)), now: instant)
        XCTAssertEqual(try store.gaps(now: instant).first?.start, instant.addingTimeInterval(-HistoryStore.retention))
        let later = instant.addingTimeInterval(120)
        XCTAssertEqual(try store.gaps(now: later).first?.start, later.addingTimeInterval(-HistoryStore.retention))
    }

    func testFullSevenDayWindowHasHardRowBound() throws {
        let store = try HistoryStore(url: temporaryURL("history.sqlite"))
        for offset in 0..<(HistoryStore.maximumPoints + 2) {
            try store.record(HistoryPoint(timestamp: instant.addingTimeInterval(Double(offset * 60)), percentage: 50))
        }
        let final = instant.addingTimeInterval(Double((HistoryStore.maximumPoints + 1) * 60))
        let points = try store.points(now: final)
        XCTAssertEqual(points.count, HistoryStore.maximumPoints)
        XCTAssertGreaterThan(points[0].timestamp, final.addingTimeInterval(-HistoryStore.retention))
        XCTAssertEqual(points.last?.percentage, 50)
    }

    func testCorruptDatabaseDoesNotPretendToBeEmptyHistory() throws {
        let url = try temporaryURL("history.sqlite")
        try Data("broken database".utf8).write(to: url)
        XCTAssertThrowsError(try HistoryStore(url: url))
        XCTAssertEqual(try Data(contentsOf: url), Data("broken database".utf8))
    }

    func testPreferencesRoundTripAndInvalidSavePreservesPriorVersion() throws {
        let store = PreferencesStore(url: try temporaryURL("preferences.json"))
        XCTAssertEqual(try store.load().status, .defaults)
        var preferences = AppPreferences()
        preferences.temperatureUnit = .fahrenheit
        preferences.historyEnabled = false
        preferences.notificationsEnabled = true
        try store.save(preferences)
        XCTAssertEqual(try store.load().preferences, preferences)
        XCTAssertEqual(try store.load().status, .loaded)
        var invalid = preferences
        invalid.lowBatteryThresholdPercent = 101
        XCTAssertThrowsError(try store.save(invalid))
        XCTAssertEqual(try store.load().preferences, preferences)
        let attributes = try FileManager.default.attributesOfItem(atPath: store.url.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testCorruptAndFuturePreferencesRecoverWithoutOverwritingEvidence() throws {
        let store = PreferencesStore(url: try temporaryURL("preferences.json"))
        let corrupt = Data("{broken".utf8)
        try corrupt.write(to: store.url)
        let result = try store.load()
        XCTAssertEqual(result.status, .recoveredCorruption)
        XCTAssertEqual(result.preferences, AppPreferences())
        XCTAssertEqual(try Data(contentsOf: store.url), corrupt)
        let future = Data("{\"version\":999,\"preferences\":{}}".utf8)
        try future.write(to: store.url)
        XCTAssertEqual(try store.load().status, .unsupportedVersion)
        XCTAssertEqual(try Data(contentsOf: store.url), future)
        try Data(repeating: 65, count: 70_000).write(to: store.url)
        XCTAssertEqual(try store.load().status, .recoveredCorruption)
    }
}
