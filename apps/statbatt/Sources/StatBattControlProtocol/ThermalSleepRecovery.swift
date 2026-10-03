import Foundation

/// Implementations MUST bound their I/O. A timeout that leaves a live writer is
/// not `true`: restore may begin only after the writer is actually reaped.
public protocol ThermalSleepRecoveryBackend: Sendable {
    func stopAndReapWriter() async -> Bool
    /// Returns current-boot continuous time after an acknowledged restore, nil if unknown.
    func restoreAdapter() async -> UInt64?
    func observeRestoration() async -> ThermalRestorationObservation?
}

public struct ThermalRestorationObservation: Sendable {
    public let bootID: UUID
    public let keyIsZero: Bool
    public let keyObservedAt: UInt64
    public let adapterSupplyingPower: Bool
    public let sourceObservedAt: UInt64
    public let now: UInt64
    public init(bootID: UUID, keyIsZero: Bool, keyObservedAt: UInt64,
                adapterSupplyingPower: Bool, sourceObservedAt: UInt64, now: UInt64) {
        self.bootID = bootID; self.keyIsZero = keyIsZero; self.keyObservedAt = keyObservedAt
        self.adapterSupplyingPower = adapterSupplyingPower; self.sourceObservedAt = sourceObservedAt; self.now = now
    }
}

public enum ThermalSleepRecoveryResult: Equatable, Sendable {
    case verified
    case noOwnedOperation, writerNotReaped, restoreUnknown, observationUnavailable, verificationOrPersistenceFailed
}

/// Dormant sequencing substrate. Never acknowledges OS sleep itself and cannot
/// veto forced sleep. Its owner must route every inhibit authorization through
/// this gate and still enforce normal policy/capability checks.
public actor ThermalSleepRecovery {
    private let ledger: ThermalOwnershipLedger
    private let backend: any ThermalSleepRecoveryBackend
    private let clock: @Sendable () -> UInt64
    private(set) var waitingCallerCount = 0
    private var flight: (id: UUID, operationID: UUID, task: Task<ThermalSleepRecoveryResult, Never>)?
    private var generation: UInt64 = 0
    private var asleep = false
    private var authorized = false
    private var recoveryVerified = true

    public init(ledger: ThermalOwnershipLedger, backend: any ThermalSleepRecoveryBackend, clock: @escaping @Sendable () -> UInt64) {
        self.ledger = ledger; self.backend = backend; self.clock = clock
    }
    public var mayInhibit: Bool { authorized && !asleep && flight == nil && recoveryVerified }

    /// A separate explicit authorization is required after wake; late completion
    /// of a pre-sleep request cannot supply it.
    public func authorizeSession() async -> Bool {
        let epoch = generation
        guard !asleep, flight == nil, recoveryVerified else { return false }
        let blocked = await ledger.blocksInhibitionAndUninstall
        guard epoch == generation, !asleep, flight == nil, recoveryVerified, !blocked else { return false }
        authorized = true
        return true
    }
    public func woke() {
        generation &+= 1
        asleep = false
        authorized = false
        // An in-flight recovery remains a barrier; wake never cancels restoration.
    }

    public func prepareForSleep(operationID: UUID, now: UInt64) async -> ThermalSleepRecoveryResult {
        waitingCallerCount += 1
        defer { waitingCallerCount -= 1 }
        generation &+= 1
        authorized = false
        asleep = true
        if let existing = flight {
            guard existing.operationID == operationID else { return .noOwnedOperation }
            return await existing.task.value
        }
        recoveryVerified = false
        let id = UUID()
        let ledger = ledger, backend = backend, clock = clock
        let task = Task<ThermalSleepRecoveryResult, Never> {
            guard let owned = await ledger.snapshot, owned.operationID == operationID, owned.unresolved else { return .noOwnedOperation }
            guard await backend.stopAndReapWriter() else { return .writerNotReaped }
            // Persistence trouble cannot prevent emergency hardware restoration.
            do { try await ledger.recordRestorationIntent(operationID: operationID, now: now) }
            catch ThermalJournalError.unavailable { /* Known owned intent: restore despite storage error. */ }
            catch { return .noOwnedOperation }
            guard let restoredAt = await backend.restoreAdapter() else { return .restoreUnknown }
            let postRestoreFloor = max(restoredAt, clock())
            guard let observation = await backend.observeRestoration() else { return .observationUnavailable }
            let validationNow = clock()
            guard observation.now <= validationNow, restoredAt >= now, observation.keyObservedAt >= postRestoreFloor,
                  observation.sourceObservedAt >= postRestoreFloor else { return .verificationOrPersistenceFailed }
            do {
                try await ledger.confirmRestored(operationID: operationID,
                    observationBootID: observation.bootID, keyIsZero: observation.keyIsZero,
                    keyObservedAt: observation.keyObservedAt, adapterSupplyingPower: observation.adapterSupplyingPower,
                    sourceObservedAt: observation.sourceObservedAt, now: validationNow)
                return .verified
            } catch { return .verificationOrPersistenceFailed }
        }
        flight = (id, operationID, task)
        let result = await task.value
        if flight?.id == id {
            flight = nil
            recoveryVerified = result == .verified
        }
        // No completion, including one arriving after wake, authorizes inhibition.
        return result
    }
}
