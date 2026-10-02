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
    var identities: [NativeShortcutIdentity]
    var executions = 0
    var lists = 0
    let result: NativeExecutionResult
    let store: MemoryJournal
    let holdExecution: Bool
    var release: CheckedContinuation<NativeExecutionResult, Never>?
    var startedWaiters: [CheckedContinuation<Void, Never>] = []
    init(store: MemoryJournal, result: NativeExecutionResult = .acknowledged, holdExecution: Bool = false) {
        self.store = store; self.result = result; self.holdExecution = holdExecution
        identities = [NativeShortcutIdentity(id: UUID(), name: NativeLimitCoordinator.expectedShortcutName)]
    }
    func listShortcuts() async throws -> [NativeShortcutIdentity] { lists += 1; return identities }
    func executeTrusted80(_ shortcut: TrustedNative80Shortcut) async -> NativeExecutionResult {
        executions += 1
        let journal = try? store.load()
        #expect(journal?.phase == .requested)
        #expect(journal?.operationID != nil)
        #expect(journal?.trust?.shortcutUUID == shortcut.id)
        for waiter in startedWaiters { waiter.resume() }; startedWaiters = []
        if holdExecution { return await withCheckedContinuation { release = $0 } }
        return result
    }
    func setIdentities(_ values: [NativeShortcutIdentity]) { identities = values }
    func waitUntilExecution() async {
        if executions > 0 { return }
        await withCheckedContinuation { startedWaiters.append($0) }
    }
    func finishExecution() { release?.resume(returning: result); release = nil }
}

private actor Preflight {
    var result = NativePreflightResult.clear
    func value() -> NativePreflightResult { result }
    func set(_ value: NativePreflightResult) { result = value }
}

private func coordinator(store: MemoryJournal, transport: FakeTransport, platform: PlatformFingerprint = qualifiedPlatform(), preflight: Preflight = Preflight()) throws -> NativeLimitCoordinator {
    try NativeLimitCoordinator(platform: platform, storage: store, transport: transport, instanceLock: TestInstanceLock(),
        clock: { Date(timeIntervalSince1970: 1_800_000_000.125) }, preflight: { await preflight.value() })
}
private func configure(_ coordinator: NativeLimitCoordinator) async throws -> NativeLimitStatus {
    try await coordinator.configureTrusted80Shortcut(acknowledgement: .approvedMutableUserWorkflow,
        confirmedBaselinePercent: 100, confirmedOtherControllersStopped: true)
}

@Test func explicitTrustAndBaselinePrecedeAnyDispatch() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let coordinator = try coordinator(store: store, transport: transport)
    #expect(try await coordinator.discoverConfiguredShortcut())
    #expect(await coordinator.status().phase == .notConfigured)
    do { _ = try await coordinator.request80Percent(); Issue.record("Unapproved setup dispatched") }
    catch { #expect(error as? NativeLimitFailure == .trustNotApproved) }
    do {
        _ = try await coordinator.configureTrusted80Shortcut(acknowledgement: .approvedMutableUserWorkflow,
            confirmedBaselinePercent: 99, confirmedOtherControllersStopped: true)
        Issue.record("Wrong return baseline accepted")
    } catch { #expect(error as? NativeLimitFailure == .invalidConfirmation) }
    do {
        _ = try await coordinator.configureTrusted80Shortcut(acknowledgement: .approvedMutableUserWorkflow,
            confirmedBaselinePercent: 100, confirmedOtherControllersStopped: false)
        Issue.record("Missing controller declaration accepted")
    } catch { #expect(error as? NativeLimitFailure == .controllersNotConfirmedStopped) }
    let ready = try await configure(coordinator)
    #expect(ready.phase == .ready)
    #expect(ready.canRequest80)
    #expect(ready.baselinePercent == 100)
    #expect(await transport.executions == 0)
}

@Test func acknowledgementDoesNotClaimObservedSettingOrAllowReplay() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let coordinator = try coordinator(store: store, transport: transport)
    _ = try await configure(coordinator)
    let receipt = try await coordinator.request80Percent()
    #expect(receipt.phase == .acknowledgedUnverified)
    #expect(receipt.requiresManualRecovery)
    #expect(!receipt.canRequest80)
    #expect(try store.load()?.confirmedAtUTC == nil)
    do { _ = try await coordinator.request80Percent(); Issue.record("Unverified request replayed") }
    catch { #expect(error as? NativeLimitFailure == .manualRecoveryRequired) }
    do { _ = try await coordinator.forgetSetup(); Issue.record("Unresolved journal forgotten") }
    catch { #expect(error as? NativeLimitFailure == .manualRecoveryRequired) }
    let confirmed = try await coordinator.confirmVisibleLimit80()
    #expect(confirmed.phase == .manuallyConfirmed80)
    #expect(!confirmed.canRequest80)
    let restored = try await coordinator.confirmRestored100(priorShortcutCompletedOrStopped: true)
    #expect(restored.phase == .restoredUserConfirmed100)
    #expect(restored.canRequest80)
    #expect(await transport.executions == 1)
}

@Test func journalIntentFailurePreventsExecution() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let coordinator = try coordinator(store: store, transport: transport)
    _ = try await configure(coordinator)
    store.failSave(2)
    do { _ = try await coordinator.request80Percent(); Issue.record("Journal failure accepted") }
    catch { #expect(error as? NativeLimitFailure == .journalUnavailable) }
    #expect(await transport.executions == 0)
    #expect(await coordinator.status().canRequest80 == false)
    #expect(await coordinator.status().lastError == .journalUnavailable)
}

@Test func resultPersistenceFailureRetainsPendingRecoveryWithoutReplay() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let coordinator = try coordinator(store: store, transport: transport)
    _ = try await configure(coordinator)
    store.failSave(3)
    do { _ = try await coordinator.request80Percent(); Issue.record("Final journal failure accepted") }
    catch { #expect(error as? NativeLimitFailure == .journalUnavailable) }
    #expect(await transport.executions == 1)
    #expect(try store.load()?.phase == .requested)
    store.failSave(nil)
    let restored = try NativeLimitCoordinator(platform: qualifiedPlatform(), storage: store, transport: transport,
        instanceLock: TestInstanceLock(), preflight: { .clear })
    #expect(await restored.status().phase == .outcomeUnknown)
    do { _ = try await restored.request80Percent(); Issue.record("Pending attempt replayed after restart") }
    catch { #expect(error as? NativeLimitFailure == .manualRecoveryRequired) }
    #expect(await transport.executions == 1)
}

@Test func everyNonAcknowledgedResultRequiresManualRecovery() async throws {
    for result in [NativeExecutionResult.failed, .timedOut, .cancelled, .outputOverflow, .notLaunched] {
        let store = MemoryJournal(); let transport = FakeTransport(store: store, result: result)
        let coordinator = try coordinator(store: store, transport: transport)
        _ = try await configure(coordinator)
        let receipt = try await coordinator.request80Percent()
        #expect(receipt.phase == .outcomeUnknown)
        #expect(receipt.lastError == .manualRecoveryRequired)
        #expect(!receipt.canRequest80)
    }
}

@Test func missingDuplicateAndChangedIdentityDoNotDispatch() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let coordinator = try coordinator(store: store, transport: transport)
    _ = try await configure(coordinator)
    let original = try #require(await coordinator.status().shortcutUUID)
    await transport.setIdentities([])
    do { _ = try await coordinator.request80Percent(); Issue.record("Missing shortcut dispatched") }
    catch { #expect(error as? NativeLimitFailure == .shortcutMissing) }
    await transport.setIdentities([NativeShortcutIdentity(id: original, name: NativeLimitCoordinator.expectedShortcutName),
        NativeShortcutIdentity(id: UUID(), name: NativeLimitCoordinator.expectedShortcutName)])
    do { _ = try await coordinator.request80Percent(); Issue.record("Duplicate name dispatched") }
    catch { #expect(error as? NativeLimitFailure == .shortcutAmbiguous) }
    await transport.setIdentities([NativeShortcutIdentity(id: UUID(), name: NativeLimitCoordinator.expectedShortcutName)])
    do { _ = try await coordinator.discoverConfiguredShortcut(); Issue.record("Discovery accepted replacement identity") }
    catch { #expect(error as? NativeLimitFailure == .shortcutIdentityChanged) }
    do { _ = try await coordinator.request80Percent(); Issue.record("Replacement identity dispatched") }
    catch { #expect(error as? NativeLimitFailure == .shortcutIdentityChanged) }
    #expect(await transport.executions == 0)
    #expect(try store.load()?.phase == .ready)
}

@Test func exactPlatformAndKnownControllerChecksAreRequired() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    var platform = qualifiedPlatform(); platform.operatingSystemBuild = "different-build"
    let unqualified = try coordinator(store: store, transport: transport, platform: platform)
    do { _ = try await configure(unqualified); Issue.record("Unknown build enabled") }
    catch { #expect(error as? NativeLimitFailure == .unqualifiedTarget) }
    #expect(await transport.executions == 0)
    let preflight = Preflight()
    let eligible = try coordinator(store: store, transport: transport, preflight: preflight)
    await preflight.set(.unavailable)
    do { _ = try await configure(eligible); Issue.record("Unknown controller status accepted") }
    catch { #expect(error as? NativeLimitFailure == .preflightUnavailable) }
    await preflight.set(.clear)
    _ = try await configure(eligible)
    await preflight.set(.conflictingController)
    do { _ = try await eligible.request80Percent(); Issue.record("Known competing controller ignored") }
    catch { #expect(error as? NativeLimitFailure == .controllerConflict) }
    #expect(await transport.executions == 0)
}

@Test func reentrantApplyAndConfirmationAreBlockedDuringExecution() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store, holdExecution: true)
    let coordinator = try coordinator(store: store, transport: transport)
    _ = try await configure(coordinator)
    let task = Task { try await coordinator.request80Percent() }
    await transport.waitUntilExecution()
    #expect(await coordinator.status().phase == .requested)
    do { _ = try await coordinator.request80Percent(); Issue.record("Concurrent execution accepted") }
    catch { #expect(error as? NativeLimitFailure == .executionInProgress) }
    do { _ = try await coordinator.confirmRestored100(priorShortcutCompletedOrStopped: true); Issue.record("Restoration confirmation raced dispatch") }
    catch { #expect(error as? NativeLimitFailure == .executionInProgress) }
    await transport.finishExecution()
    #expect(try await task.value.phase == .acknowledgedUnverified)
    #expect(await transport.executions == 1)
}

@Test func acknowledgedRestartRequiresManualReconciliation() async throws {
    let store = MemoryJournal(); let transport = FakeTransport(store: store)
    let first = try coordinator(store: store, transport: transport)
    _ = try await configure(first); _ = try await first.request80Percent()
    let restored = try coordinator(store: store, transport: transport)
    #expect(await restored.status().phase == .outcomeUnknown)
    #expect(await restored.status().requiresManualRecovery)
    #expect(await transport.executions == 1)
    do {
        _ = try await restored.confirmRestored100(priorShortcutCompletedOrStopped: false)
        Issue.record("Prior shortcut completion declaration omitted during recovery")
    } catch { #expect(error as? NativeLimitFailure == .invalidConfirmation) }
    #expect(await restored.status().phase == .outcomeUnknown)
    #expect(await restored.status().canRequest80 == false)
    #expect(try store.load()?.priorShortcutCompletedOrStoppedAtUTC == nil)
    #expect(await transport.executions == 1)
    _ = try await restored.confirmRestored100(priorShortcutCompletedOrStopped: true)
    #expect(try store.load()?.priorShortcutCompletedOrStoppedAtUTC != nil)
    #expect(await restored.status().canRequest80)
}
