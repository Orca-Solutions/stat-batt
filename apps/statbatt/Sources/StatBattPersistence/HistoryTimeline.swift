import Foundation

public enum HistoryStateContext: Equatable, Sendable {
    case initialState, summaryOverlapsGap, stateAfterGap, observedChange
}

public struct HistoryTimelineReading: Equatable, Sendable {
    public let timestamp: Date
    public let value: Double
    public let segment: Int
}

public struct HistoryStateObservation: Equatable, Identifiable, Sendable {
    public let timestamp: Date
    public let source: HistoryPowerSource
    public let isCharging: Bool?
    public let context: HistoryStateContext
    public var id: Date { timestamp }
}

/// Minute summaries have interval timestamps, not acquisition timestamps. A gap
/// overlapping [timestamp, timestamp + 60) fences both sides of that summary.
/// Already ordered database input is processed in O(points + gaps); external
/// unordered input is sorted before the same linear scan.
public struct HistoryTimeline: Sendable {
    private struct Bucket: Sendable {
        let point: HistoryPoint
        let segment: Int
        let overlapsGap: Bool
        let fencedBefore: Bool
    }
    private let buckets: [Bucket]

    public init(points: [HistoryPoint], gaps: [HistoryGap]) {
        let validPoints = points.filter { $0.timestamp.timeIntervalSince1970.isFinite }
        let orderedPoints = zip(validPoints, validPoints.dropFirst()).allSatisfy { $0.0.timestamp <= $0.1.timestamp }
            ? validPoints : validPoints.sorted { $0.timestamp < $1.timestamp }
        let validGaps = gaps.filter {
            $0.start.timeIntervalSince1970.isFinite && $0.end.timeIntervalSince1970.isFinite && $0.start < $0.end
        }
        let orderedGaps = zip(validGaps, validGaps.dropFirst()).allSatisfy { $0.0.start <= $0.1.start }
            ? validGaps : validGaps.sorted { $0.start < $1.start }
        var merged: [HistoryGap] = []
        for gap in orderedGaps {
            if let last = merged.last, gap.start <= last.end {
                merged[merged.count - 1].end = max(last.end, gap.end)
            } else { merged.append(gap) }
        }
        var result: [Bucket] = []
        result.reserveCapacity(orderedPoints.count)
        var gapIndex = 0
        var previous: Bucket?
        var segment = 0
        for point in orderedPoints {
            var passedGapSincePrevious = false
            while gapIndex < merged.count && merged[gapIndex].end <= point.timestamp {
                if let previous, merged[gapIndex].end > previous.point.timestamp {
                    passedGapSincePrevious = true
                }
                gapIndex += 1
            }
            let overlaps = gapIndex < merged.count &&
                merged[gapIndex].start < point.timestamp.addingTimeInterval(60) &&
                merged[gapIndex].end > point.timestamp
            let fenced = previous.map {
                overlaps || $0.overlapsGap || passedGapSincePrevious ||
                    point.timestamp.timeIntervalSince($0.point.timestamp) > 90
            } ?? false
            if fenced { segment += 1 }
            let bucket = Bucket(point: point, segment: segment, overlapsGap: overlaps, fencedBefore: fenced)
            result.append(bucket)
            previous = bucket
        }
        buckets = result
    }

    /// Missing measurements also break interpolation, even if other metrics in
    /// the same minute are available. Overlap summaries remain isolated points.
    public func readings(_ measurement: KeyPath<HistoryPoint, Double?>) -> [HistoryTimelineReading] {
        var result: [HistoryTimelineReading] = []
        result.reserveCapacity(buckets.count)
        var previousBucketSegment: Int?
        var measurementMissing = false
        var segment = 0
        for bucket in buckets {
            guard let value = bucket.point[keyPath: measurement], value.isFinite else {
                measurementMissing = true
                continue
            }
            if let previousBucketSegment,
               previousBucketSegment != bucket.segment || measurementMissing { segment += 1 }
            result.append(HistoryTimelineReading(timestamp: bucket.point.timestamp, value: value, segment: segment))
            previousBucketSegment = bucket.segment
            measurementMissing = false
        }
        return result
    }

    public var stateObservations: [HistoryStateObservation] {
        var result: [HistoryStateObservation] = []
        var previous: HistoryPoint?
        for bucket in buckets {
            let point = bucket.point
            let context: HistoryStateContext?
            if bucket.overlapsGap { context = .summaryOverlapsGap }
            else if previous == nil { context = .initialState }
            else if bucket.fencedBefore { context = .stateAfterGap }
            else if previous?.source != point.source || previous?.isCharging != point.isCharging {
                context = .observedChange
            } else { context = nil }
            if let context {
                result.append(HistoryStateObservation(timestamp: point.timestamp, source: point.source,
                    isCharging: point.isCharging, context: context))
            }
            previous = point
        }
        return result
    }
}
