import Foundation
import Darwin
import Testing
import StatBattDomain
@testable import StatBattNativeLimit

private func qualifiedPlatform() -> PlatformFingerprint {
    PlatformFingerprint(model: "Mac16,13", architecture: "arm64", operatingSystemVersion: "27.0.1",
        operatingSystemBuild: "26A434", firmwareVersion: "mBoot-20457.1.29", providerVersion: "test.synthetic")
}
private final class MemoryJournal: NativeLimitJournalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var journal: NativeLimitJournal?
    private var saves = 0
    private var failureAt: Int?
    init(_ journal: NativeLimitJournal? = nil) { self.journal = journal }
    func load() throws -> NativeLimitJournal? { lock.withLock { journal } }
    func save(_ journal: NativeLimitJournal) throws {
        try lock.withLock {
            saves += 1
            if failureAt == saves { throw NativeLimitFailure.journalUnavailable }
            self.journal = journal
        }
    }
    func failSave(_ count: Int?) { lock.withLock { failureAt = count } }
}
private struct TestInstanceLock: NativeLimitInstanceLock {
    let blocked: Bool
    init(blocked: Bool = false) { self.blocked = blocked }
    func acquire() throws { if blocked { throw NativeLimitFailure.anotherInstance } }
}
private actor FakeTransport: NativeShortcutTransport {
    var identities = NativeFixedLimit.allCases.map { NativeShortcutIdentity(id: UUID(), name: $0.expectedShortcutName) }
    var executions: [NativeFixedLimit] = []
    let result: NativeExecutionResult
    let store: MemoryJournal
    let holdExecution: Bool
    var release: CheckedContinuation<NativeExecutionResult, Never>?
    var startedWaiters: [CheckedContinuation<Void, Never>] = []
    init(store: MemoryJournal, result: NativeExecutionResult = .acknowledged, holdExecution: Bool = false) {
        self.store = store; self.result = result; self.holdExecution = holdExecution
    }
    func listShortcuts() async throws -> [NativeShortcutIdentity] { identities }
    func executeTrusted(_ shortcut: TrustedNativeShortcut) async -> NativeExecutionResult {
        executions.append(shortcut.limit)
        let journal = try? store.load()
        #expect(journal?.phase == .requested)
        #expect(journal?.operationID != nil)
        #expect(journal?.requestedLimit == shortcut.limit)
        #expect(journal?.trust(for: shortcut.limit)?.shortcutUUID == shortcut.id)
        if shortcut.limit == .hundred { #expect(journal?.qualification100AttemptedAtUTC != nil) }
        for waiter in startedWaiters { waiter.resume() }; startedWaiters = []
        if holdExecution { return await withCheckedContinuation { release = $0 } }
        return result
    }
    func setIdentities(_ values: [NativeShortcutIdentity]) { identities = values }
    func waitUntilExecution() async {
        if !executions.isEmpty { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }
    func finishExecution() { release?.resume(returning: result); release = nil }
}
private actor Preflight {
    var results: [NativePreflightResult] = [.clear]
    func value() -> NativePreflightResult { results.count > 1 ? results.removeFirst() : results[0] }
    func set(_ values: [NativePreflightResult]) { results = values }
}
private func coordinator(store: MemoryJournal, transport: FakeTransport, platform: PlatformFingerprint = qualifiedPlatform(), preflight: Preflight = Preflight()) throws -> NativeLimitCoordinator {
    try NativeLimitCoordinator(platform: platform, storage: store, transport: transport, instanceLock: TestInstanceLock(),
        clock: { Date(timeIntervalSince1970: 1_800_000_000.125) }, preflight: { await preflight.value() })
}
private func configure(_ coordinator: NativeLimitCoordinator, _ limit: NativeFixedLimit = .eighty) async throws -> NativeLimitStatus {
    try await coordinator.configureTrustedShortcut(for: limit, acknowledgement: .approvedMutableUserWorkflow,
        confirmedOtherControllersStopped: true)
}
private func expectFailure(_ failure: NativeLimitFailure, _ action: () async throws -> NativeLimitStatus) async {
    do { _ = try await action(); Issue.record("Expected rejection: \(failure)") }
    catch { #expect(error as? NativeLimitFailure == failure) }
}

@Test func separateOwnerTrustPrecedesAnyDispatchAndDoesNotGrant100Qualification() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let coordinator = try coordinator(store: store, transport: transport)
    #expect(try await coordinator.discoverConfiguredShortcut(for: .eighty))
    await expectFailure(.trustNotApproved) { try await coordinator.request(.eighty) }
    await expectFailure(.controllersNotConfirmedStopped) {
        try await coordinator.configureTrustedShortcut(for: .eighty, acknowledgement: .approvedMutableUserWorkflow,
            confirmedOtherControllersStopped: false)
    }
    _ = try await configure(coordinator)
    let originalTrust = try #require(try store.load()?.trust80)
    let state = try await configure(coordinator, .hundred)
    #expect(state.trustedLimits == [.eighty, .hundred])
    #expect(state.qualifiedLimits == [.eighty])
    #expect(state.canRequest80 && !state.canRequest100)
    #expect(try store.load()?.trust80?.shortcutUUID == originalTrust.shortcutUUID)
    #expect(try store.load()?.trust80?.approvedAtUTC == originalTrust.approvedAtUTC)
    await expectFailure(.unqualifiedTarget) { try await coordinator.request(.hundred) }
    #expect(await transport.executions.isEmpty)
}
@Test func durableAcknowledgementAllowsNextExplicitRequestAndSurvivesRestartWithoutReplay() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let first = try coordinator(store: store, transport: transport)
    _ = try await configure(first)
    let receipt = try await first.request(.eighty)
    #expect(receipt.phase == .acknowledgedUnverified)
    #expect(!receipt.requiresManualRecovery && receipt.canRequest80)
    #expect(receipt.lastRequestedLimit == .eighty && receipt.lastObservedLimit == nil)
    let restarted = try coordinator(store: store, transport: transport)
    let restored = await restarted.status()
    #expect(restored.phase == .acknowledgedUnverified && restored.canRequest80)
    #expect(restored.operationID == receipt.operationID && restored.requestedAtUTC == receipt.requestedAtUTC)
    #expect(await transport.executions == [.eighty])
    let next = try await restarted.request(.eighty)
    #expect(next.operationID != receipt.operationID)
    #expect(await transport.executions == [.eighty, .eighty])
}
@Test func observationRemainsHistoricalAcrossLaterRequest() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let coordinator = try coordinator(store: store, transport: transport)
    _ = try await configure(coordinator); _ = try await coordinator.request(.eighty)
    let observed = try await coordinator.confirmVisibleLimit(.hundred)
    #expect(observed.lastRequestedLimit == .eighty && observed.lastObservedLimit == .hundred)
    _ = try await coordinator.request(.eighty)
    #expect(await coordinator.status().confirmedAtUTC == observed.confirmedAtUTC)
    #expect(await coordinator.status().lastObservedLimit == .hundred)
}
@Test func journalIntentFailurePreventsExecution() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let coordinator = try coordinator(store: store, transport: transport)
    _ = try await configure(coordinator); store.failSave(2)
    await expectFailure(.journalUnavailable) { try await coordinator.request(.eighty) }
    #expect(await transport.executions.isEmpty)
    #expect(await coordinator.status().journalHealthy == false)
}
@Test func resultPersistenceFailurePreservesPendingIntentAndBlocksReplayOnRestart() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let first = try coordinator(store: store, transport: transport)
    _ = try await configure(first); store.failSave(3)
    await expectFailure(.journalUnavailable) { try await first.request(.eighty) }
    #expect(try store.load()?.phase == .requested)
    let originalOperation = try store.load()?.operationID
    store.failSave(nil)
    let restarted = try coordinator(store: store, transport: transport)
    #expect(await restarted.status().phase == .outcomeUnknown)
    #expect(await restarted.status().operationID == originalOperation)
    await expectFailure(.manualRecoveryRequired) { try await restarted.request(.eighty) }
    #expect(await transport.executions == [.eighty])
}
@Test func everyUncertainResultRequiresFinishedAndVisibleReconciliation() async throws {
    for result in [NativeExecutionResult.failed, .timedOut, .cancelled, .outputOverflow, .notLaunched] {
        let store = MemoryJournal(); let transport = FakeTransport(store: store, result: result)
        let coordinator = try coordinator(store: store, transport: transport)
        _ = try await configure(coordinator); _ = try await configure(coordinator, .hundred)
        let receipt = try await coordinator.request(.eighty)
        #expect(receipt.phase == .outcomeUnknown && receipt.requiresManualRecovery)
        await expectFailure(.manualRecoveryRequired) { try await coordinator.request(.eighty) }
        await expectFailure(.manualRecoveryRequired) { try await coordinator.request(.hundred) }
        await expectFailure(.manualRecoveryRequired) { try await coordinator.forgetSetup() }
        let observation = try await coordinator.confirmVisibleLimit(.eighty)
        #expect(observation.requiresManualRecovery)
        await expectFailure(.invalidConfirmation) { try await coordinator.reconcileVisibleLimit(.eighty, priorShortcutCompletedOrStopped: false) }
        let reconciled = try await coordinator.reconcileVisibleLimit(.eighty, priorShortcutCompletedOrStopped: true)
        #expect(reconciled.phase == .ownerReconciled && reconciled.canRequest80)
        #expect(reconciled.lastObservedLimit == .eighty)
        #expect(await transport.executions == [.eighty])
    }
}
@Test func missingDuplicateAndReplacedIdentityAreTargetSpecificAndNeverDispatched() async throws {
    for limit in NativeFixedLimit.allCases {
        let store = MemoryJournal(); let transport = FakeTransport(store: store)
        let coordinator = try coordinator(store: store, transport: transport)
        _ = try await configure(coordinator, limit)
        let original = try #require(try store.load()?.trust(for: limit)?.shortcutUUID)
        await transport.setIdentities([])
        do { _ = try await coordinator.discoverConfiguredShortcut(for: limit) } catch { Issue.record("Absent discovery should return false") }
        await transport.setIdentities([NativeShortcutIdentity(id: original, name: limit.expectedShortcutName),
            NativeShortcutIdentity(id: UUID(), name: limit.expectedShortcutName)])
        do { _ = try await coordinator.discoverConfiguredShortcut(for: limit); Issue.record("Duplicate discovery accepted") }
        catch { #expect(error as? NativeLimitFailure == .shortcutAmbiguous) }
        await transport.setIdentities([NativeShortcutIdentity(id: UUID(), name: limit.expectedShortcutName)])
        do { _ = try await coordinator.discoverConfiguredShortcut(for: limit); Issue.record("Replaced discovery accepted") }
        catch { #expect(error as? NativeLimitFailure == .shortcutIdentityChanged) }
        await expectFailure(.shortcutIdentityChanged) { try await configure(coordinator, limit) }
        if limit == .eighty { await expectFailure(.shortcutIdentityChanged) { try await coordinator.request(limit) } }
        #expect(await transport.executions.isEmpty)
    }
}
@Test func exactPlatformAndBothPreflightChecksAreRequired() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    var platform = qualifiedPlatform(); platform.operatingSystemBuild = "different-build"
    let unqualified = try coordinator(store: store, transport: transport, platform: platform)
    await expectFailure(.unqualifiedTarget) { try await configure(unqualified) }
    let preflight = Preflight()
    let eligible = try coordinator(store: store, transport: transport, preflight: preflight)
    await preflight.set([.unavailable])
    await expectFailure(.preflightUnavailable) { try await configure(eligible) }
    await preflight.set([.clear]); _ = try await configure(eligible)
    await preflight.set([.clear, .conflictingController])
    await expectFailure(.controllerConflict) { try await eligible.request(.eighty) }
    #expect(await transport.executions.isEmpty)
}
@Test func busyFenceRejectsBothTargetsSetupObservationAndRecovery() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store, holdExecution: true)
    let coordinator = try coordinator(store: store, transport: transport)
    _ = try await configure(coordinator)
    let task = Task { try await coordinator.request(.eighty) }
    await transport.waitUntilExecution()
    #expect(await coordinator.status().phase == .requested)
    for limit in NativeFixedLimit.allCases {
        await expectFailure(.executionInProgress) { try await coordinator.request(limit) }
        await expectFailure(.executionInProgress) { try await configure(coordinator, limit) }
        await expectFailure(.executionInProgress) { try await coordinator.confirmVisibleLimit(limit) }
        await expectFailure(.executionInProgress) { try await coordinator.reconcileVisibleLimit(limit, priorShortcutCompletedOrStopped: true) }
    }
    await transport.finishExecution()
    #expect(try await task.value.phase == .acknowledgedUnverified)
    #expect(await transport.executions == [.eighty])
}

#if STATBATT_NATIVE_100_QUALIFICATION
@Test func supervisedTrialUses100IdentityButNeverProductionQualificationAndSurvivesRestartAndForget() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let first = try coordinator(store: store, transport: transport)
    _ = try await configure(first); _ = try await configure(first, .hundred)
    #expect(await first.status().canRunSupervised100Qualification)
    await expectFailure(.unqualifiedTarget) { try await first.request(.hundred) }
    let receipt = try await first.requestSupervised100Qualification()
    #expect(receipt.lastRequestedLimit == .hundred && receipt.phase == .acknowledgedUnverified)
    #expect(receipt.qualifiedLimits == [.eighty] && !receipt.canRequest100 && !receipt.canRunSupervised100Qualification)
    let restarted = try coordinator(store: store, transport: transport)
    await expectFailure(.qualificationAlreadyAttempted) { try await restarted.requestSupervised100Qualification() }
    _ = try await restarted.request(.eighty)
    _ = try await restarted.forgetSetup()
    _ = try await configure(restarted, .hundred)
    #expect(!((await restarted.status()).canRunSupervised100Qualification))
    await expectFailure(.qualificationAlreadyAttempted) { try await restarted.requestSupervised100Qualification() }
    #expect(await transport.executions == [.hundred, .eighty])
}
@Test func trialMarkerPrecedesExecutionAndRemainsUsedAfterResultPersistenceFailure() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let first = try coordinator(store: store, transport: transport)
    _ = try await configure(first, .hundred); store.failSave(3)
    await expectFailure(.journalUnavailable) { try await first.requestSupervised100Qualification() }
    #expect(try store.load()?.qualification100AttemptedAtUTC != nil)
    store.failSave(nil)
    let restarted = try coordinator(store: store, transport: transport)
    #expect(await restarted.status().requiresManualRecovery)
    await expectFailure(.manualRecoveryRequired) { try await restarted.requestSupervised100Qualification() }
    _ = try await restarted.reconcileVisibleLimit(.hundred, priorShortcutCompletedOrStopped: true)
    await expectFailure(.qualificationAlreadyAttempted) { try await restarted.requestSupervised100Qualification() }
    #expect(await transport.executions == [.hundred])
}
#else
@Test func normalBuildHasNoTrialEligibilityEvenWith100Trust() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let coordinator = try coordinator(store: store, transport: transport)
    _ = try await configure(coordinator, .hundred)
    #expect(!((await coordinator.status()).canRunSupervised100Qualification))
    await expectFailure(.unqualifiedTarget) { try await coordinator.request(.hundred) }
    #expect(await transport.executions.isEmpty)
}
#endif
