import Foundation
import Testing
import StatBattDomain
@testable import StatBattControlProtocol

private final class ControlClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 100_000_000_000
    func now() -> UInt64 { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ nanos: UInt64) { lock.lock(); defer { lock.unlock() }; value += nanos }
}
private final class ControlJournal: ThermalOwnershipJournalStorage, @unchecked Sendable {
    var record: ThermalOwnershipRecord?
    var delayOnIntent: (() -> Void)?
    func load() throws -> ThermalOwnershipRecord? { record }
    func save(_ value: ThermalOwnershipRecord) throws {
        if value.phase == .inhibitionIntent { delayOnIntent?() }
        record = value
    }
}
private actor ControlBackend: ThermalControlBackend {
    let boot: UUID, clock: ControlClock
    var calls: [String] = []
    var waitForInhibit = false
    var gate: CheckedContinuation<Void, Never>?
    var failObservation = false
    var observationDelay: UInt64 = 0
    init(boot: UUID, clock: ControlClock) { self.boot = boot; self.clock = clock }
    func blockInhibit() { waitForInhibit = true }
    func releaseInhibit() { waitForInhibit = false; gate?.resume(); gate = nil }
    func failReadback() { failObservation = true }
    func delayObservation(_ nanos: UInt64) { observationDelay = nanos }
    func inhibitAdapter(operationID: UUID) async -> Bool {
        calls.append("inhibitStarted")
        if waitForInhibit { await withCheckedContinuation { gate = $0 } }
        calls.append("write08")
        return true
    }
    func observeInhibition(operationID: UUID) async -> ThermalInhibitionObservation? {
        calls.append("read08")
        clock.advance(observationDelay)
        if failObservation { return nil }
        return .init(bootID: boot, operationID: operationID, inhibited: true, batterySupplyingPower: true, observedAt: clock.now())
    }
    func stopAndReapWriter() async -> Bool { calls.append("reap"); return true }
    func restoreAdapter() async -> UInt64? { calls.append("write00"); return clock.now() }
    func observeRestoration() async -> ThermalRestorationObservation? {
        calls.append("read00")
        return .init(bootID: boot, keyIsZero: true, keyObservedAt: clock.now(), adapterSupplyingPower: true, sourceObservedAt: clock.now(), now: clock.now())
    }
}
private func controlInput(boot: UUID, now: UInt64, hot: Bool = true, inhibited: Bool = false) -> ThermalAdapterInput {
    var sample = BatterySnapshot(bootID: boot)
    func metric<T>(_ value: T) -> Metric<T> { .init(value: value, quality: .observed, sampledAtContinuousNanoseconds: now, source: "test") }
    sample.batteryPresent = metric(true); sample.adapterAttached = metric(!inhibited)
    sample.supplyingSource = metric(inhibited ? .battery : .adapter)
    sample.stateOfChargePercent = metric(80); sample.thermalPressure = metric(.nominal)
    sample.batteryTemperatureCelsius = metric(hot ? 40 : 37)
    let verified = Capability(status: .verified, scope: .awakeOnly, evidence: [.init(identifier: "test", provenance: "fixture only")], verifiedAtUTC: Date(), restorationVerified: true, crashRecoveryBoundSeconds: 5)
    var caps = CapabilitySnapshot()
    caps.canInhibitAdapter = verified; caps.canRestoreOwnedControl = verified
    caps.canReadControlState = verified; caps.canObserveBatteryTemperature = verified
    caps.verifiedBatteryTemperatureBoundsCelsius = .init(lower: 0, upper: 60)
    var input = ThermalAdapterInput(policy: .init(enabled: true), capabilities: caps, telemetry: sample, bootID: boot, now: now, sessionStartedAt: 0, sessionDeadline: UInt64.max)
    input.recoveryComplete = true; input.observation = .enabled; input.controlObservedAt = now
    return input
}

@Test func thermalSessionMissingHeartbeatRestoresWithoutAnotherWrite() async throws {
    let boot = UUID(), owner = UUID(), clock = ControlClock(), storage = ControlJournal()
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
    let backend = ControlBackend(boot: boot, clock: clock)
    let control = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot, clock: { clock.now() })
    let session = ThermalPolicySession(controller: control, clock: { clock.now() }, activeUID: { 501 })
    #expect(await session.start(owner: owner, uid: 501, policy: .init(enabled: true)))
    #expect(await session.tick(controlInput(boot: boot, now: clock.now()), activeUID: 501) == .inhibited)
    #expect(!(await session.heartbeat(owner: UUID(), activeUID: 501)))
    clock.advance(ThermalSessionLease.heartbeatLimit)
    #expect(await session.tick(controlInput(boot: boot, now: clock.now(), inhibited: true), activeUID: 501) == .stopped)
    #expect(await session.owner == nil)
    #expect(!(await session.heartbeat(owner: owner, activeUID: 501)))
    #expect(storage.record?.phase == .restored)
    #expect(await backend.calls.filter { $0 == "write08" }.count == 1)
}

@Test func thermalSessionUserSwitchAndOwnerDisconnectEndConsent() async throws {
    let boot = UUID(), owner = UUID(), clock = ControlClock(), storage = ControlJournal()
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
    let backend = ControlBackend(boot: boot, clock: clock)
    let control = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot, clock: { clock.now() })
    let session = ThermalPolicySession(controller: control, clock: { clock.now() }, activeUID: { 501 })
    #expect(await session.start(owner: owner, uid: 501, policy: .init(enabled: true)))
    _ = await session.tick(controlInput(boot: boot, now: clock.now()), activeUID: 502)
    #expect(await session.owner == nil)
    #expect(await backend.calls.isEmpty)
    #expect(await session.start(owner: owner, uid: 501, policy: .init(enabled: true)))
    await session.disconnected(UUID())
    #expect(await session.owner == owner)
    await session.disconnected(owner)
    #expect(await session.owner == nil)
}

@Test func thermalOrchestratorHotHoldCoolPersistsAndDoesNotRewrite() async throws {
    let boot = UUID(), clock = ControlClock(), storage = ControlJournal()
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
    let backend = ControlBackend(boot: boot, clock: clock)
    let control = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot, clock: { clock.now() })
    #expect(await control.authorize(sessionID: UUID(), deadline: clock.now() + 600_000_000_000))
    #expect(await control.evaluate(controlInput(boot: boot, now: clock.now())) == .inhibited)
    #expect(storage.record?.phase == .inhibitionIntent)
    #expect(await control.evaluate(controlInput(boot: boot, now: clock.now(), inhibited: true)) == .holding)
    #expect(await control.evaluate(controlInput(boot: boot, now: clock.now(), hot: false, inhibited: true)) == .restored)
    #expect(await control.sessionAuthorized)
    #expect(storage.record?.phase == .restored)
    #expect(await backend.calls.filter { $0 == "write08" }.count == 1)
    // Cooldown prohibits immediate re-entry despite a hot sample.
    #expect(await control.evaluate(controlInput(boot: boot, now: clock.now())) == .idle)
}

@Test func thermalOrchestratorDrainsDelayedWriterBeforeDisableAndSleepRestore() async throws {
    for sleeping in [false, true] {
        let boot = UUID(), clock = ControlClock(), storage = ControlJournal()
        let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
        let backend = ControlBackend(boot: boot, clock: clock)
        await backend.blockInhibit()
        let control = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot, clock: { clock.now() })
        #expect(await control.authorize(sessionID: UUID(), deadline: clock.now() + 600_000_000_000))
        let tick = Task { await control.evaluate(controlInput(boot: boot, now: clock.now())) }
        while await backend.calls.isEmpty { await Task.yield() }
        let stop = Task { await control.stop(forSleep: sleeping) }
        while await control.sessionAuthorized { await Task.yield() }
        await backend.releaseInhibit()
        _ = await tick.value
        #expect(await stop.value == .stopped)
        #expect(await backend.calls == ["inhibitStarted", "write08", "reap", "write00", "read00"])
        #expect(!(await control.sessionAuthorized))
        if sleeping { #expect(!(await control.authorize(sessionID: UUID(), deadline: clock.now() + 600_000_000_000))) }
    }
}

@Test func thermalOrchestratorReadbackFailureRestoresAndEndsSession() async throws {
    let boot = UUID(), clock = ControlClock(), storage = ControlJournal()
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
    let backend = ControlBackend(boot: boot, clock: clock)
    await backend.failReadback()
    let control = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot, clock: { clock.now() })
    #expect(await control.authorize(sessionID: UUID(), deadline: clock.now() + 600_000_000_000))
    #expect(await control.evaluate(controlInput(boot: boot, now: clock.now())) == .stopped)
    #expect(!(await control.sessionAuthorized))
    #expect(storage.record?.phase == .restored)
}

@Test func thermalOrchestratorSlowJournalCannotActuateStaleHotSample() async throws {
    let boot = UUID(), clock = ControlClock(), storage = ControlJournal()
    storage.delayOnIntent = { clock.advance(3_000_000_000) }
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
    let backend = ControlBackend(boot: boot, clock: clock)
    let control = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot, clock: { clock.now() })
    #expect(await control.authorize(sessionID: UUID(), deadline: clock.now() + 600_000_000_000))
    #expect(await control.evaluate(controlInput(boot: boot, now: clock.now())) == .stopped)
    #expect(await backend.calls == ["reap", "write00", "read00"])
}


@Test func thermalOrchestratorWakeAloneRecoversPendingWriterWithoutResuming() async throws {
    let boot = UUID(), clock = ControlClock(), storage = ControlJournal()
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
    let backend = ControlBackend(boot: boot, clock: clock)
    await backend.blockInhibit()
    let control = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot, clock: { clock.now() })
    #expect(await control.authorize(sessionID: UUID(), deadline: clock.now() + 600_000_000_000))
    let tick = Task { await control.evaluate(controlInput(boot: boot, now: clock.now())) }
    while await backend.calls.isEmpty { await Task.yield() }
    let wake = Task { await control.woke() }
    while await control.sessionAuthorized { await Task.yield() }
    await backend.releaseInhibit()
    _ = await tick.value
    await wake.value
    #expect(await backend.calls == ["inhibitStarted", "write08", "reap", "write00", "read00"])
    #expect(!(await control.sessionAuthorized))
    #expect(storage.record?.phase == .restored)
}

@Test func thermalOrchestratorLatePositiveReadbackCannotOutliveSessionOrPause() async throws {
    for sessionSeconds: UInt64 in [1, 600] {
        let boot = UUID(), clock = ControlClock(), storage = ControlJournal()
        let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
        let backend = ControlBackend(boot: boot, clock: clock)
        await backend.delayObservation(sessionSeconds == 1 ? 2_000_000_000 : 121_000_000_000)
        let control = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot, clock: { clock.now() })
        #expect(await control.authorize(sessionID: UUID(), deadline: clock.now() + sessionSeconds * 1_000_000_000))
        #expect(await control.evaluate(controlInput(boot: boot, now: clock.now())) == .stopped)
        #expect(!(await control.sessionAuthorized))
        #expect(storage.record?.phase == .restored)
    }
}

@Test func thermalOrchestratorNeverPromotesUnqualifiedCapabilityOrEstimatedSensor() async throws {
    for estimated in [false, true] {
        let boot = UUID(), clock = ControlClock(), storage = ControlJournal()
        let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
        let backend = ControlBackend(boot: boot, clock: clock)
        let control = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot, clock: { clock.now() })
        #expect(await control.authorize(sessionID: UUID(), deadline: clock.now() + 600_000_000_000))
        var input = controlInput(boot: boot, now: clock.now())
        if estimated { input.telemetry.batteryTemperatureCelsius.quality = .estimated }
        else { input.capabilities = CapabilitySnapshot() }
        #expect(await control.evaluate(input) == .idle)
        #expect(await backend.calls.isEmpty)
        #expect(!(await control.sessionAuthorized))
    }
}
