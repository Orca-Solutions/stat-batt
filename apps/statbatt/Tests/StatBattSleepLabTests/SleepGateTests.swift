import Testing
@testable import StatBattSleepLab

@Test func sleepGateDoesNotTreatEarlyReplyAsRestoration() {
    var gate = SleepGate()
    #expect(gate.poll(now: 0, reply: 0x52, ownerGone: false) == .wait)
    gate.willSleep(now: 1)
    #expect(gate.poll(now: 2, reply: nil, ownerGone: false) == .wait)
    #expect(gate.poll(now: 3, reply: 0x52, ownerGone: false) == .allowVerified)
}
@Test func sleepGateTimeoutAndOwnerLossNeverClaimRestoration() {
    for lost in [false, true] {
        var gate = SleepGate(); gate.willSleep(now: 0); gate.willSleep(now: 7)
        #expect(gate.poll(now: lost ? 1 : 8, reply: 0x52, ownerGone: lost) == .allowUnknown)
        #expect(gate.poll(now: 9, reply: 0x52, ownerGone: false) == .allowUnknown)
    }
}
