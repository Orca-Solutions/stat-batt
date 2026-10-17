import Foundation
import XCTest
@testable import StatBattPersistence

final class HistoryTimelineTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)
    private func date(_ seconds: Double) -> Date { base.addingTimeInterval(seconds) }
    private func point(_ seconds: Double, percent: Double? = 50,
                       source: HistoryPowerSource = .adapter, charging: Bool? = true) -> HistoryPoint {
        HistoryPoint(timestamp: date(seconds), percentage: percent, isCharging: charging, source: source)
    }
    private func gap(_ start: Double, _ end: Double) -> HistoryGap {
        HistoryGap(start: date(start), end: date(end))
    }

    func testShortSleepInWakeMinuteDoesNotBecomeObservedChangeOrConnectedLine() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StatBattTimeline-\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(url: directory.appendingPathComponent("history.sqlite"))
        try store.record(point(30))
        try store.record(point(61))
        try store.recordGap(gap(65, 70))
        try store.record(point(70, percent: 49, source: .battery, charging: false))
        try store.record(point(130, percent: 48, source: .battery, charging: false))
        let timeline = HistoryTimeline(points: try store.points(now: date(130)), gaps: try store.gaps(now: date(130)))
        XCTAssertEqual(timeline.stateObservations.map(\.timestamp), [date(0), date(60), date(120)])
        XCTAssertEqual(timeline.stateObservations.map(\.context), [.initialState, .summaryOverlapsGap, .stateAfterGap])
        XCTAssertEqual(timeline.stateObservations[1].source, .battery)
        XCTAssertEqual(timeline.readings(\.percentage).map(\.segment), [0, 1, 2],
                       "The mixed wake-minute summary must have no line to either neighbor")
    }

    func testShortSameMinuteSleepLabelsInitialSummaryAsOverlapping() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StatBattTimeline-\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = try HistoryStore(url: directory.appendingPathComponent("history.sqlite"))
        try store.record(point(10))
        try store.recordGap(gap(15, 20))
        try store.record(point(25, source: .battery, charging: false))
        try store.record(point(75, source: .battery, charging: false))
        let timeline = HistoryTimeline(points: try store.points(now: date(75)), gaps: try store.gaps(now: date(75)))
        XCTAssertEqual(timeline.stateObservations.map(\.context), [.summaryOverlapsGap, .stateAfterGap])
        XCTAssertEqual(timeline.readings(\.percentage).map(\.segment), [0, 1])
    }

    func testHalfOpenBucketBoundariesDoNotAssignGapToWrongMinute() {
        let points = [point(0), point(60), point(120)]
        let startsAtBoundary = HistoryTimeline(points: points, gaps: [gap(60, 65)])
        XCTAssertEqual(startsAtBoundary.stateObservations.map(\.context), [.initialState, .summaryOverlapsGap, .stateAfterGap])
        let endsAtBoundary = HistoryTimeline(points: points, gaps: [gap(55, 60)])
        XCTAssertEqual(endsAtBoundary.stateObservations.map(\.context), [.summaryOverlapsGap, .stateAfterGap])
        XCTAssertEqual(endsAtBoundary.readings(\.percentage).map(\.segment), [0, 1, 1])
        let noDuration = HistoryTimeline(points: points, gaps: [gap(60, 60)])
        XCTAssertEqual(noDuration.readings(\.percentage).map(\.segment), [0, 0, 0])
    }

    func testBothSidesOfCrossMinuteGapAreIsolated() {
        let timeline = HistoryTimeline(points: [point(0), point(60), point(120), point(180)],
                                       gaps: [gap(50, 70)])
        XCTAssertEqual(timeline.stateObservations.map(\.context), [.summaryOverlapsGap, .summaryOverlapsGap, .stateAfterGap])
        XCTAssertEqual(timeline.readings(\.percentage).map(\.segment), [0, 1, 2, 2])
        XCTAssertFalse(timeline.stateObservations.contains { $0.context == .observedChange })
    }

    func testMissingOrInvalidMeasurementBreaksOnlyThatMetricChart() {
        var middle = point(60, percent: nil)
        middle.temperatureCelsius = 30
        var first = point(0)
        first.temperatureCelsius = 29
        var last = point(120, percent: 49)
        last.temperatureCelsius = 31
        let timeline = HistoryTimeline(points: [first, middle, last], gaps: [])
        XCTAssertEqual(timeline.readings(\.percentage).map(\.segment), [0, 1])
        XCTAssertEqual(timeline.readings(\.temperatureCelsius).map(\.segment), [0, 0, 0])
        middle.percentage = .nan
        XCTAssertEqual(HistoryTimeline(points: [first, middle, last], gaps: []).readings(\.percentage).map(\.segment), [0, 1])
    }

    func testContinuousStateChangesRemainVisibleButChangesAfterMissingMinuteDoNot() {
        let timeline = HistoryTimeline(points: [point(0), point(60, source: .battery, charging: false),
                                               point(180, source: .adapter, charging: true)], gaps: [])
        XCTAssertEqual(timeline.stateObservations.map(\.context), [.initialState, .observedChange, .stateAfterGap])
        XCTAssertEqual(timeline.readings(\.percentage).map(\.segment), [0, 0, 1])
    }

    func testOverlappingUnorderedGapsDoNotLoseLongGapFence() {
        let timeline = HistoryTimeline(points: [point(180), point(0), point(120), point(60)],
                                       gaps: [gap(65, 70), gap(50, 130), gap(55, 65)])
        XCTAssertEqual(timeline.stateObservations.map(\.context),
                       [.summaryOverlapsGap, .summaryOverlapsGap, .summaryOverlapsGap, .stateAfterGap])
        XCTAssertEqual(timeline.readings(\.percentage).map(\.segment), [0, 1, 2, 3])
    }
}
