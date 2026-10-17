import Foundation

/// In-memory consent only. Heartbeats cannot extend the absolute session limit,
/// change owners, revive an expired lease, or survive a process restart.
public struct ThermalSessionLease: Sendable {
    public let owner: UUID
    public let uid: UInt32
    public let startedAt: UInt64
    public let deadline: UInt64
    public private(set) var lastHeartbeat: UInt64
    public static let heartbeatLimit: UInt64 = 15_000_000_000
    public init?(owner: UUID, uid: UInt32, now: UInt64, duration: UInt64 = 3_600_000_000_000) {
        guard uid != 0, duration > 0, duration <= 3_600_000_000_000,
              now <= UInt64.max - duration else { return nil }
        self.owner = owner; self.uid = uid; startedAt = now
        deadline = now + duration; lastHeartbeat = now
    }
    public func isValid(now: UInt64, activeUID: UInt32?) -> Bool {
        activeUID == uid && now >= lastHeartbeat && now < deadline &&
        now - lastHeartbeat < Self.heartbeatLimit
    }
    @discardableResult public mutating func heartbeat(owner: UUID, now: UInt64, activeUID: UInt32?) -> Bool {
        guard owner == self.owner, isValid(now: now, activeUID: activeUID) else { return false }
        lastHeartbeat = now
        return true
    }
}
