import Foundation
import Testing
@testable import StatBattControlProtocol

@Test func thermalLeaseCannotBeStolenOrRevived() throws {
    let owner = UUID()
    var lease = try #require(ThermalSessionLease(owner: owner, uid: 501, now: 100))
    let heartbeatResult1 = lease.heartbeat(owner: UUID(), now: 200, activeUID: 501)
    #expect(!heartbeatResult1)
    let heartbeatResult2 = lease.heartbeat(owner: owner, now: 200, activeUID: 502)
    #expect(!heartbeatResult2)
    let heartbeatResult3 = lease.heartbeat(owner: owner, now: 99, activeUID: 501)
    #expect(!heartbeatResult3)
    #expect(lease.lastHeartbeat == 100)
    let heartbeatResult4 = lease.heartbeat(owner: owner, now: 200, activeUID: 501)
    #expect(heartbeatResult4)
    let heartbeatResult5 = lease.heartbeat(owner: owner, now: 200 + ThermalSessionLease.heartbeatLimit, activeUID: 501)
    #expect(!heartbeatResult5)
    #expect(!lease.isValid(now: 201, activeUID: nil))
}

@Test func thermalLeaseAbsoluteDeadlineNeverSlides() throws {
    let owner = UUID()
    var lease = try #require(ThermalSessionLease(owner: owner, uid: 501, now: 100, duration: 1000))
    let heartbeatResult6 = lease.heartbeat(owner: owner, now: 1099, activeUID: 501)
    #expect(heartbeatResult6)
    #expect(!lease.isValid(now: 1100, activeUID: 501))
    let heartbeatResult7 = lease.heartbeat(owner: owner, now: 1100, activeUID: 501)
    #expect(!heartbeatResult7)
    #expect(ThermalSessionLease(owner: owner, uid: 0, now: 0) == nil)
    #expect(ThermalSessionLease(owner: owner, uid: 501, now: UInt64.max) == nil)
    #expect(ThermalSessionLease(owner: owner, uid: 501, now: 0, duration: 3_600_000_000_001) == nil)
}
