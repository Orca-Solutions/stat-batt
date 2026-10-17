import Foundation
import StatBattDomain

public struct ThermalInhibitionObservation: Sendable {
    public let bootID: UUID
    public let operationID: UUID
    public let inhibited: Bool
    public let batterySupplyingPower: Bool
    public let observedAt: UInt64
    public init(bootID: UUID, operationID: UUID, inhibited: Bool, batterySupplyingPower: Bool, observedAt: UInt64) {
        self.bootID = bootID; self.operationID = operationID; self.inhibited = inhibited
        self.batterySupplyingPower = batterySupplyingPower; self.observedAt = observedAt
    }
}
/// Bounded, serialized writes are mandatory. Inhibit must independently recheck
/// the live zero baseline and physical preconditions. No production provider exists.
public protocol ThermalControlBackend: ThermalSleepRecoveryBackend {
    func inhibitAdapter(operationID: UUID) async -> Bool
    func observeInhibition(operationID: UUID) async -> ThermalInhibitionObservation?
}
public enum ThermalControlResult: Equatable, Sendable {
    case idle, inhibited, holding, restored, stopped, busy, superseded, recoveryUnknown
}

/// Injected execution orchestration only. No hardware capability is manufactured,
/// and no session authorization is persisted or resumed after process restart.
public actor ThermalControlOrchestrator {
    private let ledger: ThermalOwnershipLedger
    private let backend: any ThermalControlBackend
    private let recovery: ThermalSleepRecovery
    private let bootID: UUID
    private let clock: @Sendable () -> UInt64
    private var session: (id: UUID, started: UInt64, deadline: UInt64)?
    private var operation: (id: UUID, started: UInt64)?
    private var lastRestored: UInt64?
    private var sleeping = false
    private var epoch: UInt64 = 0
    private var cycle: Task<ThermalControlResult, Never>?
    private var stopping: Task<ThermalControlResult, Never>?

    public init(ledger: ThermalOwnershipLedger, backend: any ThermalControlBackend,
                bootID: UUID, clock: @escaping @Sendable () -> UInt64) {
        self.ledger = ledger; self.backend = backend; self.bootID = bootID; self.clock = clock
        recovery = ThermalSleepRecovery(ledger: ledger, backend: backend, clock: clock)
    }
    public var sessionAuthorized: Bool { session != nil && stopping == nil }
    public func authorize(sessionID: UUID, deadline: UInt64) async -> Bool {
        let generation = epoch, now = clock()
        guard !sleeping, cycle == nil, stopping == nil, session == nil,
              deadline > now, deadline - now <= 3_600_000_000_000 else { return false }
        let blocked = await ledger.blocksInhibitionAndUninstall
        guard generation == epoch, !sleeping, session == nil, cycle == nil, stopping == nil, !blocked else { return false }
        session = (sessionID, now, deadline); lastRestored = nil
        return true
    }
    public func evaluate(_ supplied: ThermalAdapterInput) async -> ThermalControlResult {
        guard stopping == nil else { return .busy }
        guard cycle == nil else { return .busy }
        let generation = epoch
        let task = Task { await self.run(supplied, generation: generation) }
        cycle = task
        let result = await task.value
        cycle = nil
        return result
    }
    /// Revokes immediately, drains the bounded in-flight cycle, then reaps before
    /// restore. No timeout races a still-live writer; cannot veto forced sleep.
    public func stop(forSleep: Bool = false) async -> ThermalControlResult {
        epoch &+= 1; session = nil
        if forSleep { sleeping = true }
        if let stopping { return await stopping.value }
        let existing = cycle
        let task = Task { [self] in
            if let existing { _ = await existing.value }
            return await restore(sleeping: forSleep)
        }
        stopping = task
        let result = await task.value
        stopping = nil
        return result
    }
    public func woke() async {
        let expected = epoch &+ 1
        _ = await stop(forSleep: true) // Also recovers when the sleep notification was missed.
        guard epoch == expected else { return } // A newer sleep request wins.
        await recovery.woke()
        guard epoch == expected else { return }
        sleeping = false
    }
    private func input(_ supplied: ThermalAdapterInput) -> ThermalAdapterInput {
        var value = supplied
        value.now = clock(); value.bootID = bootID
        value.authorized = session != nil
        value.awake = supplied.awake && !sleeping
        if let session {
            value.sessionStartedAt = session.started; value.sessionDeadline = session.deadline
            value.minimumSampleTime = max(value.minimumSampleTime, session.started)
        }
        value.pauseStartedAt = operation?.started; value.lastRestoredAt = lastRestored
        return value
    }
    private func run(_ supplied: ThermalAdapterInput, generation: UInt64) async -> ThermalControlResult {
        guard generation == epoch else { return .superseded }
        var value = input(supplied)
        if let operation {
            guard let observation = await backend.observeInhibition(operationID: operation.id),
                  generation == epoch, observation.bootID == bootID, observation.operationID == operation.id,
                  observation.inhibited, observation.batterySupplyingPower else {
                session = nil; return await restore()
            }
            value = input(supplied)
            value.observation = .inhibitedByThisSession; value.controlObservedAt = observation.observedAt
        }
        let decision = ThermalAdapterReducer.evaluate(value)
        if decision.effect != .inhibitAdapter {
            if decision.endSession { session = nil }
            return await restore()
        }
        if operation != nil { return .holding } // Never rewrite a held cut.
        guard let session, generation == epoch else { return .superseded }
        let started = clock()
        let id: UUID
        do { id = try await ledger.prepareInhibition(sessionID: session.id, now: started) }
        catch { self.session = nil; return await restore() }
        operation = (id, started)
        // Durable storage can take time: re-evaluate the original sample against
        // the trusted current clock before submitting any hardware operation.
        guard generation == epoch else { return .superseded }
        var recheck = input(supplied)
        recheck.pauseStartedAt = nil // Intent exists, but hardware is still enabled.
        guard ThermalAdapterReducer.evaluate(recheck).effect == .inhibitAdapter else {
            self.session = nil; return await restore()
        }
        guard await backend.inhibitAdapter(operationID: id) else { self.session = nil; return await restore() }
        let floor = clock()
        guard generation == epoch else { return .superseded }
        // Initial physical source telemetry can lag the acknowledged key write.
        // This grace observes only; it never rewrites or renews the worker lease.
        let settlingEnd = ContinuousClock.now + .seconds(2)
        var confirmed = false
        repeat {
            guard generation == epoch else { return .superseded }
            let now = clock()
            guard now >= floor, now - floor <= 2_000_000_000, now < session.deadline,
                  now >= started, Double(now - started) / 1_000_000_000 < supplied.policy.maximumPauseSeconds,
                  ContinuousClock.now < settlingEnd else { break }
            let observed = await backend.observeInhibition(operationID: id)
            guard generation == epoch else { return .superseded }
            let received = clock()
            guard let observed, observed.bootID == bootID, observed.operationID == id, observed.inhibited,
                  observed.observedAt >= floor, observed.observedAt <= received,
                  received >= floor, received - floor <= 2_000_000_000,
                  received - observed.observedAt <= 2_000_000_000,
                  received < session.deadline, ContinuousClock.now < settlingEnd else { break }
            if observed.batterySupplyingPower { confirmed = true; break }
            try? await Task.sleep(for: .milliseconds(20))
        } while true
        guard confirmed else {
            self.session = nil; return await restore()
        }
        let completedAt = clock()
        guard completedAt < session.deadline, completedAt >= started,
              Double(completedAt - started) / 1_000_000_000 < supplied.policy.maximumPauseSeconds else {
            self.session = nil; return await restore()
        }
        return .inhibited
    }
    private func restore(sleeping: Bool = false) async -> ThermalControlResult {
        guard let record = await ledger.snapshot, record.unresolved else {
            return await ledger.blocksInhibitionAndUninstall ? .recoveryUnknown : .idle
        }
        let result = sleeping
            ? await recovery.prepareForSleep(operationID: record.operationID, now: clock())
            : await recovery.restoreOwnedOperation(operationID: record.operationID, now: clock())
        guard result == .verified else { session = nil; return .recoveryUnknown }
        operation = nil; lastRestored = clock()
        return session == nil ? .stopped : .restored
    }
}
