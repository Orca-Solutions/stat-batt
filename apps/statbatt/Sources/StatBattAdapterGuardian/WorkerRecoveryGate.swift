import StatBattAdapterBackend

/// Closed two-second worker lease. No renewal or caller-selected duration.
struct WorkerRecoveryGate {
    private(set) var deadline: UInt64?
    private(set) var restorationStarted = false
    private(set) var cause: AdapterRecoveryCause?
    mutating func begin(now: UInt64, ownerGone: Bool, sleeping: Bool) -> Bool {
        guard deadline == nil, !ownerGone, !sleeping, now <= UInt64.max - 2_000_000_000 else { return false }
        deadline = now + 2_000_000_000
        return true
    }
    mutating func shouldRestore(now: UInt64, ownerGone: Bool, sleeping: Bool, hardwareFailed: Bool = false) -> Bool {
        guard let deadline, !restorationStarted else { return false }
        guard now >= deadline || ownerGone || sleeping || hardwareFailed else { return false }
        restorationStarted = true
        cause = ownerGone ? .ownerEOF : sleeping ? .sleep : hardwareFailed ? .hardwareFailure : .deadline
        return true
    }
}
