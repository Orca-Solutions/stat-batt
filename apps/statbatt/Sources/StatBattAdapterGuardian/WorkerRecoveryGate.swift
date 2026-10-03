import StatBattAdapterBackend

enum WorkerLease: UInt64 { case shortTrial = 2, longTrial = 120 }

/// Closed fixed worker leases. No renewal or caller-selected duration.
struct WorkerRecoveryGate {
    let lease: WorkerLease
    init(lease: WorkerLease = .shortTrial) { self.lease = lease }
    private(set) var deadline: UInt64?
    private(set) var restorationStarted = false
    private(set) var cause: AdapterRecoveryCause?
    mutating func begin(now: UInt64, ownerGone: Bool, sleeping: Bool) -> Bool {
        let duration = lease.rawValue * 1_000_000_000
        guard deadline == nil, !ownerGone, !sleeping, now <= UInt64.max - duration else { return false }
        deadline = now + duration
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
