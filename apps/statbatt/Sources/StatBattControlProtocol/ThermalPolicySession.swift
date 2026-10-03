import Foundation
import StatBattDomain

/// Owns the ephemeral policy and UI lease. Call tick with freshly acquired trusted
/// inputs; this type neither manufactures capabilities nor reads client telemetry.
public actor ThermalPolicySession {
    private let controller: ThermalControlOrchestrator
    private let activeUID: @Sendable () -> UInt32?
    private var pendingLease: ThermalSessionLease?
    private let clock: @Sendable () -> UInt64
    private var lease: ThermalSessionLease?
    private var policy: ThermalAdapterPolicy?
    private var generation: UInt64 = 0
    private var starting = false
    public init(controller: ThermalControlOrchestrator, clock: @escaping @Sendable () -> UInt64, activeUID: @escaping @Sendable () -> UInt32?) {
        self.controller = controller; self.clock = clock; self.activeUID = activeUID
    }
    public var owner: UUID? { lease?.owner }
    public var activePolicy: ThermalAdapterPolicy? { policy }
    public func start(owner: UUID, uid: UInt32, policy: ThermalAdapterPolicy) async -> Bool {
        guard lease == nil, !starting, activeUID() == uid, policy.enabled, policy.isValid,
              let next = ThermalSessionLease(owner: owner, uid: uid, now: clock()) else { return false }
        starting = true; pendingLease = next
        defer { starting = false; pendingLease = nil }
        let expected = generation
        let authorized = await controller.authorize(sessionID: owner, deadline: next.deadline)
        guard expected == generation, authorized else { return false }
        guard next.isValid(now: clock(), activeUID: activeUID()) else {
            _ = await stop(); return false
        }
        lease = next; self.policy = policy
        return true
    }
    public func heartbeat(owner: UUID, activeUID: UInt32?) -> Bool {
        guard var next = lease, next.heartbeat(owner: owner, now: clock(), activeUID: activeUID) else { return false }
        lease = next; return true
    }
    public func tick(_ sample: ThermalAdapterInput, activeUID: UInt32?) async -> ThermalControlResult {
        guard let lease, let policy else { return .idle }
        guard lease.isValid(now: clock(), activeUID: activeUID) else { return await stop() }
        let expected = generation
        var input = sample
        input.policy = policy // Saved consent, never a later caller's thresholds.
        let result = await controller.evaluate(input)
        guard expected == generation else { return .superseded }
        guard let current = self.lease, current.isValid(now: clock(), activeUID: self.activeUID()) else {
            return await stop()
        }
        let authorized = await controller.sessionAuthorized
        guard expected == generation else { return .superseded }
        guard self.lease?.isValid(now: clock(), activeUID: self.activeUID()) == true else { return await stop() }
        if !authorized { self.lease = nil; self.policy = nil }
        return result
    }
    /// Runtime calls this on an independent watchdog, even while evaluate awaits
    /// a bounded backend. Revocation reaches the controller before writer drain.
    @discardableResult public func enforceLease(activeUID: UInt32?) async -> Bool {
        guard let lease = lease ?? pendingLease else { return false }
        guard lease.isValid(now: clock(), activeUID: activeUID), activeUID == self.activeUID() else {
            _ = await stop(); return false
        }
        return true
    }
    @discardableResult public func stop(forSleep: Bool = false) async -> ThermalControlResult {
        generation &+= 1; lease = nil; policy = nil; pendingLease = nil
        return await controller.stop(forSleep: forSleep)
    }
    public func disconnected(_ owner: UUID) async {
        if lease?.owner == owner || pendingLease?.owner == owner { _ = await stop() }
    }
}
