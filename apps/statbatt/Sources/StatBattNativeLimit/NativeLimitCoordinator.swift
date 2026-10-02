import Foundation
import Darwin
import StatBattDomain

/// User-level persistent native-limit coordinator. No helper, automatic expiry, automatic restore,
/// arbitrary target or content-integrity claim. Every mutating delivery requires approved setup.
public actor NativeLimitCoordinator {
    public static let expectedShortcutName = "StatBatt — Apple Limit 80"
    private let platform: PlatformFingerprint
    private let storage: any NativeLimitJournalStorage
    private let transport: any NativeShortcutTransport
    private let instanceLock: any NativeLimitInstanceLock
    private let preflight: @Sendable () async -> NativePreflightResult
    private let clock: @Sendable () -> Date
    private var journal: NativeLimitJournal
    private var lastError: NativeLimitFailure?
    private var busy = false
    private var journalHealthy = true

    public init(platform: PlatformFingerprint, storageDirectory: URL,
                preflight: @escaping @Sendable () async -> NativePreflightResult) throws {
        let storage = try FileNativeLimitJournal(directory: storageDirectory)
        let lock = try FileNativeLimitInstanceLock(directory: storageDirectory)
        try self.init(platform: platform, storage: storage, transport: ShortcutsProcessTransport(), instanceLock: lock, preflight: preflight)
    }

    /// Injected IO is for contract tests; the app uses the fixed production initializer above.
    public init(platform: PlatformFingerprint, storage: any NativeLimitJournalStorage,
                transport: any NativeShortcutTransport, instanceLock: any NativeLimitInstanceLock,
                ownerUID: UInt32 = UInt32(geteuid()), clock: @escaping @Sendable () -> Date = { Date() },
                preflight: @escaping @Sendable () async -> NativePreflightResult) throws {
        self.platform = platform; self.storage = storage; self.transport = transport; self.instanceLock = instanceLock
        self.preflight = preflight; self.clock = clock
        try instanceLock.acquire()
        let loaded = try storage.load() ?? NativeLimitJournal(ownerUID: ownerUID)
        try loaded.validate(ownerUID: ownerUID)
        journal = loaded
        if [.requested, .acknowledgedUnverified, .outcomeUnknown].contains(journal.phase) {
            journal.phase = .outcomeUnknown
            lastError = .manualRecoveryRequired
            // Loaded pending work is never automatically dispatched or retried.
            do { try storage.save(journal) } catch { throw NativeLimitFailure.journalUnavailable }
        } else if journal.phase == .manuallyConfirmed80 {
            lastError = .manualRecoveryRequired
        }
    }

    public func status() -> NativeLimitStatus {
        let qualified = NativeTargetQualification.qualifies(platform)
        let unresolved = [.requested, .acknowledgedUnverified, .outcomeUnknown, .manuallyConfirmed80].contains(journal.phase)
        return NativeLimitStatus(phase: journal.phase, lastError: lastError, shortcutUUID: journal.trust?.shortcutUUID,
            baselinePercent: journal.trust?.confirmedBaselinePercent, operationID: journal.operationID,
            trustApprovedAtUTC: journal.trust?.approvedAtUTC, qualifiedTarget: qualified,
            journalHealthy: journalHealthy,
            requiresManualRecovery: unresolved,
            canRequest80: qualified && journalHealthy && !busy && journal.trust != nil && !unresolved)
    }

    public func discoverConfiguredShortcut() async throws -> Bool {
        guard !busy else { throw NativeLimitFailure.executionInProgress }
        busy = true; defer { busy = false }
        do {
            let identities = try await transport.listShortcuts()
            let matches = identities.filter { $0.name == Self.expectedShortcutName }
            guard matches.count <= 1 else { throw NativeLimitFailure.shortcutAmbiguous }
            guard Set(identities.map(\.id)).count == identities.count else { throw NativeLimitFailure.shortcutAmbiguous }
            if let trust = journal.trust, let match = matches.first, match.id != trust.shortcutUUID {
                throw NativeLimitFailure.shortcutIdentityChanged
            }
            return matches.count == 1
        } catch { throw record(error) }
    }

    public func configureTrusted80Shortcut(acknowledgement: NativeTrustAcknowledgement,
                                           confirmedBaselinePercent: Double,
                                           confirmedOtherControllersStopped: Bool) async throws -> NativeLimitStatus {
        try ensureIdleAndHealthy()
        guard NativeTargetQualification.qualifies(platform) else { throw record(NativeLimitFailure.unqualifiedTarget) }
        guard !status().requiresManualRecovery else { throw record(NativeLimitFailure.manualRecoveryRequired) }
        guard confirmedBaselinePercent == 100 else { throw record(NativeLimitFailure.invalidConfirmation) }
        guard confirmedOtherControllersStopped else { throw record(NativeLimitFailure.controllersNotConfirmedStopped) }
        busy = true; defer { busy = false }
        do {
            try await checkPreflight()
            let selected = try uniqueExpectedShortcut(await transport.listShortcuts())
            try await checkPreflight()
            let now = try currentTime()
            var next = NativeLimitJournal(ownerUID: journal.ownerUID)
            next.trust = NativeTrustRecord(shortcutUUID: selected.id, expectedName: Self.expectedShortcutName,
                acknowledgement: acknowledgement, approvedAtUTC: now, confirmedBaselinePercent: 100,
                confirmedOtherControllersStopped: true, platform: platform)
            next.phase = .ready
            try persist(next)
            lastError = nil
            return statusAfterIdle()
        } catch { throw record(error) }
    }

    public func request80Percent() async throws -> NativeLimitStatus {
        try ensureIdleAndHealthy()
        guard NativeTargetQualification.qualifies(platform) else { throw record(NativeLimitFailure.unqualifiedTarget) }
        guard !status().requiresManualRecovery else { throw record(NativeLimitFailure.manualRecoveryRequired) }
        guard let trust = journal.trust else { throw record(NativeLimitFailure.trustNotApproved) }
        busy = true; defer { busy = false }
        do {
            try await checkPreflight()
            let selected = try uniqueExpectedShortcut(await transport.listShortcuts())
            guard selected.id == trust.shortcutUUID else { throw NativeLimitFailure.shortcutIdentityChanged }
            try await checkPreflight()
            var requested = journal
            requested.phase = .requested; requested.operationID = UUID()
            requested.requestedAtUTC = try currentTime(); requested.confirmedAtUTC = nil
            requested.priorShortcutCompletedOrStoppedAtUTC = nil
            // Durably flush the complete intent before crossing the hardware execution boundary.
            try persist(requested)
            lastError = nil
            let result = await transport.executeTrusted80(TrustedNative80Shortcut(id: selected.id))
            var completed = journal
            completed.phase = result == .acknowledged ? .acknowledgedUnverified : .outcomeUnknown
            try persist(completed)
            lastError = result == .acknowledged ? nil : .manualRecoveryRequired
            return statusAfterIdle()
        } catch { throw record(error) }
    }

    /// Explicit visible user confirmation only. Exit status never invokes this transition.
    public func confirmVisibleLimit80() throws -> NativeLimitStatus {
        try ensureIdleAndHealthy()
        guard [.acknowledgedUnverified, .outcomeUnknown, .manuallyConfirmed80].contains(journal.phase) else {
            throw record(NativeLimitFailure.invalidConfirmation)
        }
        var next = journal; next.phase = .manuallyConfirmed80; next.confirmedAtUTC = try currentTime()
        try persist(next); lastError = nil
        return status()
    }

    /// The user restores and verifies100% in Apple's UI; StatBatt sends no restoration command.
    public func confirmRestored100(priorShortcutCompletedOrStopped: Bool) throws -> NativeLimitStatus {
        try ensureIdleAndHealthy()
        guard journal.trust != nil else { throw record(NativeLimitFailure.trustNotApproved) }
        guard priorShortcutCompletedOrStopped else { throw record(NativeLimitFailure.invalidConfirmation) }
        var next = journal; next.phase = .restoredUserConfirmed100; next.confirmedAtUTC = try currentTime()
        next.priorShortcutCompletedOrStoppedAtUTC = next.confirmedAtUTC
        try persist(next); lastError = nil
        return status()
    }

    public func forgetSetup() throws -> NativeLimitStatus {
        try ensureIdleAndHealthy()
        guard !status().requiresManualRecovery else { throw record(NativeLimitFailure.manualRecoveryRequired) }
        try persist(NativeLimitJournal(ownerUID: journal.ownerUID)); lastError = nil
        return status()
    }

    private func statusAfterIdle() -> NativeLimitStatus {
        // Construct the final receipt after operation completion; defer still owns the busy fence.
        busy = false
        return status()
    }
    private func ensureIdleAndHealthy() throws {
        guard !busy else { throw NativeLimitFailure.executionInProgress }
        guard journalHealthy else { throw NativeLimitFailure.journalUnavailable }
    }
    private func currentTime() throws -> Date {
        let now = clock()
        guard now.timeIntervalSinceReferenceDate.isFinite else { throw NativeLimitFailure.journalUnavailable }
        return now
    }
    private func checkPreflight() async throws {
        switch await preflight() {
        case .clear: break
        case .conflictingController: throw NativeLimitFailure.controllerConflict
        case .unavailable: throw NativeLimitFailure.preflightUnavailable
        }
    }
    private func uniqueExpectedShortcut(_ list: [NativeShortcutIdentity]) throws -> NativeShortcutIdentity {
        let matches = list.filter { $0.name == Self.expectedShortcutName }
        guard !matches.isEmpty else { throw NativeLimitFailure.shortcutMissing }
        guard matches.count == 1, Set(list.map(\.id)).count == list.count else { throw NativeLimitFailure.shortcutAmbiguous }
        return matches[0]
    }
    private func persist(_ next: NativeLimitJournal) throws {
        do {
            try next.validate(ownerUID: journal.ownerUID)
            try storage.save(next)
            journal = next
        } catch {
            journalHealthy = false; lastError = .journalUnavailable
            throw NativeLimitFailure.journalUnavailable
        }
    }
    private func record(_ error: Error) -> NativeLimitFailure {
        let failure = error as? NativeLimitFailure ?? .transportUnavailable
        lastError = failure
        return failure
    }
}
