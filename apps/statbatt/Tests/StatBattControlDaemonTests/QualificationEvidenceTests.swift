import Foundation
import Testing
import StatBattControlProtocol
@testable import StatBattControlDaemon

@Test func oneShotQualificationDoesNotEnableAutomaticPolicy() {
    #expect(ThermalAutomaticQualification.current == nil)
}

@Test func qualificationRequiresFreshPhysicalTransitionAndExactOwnership() {
    let operation = UUID(), boot = UUID()
    func observation(_ source: Bool, _ time: UInt64, owner: UUID? = nil) -> ThermalInhibitionObservation {
        .init(bootID: boot, operationID: owner ?? operation, inhibited: true, batterySupplyingPower: source, observedAt: time)
    }
    #expect(!ThermalRuntime.qualifiesObservation(observation(false, 11), operation: operation, boot: boot, floor: 10, now: 12))
    #expect(!ThermalRuntime.qualifiesObservation(observation(true, 9), operation: operation, boot: boot, floor: 10, now: 12))
    #expect(!ThermalRuntime.qualifiesObservation(observation(true, 13), operation: operation, boot: boot, floor: 10, now: 12))
    #expect(!ThermalRuntime.qualifiesObservation(observation(true, 11, owner: UUID()), operation: operation, boot: boot, floor: 10, now: 12))
    #expect(ThermalRuntime.qualifiesObservation(observation(true, 11), operation: operation, boot: boot, floor: 10, now: 12))
}
