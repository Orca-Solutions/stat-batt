import Foundation
import Testing
import StatBattDomain
@testable import StatBattControlProtocol

private final class SessionReviewClock: @unchecked Sendable {
    private let lock = NSLock()
    private var user: UInt32? = 501
    func uid() -> UInt32? { lock.lock(); defer { lock.unlock() }; return user }
    func switchUser() { lock.lock(); user = 502; lock.unlock() }
    private var value: UInt64 = 100_000_000_000
    func now() -> UInt64 { lock.lock(); defer { lock.unlock() }; return value }
    func advance(_ nanos: UInt64) { lock.lock(); defer { lock.unlock() }; value += nanos }
}
private final class SessionReviewJournal: ThermalOwnershipJournalStorage, @unchecked Sendable {
    var record: ThermalOwnershipRecord?
    var delayOnIntent: (() -> Void)?
    func load() throws -> ThermalOwnershipRecord? { record }
    func save(_ value: ThermalOwnershipRecord) throws {
        if value.phase == .inhibitionIntent { delayOnIntent?() }
        record = value
    }
}
private actor SessionReviewBackend: ThermalControlBackend {
    let boot: UUID, clock: SessionReviewClock
    var calls: [String] = []
    var waitForInhibit = false
    var gate: CheckedContinuation<Void, Never>?
    var failObservation = false
    var observationDelay: UInt64 = 0
    init(boot: UUID, clock: SessionReviewClock) { self.boot = boot; self.clock = clock }
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
private func sessionReviewInput(boot: UUID, now: UInt64, hot: Bool = true, inhibited: Bool = false) -> ThermalAdapterInput {
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

@Test func sessionWatchdogRevokesWhileWriterSuspended() async throws {
    let boot = UUID(), clock = SessionReviewClock(), storage = SessionReviewJournal()
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
    let backend = SessionReviewBackend(boot: boot, clock: clock)
    let controller = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot, clock: { clock.now() })
    let session = ThermalPolicySession(controller: controller, clock: { clock.now() }, activeUID: { clock.uid() })
    #expect(await session.start(owner: UUID(), uid: 501, policy: .init(enabled: true)))
    await backend.blockInhibit()
    let evaluating = Task { await session.tick(sessionReviewInput(boot: boot, now: clock.now()), activeUID: 501) }
    for _ in 0..<10000 { if await backend.gate != nil { break }; await Task.yield() }
    #expect(await backend.gate != nil)
    clock.advance(ThermalSessionLease.heartbeatLimit)
    let enforcing = Task { await session.enforceLease(activeUID: 501) }
    for _ in 0..<10000 { if await session.owner == nil { break }; await Task.yield() }
    #expect(await session.owner == nil)
    await backend.releaseInhibit()
    #expect(!(await enforcing.value))
    _ = await evaluating.value
    #expect(!(await controller.sessionAuthorized))
    #expect(storage.record?.phase == .restored)
    #expect(await backend.calls.suffix(3) == ["reap", "write00", "read00"])
}

@Test func sessionRechecksLiveUserAfterEvaluationSuspends() async throws {
    let boot = UUID(), clock = SessionReviewClock(), storage = SessionReviewJournal()
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
    let backend = SessionReviewBackend(boot: boot, clock: clock)
    let controller = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot, clock: { clock.now() })
    let session = ThermalPolicySession(controller: controller, clock: { clock.now() }, activeUID: { clock.uid() })
    #expect(await session.start(owner: UUID(), uid: 501, policy: .init(enabled: true)))
    await backend.blockInhibit()
    let evaluating = Task { await session.tick(sessionReviewInput(boot: boot, now: clock.now()), activeUID: 501) }
    for _ in 0..<10000 { if await backend.gate != nil { break }; await Task.yield() }
    #expect(await backend.gate != nil)
    clock.switchUser()
    await backend.releaseInhibit()
    #expect(await evaluating.value == .stopped)
    #expect(await session.owner == nil)
    #expect(storage.record?.phase == .restored)
}
