/// Pure coordination only. Deadline is a host-time bound, never a promise about firmware.
struct SleepGate {
    enum Decision: Equatable { case wait, allowVerified, allowUnknown }
    private(set) var deadline: Double?
    private(set) var decision: Decision = .wait
    mutating func willSleep(now: Double) {
        // Never extend a pending acknowledgment deadline for a duplicate event.
        if deadline == nil { deadline = now + 8 }
    }
    mutating func poll(now: Double, reply: UInt8?, ownerGone: Bool) -> Decision {
        guard deadline != nil else { return .wait }
        if decision != .wait { return decision }
        if ownerGone || now >= deadline! { decision = .allowUnknown }
        else if reply == 0x52 { decision = .allowVerified }
        else if reply != nil { decision = .allowUnknown }
        return decision
    }
}
