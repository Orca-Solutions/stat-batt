import Foundation
import Testing
@testable import StatBattControlProtocol

private final class SleepJournal: ThermalOwnershipJournalStorage, @unchecked Sendable {
    var record: ThermalOwnershipRecord?
    var failRestoreIntent = false
    var failConfirmation = false
    func load() throws -> ThermalOwnershipRecord? { record }
    func save(_ record: ThermalOwnershipRecord) throws {
        if (failRestoreIntent && record.phase == .restorationIntent) || (failConfirmation && record.phase == .restored) {
            throw ThermalJournalError.unavailable
        }
        self.record = record
    }
}
private actor SleepBackend: ThermalSleepRecoveryBackend {
    var calls: [String] = []
    let reaped: Bool
    let observation: ThermalRestorationObservation?
    var gate: CheckedContinuation<Void, Never>?
    var blocked = false
    init(reaped: Bool = true, observation: ThermalRestorationObservation?) {
        self.reaped = reaped; self.observation = observation
    }
    func block() { blocked = true }
    func release() { blocked = false; gate?.resume(); gate = nil }
    func stopAndReapWriter() async -> Bool {
        calls.append("reap")
        if blocked { await withCheckedContinuation { gate = $0 } }
        return reaped
    }
    func restoreAdapter() async -> UInt64? { calls.append("restore"); return 30 }
    func observeRestoration() async -> ThermalRestorationObservation? { calls.append("observe"); return observation }
}
private func sleepObservation(_ boot: UUID, at time: UInt64 = 31) -> ThermalRestorationObservation {
    .init(bootID: boot, keyIsZero: true, keyObservedAt: time, adapterSupplyingPower: true, sourceObservedAt: time, now: 31)
}

@Test func sleepRecoveryOrdersReapRestoreObservationAndPersistsDespiteIntentError() async throws {
    let boot = UUID(), store = SleepJournal()
    let ledger = try ThermalOwnershipLedger(storage: store, bootID: boot)
    let op = try await ledger.prepareInhibition(sessionID: UUID(), now: 10)
    store.failRestoreIntent = true
    let backend = SleepBackend(observation: sleepObservation(boot))
    let recovery = ThermalSleepRecovery(ledger: ledger, backend: backend, clock: { 31 })
    #expect(await recovery.prepareForSleep(operationID: op, now: 20) == .verified)
    #expect(await backend.calls == ["reap", "restore", "observe"])
    #expect(store.record?.phase == .restored)
    #expect(!(await recovery.mayInhibit))
}

@Test func unreapedWriterNeverAllowsRestore() async throws {
    let boot = UUID(), store = SleepJournal()
    let ledger = try ThermalOwnershipLedger(storage: store, bootID: boot)
    let op = try await ledger.prepareInhibition(sessionID: UUID(), now: 10)
    let backend = SleepBackend(reaped: false, observation: sleepObservation(boot))
    let recovery = ThermalSleepRecovery(ledger: ledger, backend: backend, clock: { 31 })
    #expect(await recovery.prepareForSleep(operationID: op, now: 20) == .writerNotReaped)
    #expect(await backend.calls == ["reap"])
    #expect(await ledger.blocksInhibitionAndUninstall)
}

@Test func sleepRecoveryRejectsOldBootPreRestoreAndUndurableProof() async throws {
    let boot = UUID()
    for (observation, failSave) in [(sleepObservation(UUID()), false), (sleepObservation(boot, at: 29), false), (sleepObservation(boot), true)] {
        let store = SleepJournal()
        let ledger = try ThermalOwnershipLedger(storage: store, bootID: boot)
        let op = try await ledger.prepareInhibition(sessionID: UUID(), now: 10)
        store.failConfirmation = failSave
        let recovery = ThermalSleepRecovery(ledger: ledger, backend: SleepBackend(observation: observation), clock: { 31 })
        #expect(await recovery.prepareForSleep(operationID: op, now: 20) == .verificationOrPersistenceFailed)
        #expect(await ledger.blocksInhibitionAndUninstall)
    }
}

@Test func duplicateSleepCoalescesAndWakeNeverReauthorizes() async throws {
    let boot = UUID(), store = SleepJournal()
    let ledger = try ThermalOwnershipLedger(storage: store, bootID: boot)
    let op = try await ledger.prepareInhibition(sessionID: UUID(), now: 10)
    let backend = SleepBackend(observation: sleepObservation(boot))
    await backend.block()
    let recovery = ThermalSleepRecovery(ledger: ledger, backend: backend, clock: { 31 })
    let first = Task { await recovery.prepareForSleep(operationID: op, now: 20) }
    while await backend.calls.isEmpty { await Task.yield() }
    let second = Task { await recovery.prepareForSleep(operationID: op, now: 20) }
    // Wait for both callers to enter without relying on elapsed wall time.
    while await recovery.waitingCallerCount < 2 { await Task.yield() }
    await recovery.woke()
    #expect(!(await recovery.authorizeSession()))
    await backend.release()
    #expect(await first.value == .verified)
    #expect(await second.value == .verified)
    #expect(await backend.calls == ["reap", "restore", "observe"])
    #expect(!(await recovery.mayInhibit))
    // A new deliberate authorization can follow fully verified recovery.
    #expect(await recovery.authorizeSession())
}

@Test func sleepRecoveryRejectsWrongOrAbsentOwnershipBeforeHardware() async throws {
    for hasIntent in [false, true] {
        let boot = UUID(), store = SleepJournal()
        let ledger = try ThermalOwnershipLedger(storage: store, bootID: boot)
        if hasIntent { _ = try await ledger.prepareInhibition(sessionID: UUID(), now: 10) }
        let backend = SleepBackend(observation: sleepObservation(boot))
        let recovery = ThermalSleepRecovery(ledger: ledger, backend: backend, clock: { 31 })
        #expect(await recovery.prepareForSleep(operationID: UUID(), now: 20) == .noOwnedOperation)
        #expect(await backend.calls.isEmpty)
    }
}

@Test func sleepCallerCancellationDoesNotAbandonRecovery() async throws {
    let boot = UUID(), store = SleepJournal()
    let ledger = try ThermalOwnershipLedger(storage: store, bootID: boot)
    let op = try await ledger.prepareInhibition(sessionID: UUID(), now: 10)
    let backend = SleepBackend(observation: sleepObservation(boot))
    await backend.block()
    let recovery = ThermalSleepRecovery(ledger: ledger, backend: backend, clock: { 31 })
    let caller = Task { await recovery.prepareForSleep(operationID: op, now: 20) }
    while await backend.calls.isEmpty { await Task.yield() }
    caller.cancel()
    await backend.release()
    #expect(await caller.value == .verified)
    #expect(await backend.calls == ["reap", "restore", "observe"])
    #expect(store.record?.phase == .restored)
}


private final class SleepTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 31
    func read() -> UInt64 { lock.lock(); defer { lock.unlock() }; return value }
    func advance() { lock.lock(); defer { lock.unlock() }; value = 2_000_000_032 }
}
private struct DelayedSleepObservationBackend: ThermalSleepRecoveryBackend {
    let boot: UUID
    let clock: SleepTestClock
    func stopAndReapWriter() async -> Bool { true }
    func restoreAdapter() async -> UInt64? { 30 }
    func observeRestoration() async -> ThermalRestorationObservation? {
        clock.advance()
        return sleepObservation(boot)
    }
}
@Test func sleepRecoveryRejectsBackendObservationDelayedBeyondFreshness() async throws {
    let boot = UUID(), store = SleepJournal(), clock = SleepTestClock()
    let ledger = try ThermalOwnershipLedger(storage: store, bootID: boot)
    let op = try await ledger.prepareInhibition(sessionID: UUID(), now: 10)
    let recovery = ThermalSleepRecovery(ledger: ledger,
        backend: DelayedSleepObservationBackend(boot: boot, clock: clock), clock: { clock.read() })
    #expect(await recovery.prepareForSleep(operationID: op, now: 20) == .verificationOrPersistenceFailed)
    #expect(await ledger.blocksInhibitionAndUninstall)
}
