import Foundation
import Darwin
import StatBattDomain

/// Explicit user requests only. A receipt is historical; no getter, automatic restore or replay.
public actor NativeLimitCoordinator {
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
    /// Injected IO validates contracts; it cannot establish real hardware qualification.
    public init(platform: PlatformFingerprint, storage: any NativeLimitJournalStorage,
                transport: any NativeShortcutTransport, instanceLock: any NativeLimitInstanceLock,
                ownerUID: UInt32 = UInt32(geteuid()), clock: @escaping @Sendable () -> Date = { Date() },
                preflight: @escaping @Sendable () async -> NativePreflightResult) throws {
        self.platform = platform; self.storage = storage; self.transport = transport; self.instanceLock = instanceLock
        self.preflight = preflight; self.clock = clock
        try instanceLock.acquire()
        var loaded = try storage.load() ?? NativeLimitJournal(ownerUID: ownerUID)
        try loaded.validate(ownerUID: ownerUID)
        let mustPersist = loaded.needsMigration || loaded.phase == .requested
        if loaded.phase == .requested { loaded.phase = .outcomeUnknown }
        loaded.needsMigration = false
        if mustPersist {
            // Complete the migration/interruption fence durably before exposing request eligibility.
            do { try storage.save(loaded) } catch { throw NativeLimitFailure.journalUnavailable }
        }
        journal = loaded
        if journal.requiresManualRecovery { lastError = .manualRecoveryRequired }
        // A durable acknowledgement survives normal restart without dispatch or a current-state claim.
    }
    public func status() -> NativeLimitStatus {
        let qualifiedLimits = NativeTargetQualification.qualifiedLimits(platform)
        let trustedLimits = Set(NativeFixedLimit.allCases.filter { journal.trust(for: $0) != nil })
        let available = NativeTargetQualification.qualifies(platform) && journalHealthy && !busy && !journal.requiresManualRecovery
        return NativeLimitStatus(phase: journal.phase, lastError: lastError,
            shortcut80UUID: journal.trust80?.shortcutUUID, shortcut100UUID: journal.trust100?.shortcutUUID,
            operationID: journal.operationID, lastRequestedLimit: journal.requestedLimit, requestedAtUTC: journal.requestedAtUTC,
            lastObservedLimit: journal.observedLimit, confirmedAtUTC: journal.confirmedAtUTC,
            qualifiedTarget: NativeTargetQualification.qualifies(platform), qualifiedLimits: qualifiedLimits, trustedLimits: trustedLimits,
            journalHealthy: journalHealthy, requiresManualRecovery: journal.requiresManualRecovery,
            canRequest80: available && trustedLimits.contains(.eighty) && qualifiedLimits.contains(.eighty),
            canRequest100: available && trustedLimits.contains(.hundred) && qualifiedLimits.contains(.hundred),
            canRunSupervised100Qualification: available && trustedLimits.contains(.hundred) && Self.supervised100Build && journal.qualification100AttemptedAtUTC == nil,
            qualification100AttemptedAtUTC: journal.qualification100AttemptedAtUTC)
    }
    private static var supervised100Build: Bool {
        #if STATBATT_NATIVE_100_QUALIFICATION
        true
        #else
        false
        #endif
    }
    public func discoverConfiguredShortcut(for limit: NativeFixedLimit) async throws -> Bool {
        try ensureIdleAndHealthy()
        busy = true; defer { busy = false }
        do {
            let identities = try await transport.listShortcuts()
            let matches = identities.filter { $0.name == limit.expectedShortcutName }
            guard matches.count <= 1, Set(identities.map(\.id)).count == identities.count else { throw NativeLimitFailure.shortcutAmbiguous }
            if let trust = journal.trust(for: limit), let match = matches.first, match.id != trust.shortcutUUID {
                throw NativeLimitFailure.shortcutIdentityChanged
            }
            return matches.count == 1
        } catch { throw record(error) }
    }
    /// Non-actuating setup.100 trust can be recorded before qualification without enabling production100.
    public func configureTrustedShortcut(for limit: NativeFixedLimit,
                                         acknowledgement: NativeTrustAcknowledgement,
                                         confirmedOtherControllersStopped: Bool) async throws -> NativeLimitStatus {
        try ensureIdleAndHealthy()
        guard NativeTargetQualification.qualifies(platform) else { throw record(NativeLimitFailure.unqualifiedTarget) }
        guard !journal.requiresManualRecovery else { throw record(NativeLimitFailure.manualRecoveryRequired) }
        guard confirmedOtherControllersStopped else { throw record(NativeLimitFailure.controllersNotConfirmedStopped) }
        busy = true; defer { busy = false }
        do {
            try await checkPreflight()
            let selected = try uniqueExpectedShortcut(await transport.listShortcuts(), for: limit)
            if let trust = journal.trust(for: limit), trust.shortcutUUID != selected.id { throw NativeLimitFailure.shortcutIdentityChanged }
            let otherLimit: NativeFixedLimit = limit == .eighty ? .hundred : .eighty
            if journal.trust(for: otherLimit)?.shortcutUUID == selected.id { throw NativeLimitFailure.shortcutAmbiguous }
            try await checkPreflight()
            var next = journal
            // Preserve prior trust metadata when merely recording the same inspected identity again.
            let trust: NativeTrustRecord
            if let existing = next.trust(for: limit) { trust = existing } else {
                trust = NativeTrustRecord(limit: limit, shortcutUUID: selected.id,
                    expectedName: limit.expectedShortcutName, acknowledgement: acknowledgement, approvedAtUTC: try currentTime(),
                    confirmedBaselinePercent: nil, confirmedOtherControllersStopped: true, platform: platform)
            }
            if limit == .eighty { next.trust80 = trust } else { next.trust100 = trust }
            if next.phase == .notConfigured { next.phase = .ready }
            try persist(next); lastError = nil
            return statusAfterIdle()
        } catch { throw record(error) }
    }
    public func request(_ limit: NativeFixedLimit) async throws -> NativeLimitStatus {
        try await performRequest(limit, supervised100: false)
    }
    #if STATBATT_NATIVE_100_QUALIFICATION
    /// Separate, explicit one-use trial in the identified supervised candidate; never production qualification.
    public func requestSupervised100Qualification() async throws -> NativeLimitStatus {
        try await performRequest(.hundred, supervised100: true)
    }
    #endif
    private func performRequest(_ limit: NativeFixedLimit, supervised100: Bool) async throws -> NativeLimitStatus {
        try ensureIdleAndHealthy()
        guard NativeTargetQualification.qualifies(platform) else { throw record(NativeLimitFailure.unqualifiedTarget) }
        guard !journal.requiresManualRecovery else { throw record(NativeLimitFailure.manualRecoveryRequired) }
        if supervised100 {
            guard Self.supervised100Build, limit == .hundred else { throw record(NativeLimitFailure.unqualifiedTarget) }
            guard journal.qualification100AttemptedAtUTC == nil else { throw record(NativeLimitFailure.qualificationAlreadyAttempted) }
        } else {
            guard NativeTargetQualification.qualifiedLimits(platform).contains(limit) else { throw record(NativeLimitFailure.unqualifiedTarget) }
        }
        guard let trust = journal.trust(for: limit) else { throw record(NativeLimitFailure.trustNotApproved) }
        busy = true; defer { busy = false }
        do {
            try await checkPreflight()
            let selected = try uniqueExpectedShortcut(await transport.listShortcuts(), for: limit)
            guard selected.id == trust.shortcutUUID else { throw NativeLimitFailure.shortcutIdentityChanged }
            try await checkPreflight()
            var requested = journal
            requested.phase = .requested; requested.operationID = UUID(); requested.requestedLimit = limit
            requested.requestedAtUTC = try currentTime()
            requested.priorShortcutCompletedOrStoppedAtUTC = nil
            // Keep prior observations historical; a new request does not refresh them.
            if supervised100 { requested.qualification100AttemptedAtUTC = requested.requestedAtUTC }
            try persist(requested)
            lastError = nil
            let result = await transport.executeTrusted(TrustedNativeShortcut(id: selected.id, limit: limit))
            var completed = journal
            completed.phase = result == .acknowledged ? .acknowledgedUnverified : .outcomeUnknown
            try persist(completed)
            lastError = result == .acknowledged ? nil : .manualRecoveryRequired
            return statusAfterIdle()
        } catch { throw record(error) }
    }
    /// Optional historical visible observation. This cannot clear an unknown execution fence.
    public func confirmVisibleLimit(_ limit: NativeFixedLimit) throws -> NativeLimitStatus {
        try ensureIdleAndHealthy()
        guard journal.operationID != nil, journal.phase != .notConfigured else { throw record(NativeLimitFailure.invalidConfirmation) }
        var next = journal; next.observedLimit = limit; next.confirmedAtUTC = try currentTime()
        try persist(next)
        lastError = next.requiresManualRecovery ? .manualRecoveryRequired : nil
        return status()
    }
    /// Recovery requires visible owner reconciliation and library-finished/stopped declaration.
    public func reconcileVisibleLimit(_ limit: NativeFixedLimit, priorShortcutCompletedOrStopped: Bool) throws -> NativeLimitStatus {
        try ensureIdleAndHealthy()
        guard journal.trust80 != nil || journal.trust100 != nil else { throw record(NativeLimitFailure.trustNotApproved) }
        guard priorShortcutCompletedOrStopped else { throw record(NativeLimitFailure.invalidConfirmation) }
        var next = journal; next.phase = .ownerReconciled; next.observedLimit = limit
        next.confirmedAtUTC = try currentTime(); next.priorShortcutCompletedOrStoppedAtUTC = next.confirmedAtUTC
        try persist(next); lastError = nil
        return status()
    }
    public func forgetSetup() throws -> NativeLimitStatus {
        try ensureIdleAndHealthy()
        guard !journal.requiresManualRecovery else { throw record(NativeLimitFailure.manualRecoveryRequired) }
        var next = NativeLimitJournal(ownerUID: journal.ownerUID)
        // Trust revocation must not replenish a consumed supervised trial.
        next.qualification100AttemptedAtUTC = journal.qualification100AttemptedAtUTC
        try persist(next); lastError = nil
        return status()
    }
    private func statusAfterIdle() -> NativeLimitStatus { busy = false; return status() }
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
    private func uniqueExpectedShortcut(_ list: [NativeShortcutIdentity], for limit: NativeFixedLimit) throws -> NativeShortcutIdentity {
        let matches = list.filter { $0.name == limit.expectedShortcutName }
        guard !matches.isEmpty else { throw NativeLimitFailure.shortcutMissing }
        guard matches.count == 1, Set(list.map(\.id)).count == list.count else { throw NativeLimitFailure.shortcutAmbiguous }
        return matches[0]
    }
    private func persist(_ next: NativeLimitJournal) throws {
        do {
            try next.validate(ownerUID: journal.ownerUID); try storage.save(next); journal = next
        } catch {
            journalHealthy = false; lastError = .journalUnavailable
            throw NativeLimitFailure.journalUnavailable
        }
    }
    private func record(_ error: Error) -> NativeLimitFailure {
        let failure = error as? NativeLimitFailure ?? .transportUnavailable
        lastError = failure; return failure
    }
}
