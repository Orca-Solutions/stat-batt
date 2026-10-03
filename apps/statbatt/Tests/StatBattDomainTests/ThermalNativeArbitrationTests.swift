import Foundation
import Testing
@testable import StatBattDomain

private let arbitrationRequest = UUID()
private let arbitrationNow: UInt64 = 10_000_000_000
private func restored(_ boot: UUID, at time: UInt64 = arbitrationNow) -> ThermalNativeArbitration.Event {
    .restorationObserved(.init(keyIsZero: true, adapterSupplyingPower: true, observedAt: time, bootID: boot))
}

@Test func nativeDispatchWaitsForRestorationAndRevokesThermalSession() {
    let boot = UUID()
    var state = ThermalNativeArbitration(bootID: boot)
    state.handle(.authorizeThermalSession, now: arbitrationNow)
    #expect(state.mayInhibitAdapter)
    #expect(state.handle(.requestNative(arbitrationRequest), now: arbitrationNow) == .restoreOwnedAdapter)
    #expect(!state.mayInhibitAdapter)
    #expect(state.nativeState == .waitingForRestoration)
    #expect(state.handle(.requestNative(arbitrationRequest), now: arbitrationNow) == .none)
    state.handle(.authorizeThermalSession, now: arbitrationNow)
    #expect(!state.thermalAuthorized)
    #expect(state.handle(restored(boot), now: arbitrationNow) == .dispatchNative)
    #expect(state.handle(restored(boot), now: arbitrationNow) == .none)
    #expect(state.nativeState == .running)
    state.handle(.nativeCompleted(arbitrationRequest), now: arbitrationNow)
    #expect(!state.mayInhibitAdapter)
    state.handle(.authorizeThermalSession, now: arbitrationNow)
    #expect(state.mayInhibitAdapter)
}

@Test func restorationRequiresBothControlsFreshCurrentBootAndPostRequest() {
    let boot = UUID()
    let invalid: [ThermalNativeArbitration.RestoreObservation] = [
        .init(keyIsZero: false, adapterSupplyingPower: true, observedAt: arbitrationNow, bootID: boot),
        .init(keyIsZero: true, adapterSupplyingPower: false, observedAt: arbitrationNow, bootID: boot),
        .init(keyIsZero: true, adapterSupplyingPower: true, observedAt: arbitrationNow - 1, bootID: boot),
        .init(keyIsZero: true, adapterSupplyingPower: true, observedAt: arbitrationNow + 1, bootID: boot),
        .init(keyIsZero: true, adapterSupplyingPower: true, observedAt: arbitrationNow, bootID: UUID())
    ]
    for observation in invalid {
        var state = ThermalNativeArbitration(bootID: boot)
        state.handle(.requestNative(arbitrationRequest), now: arbitrationNow)
        #expect(state.handle(.restorationObserved(observation), now: arbitrationNow) == .none)
        #expect(state.nativeState == .waitingForRestoration)
    }
    var state = ThermalNativeArbitration(bootID: boot)
    state.handle(.requestNative(arbitrationRequest), now: arbitrationNow)
    #expect(state.handle(restored(boot), now: arbitrationNow + 2_000_000_001) == .none)
    #expect(state.handle(restored(boot), now: arbitrationNow + 2_000_000_000) == .dispatchNative)
}

@Test func unknownNativeOutcomeNeedsReconciliationAndNewAuthorization() {
    let boot = UUID()
    var state = ThermalNativeArbitration(bootID: boot)
    state.handle(.requestNative(arbitrationRequest), now: arbitrationNow)
    state.handle(restored(boot), now: arbitrationNow)
    state.handle(.nativeOutcomeUnknown(arbitrationRequest), now: arbitrationNow)
    state.handle(.nativeCompleted(arbitrationRequest), now: arbitrationNow) // Late completion is not reconciliation.
    state.handle(.authorizeThermalSession, now: arbitrationNow)
    #expect(state.nativeState == .outcomeUnknown && !state.mayInhibitAdapter)
    #expect(state.handle(.requestNative(arbitrationRequest), now: arbitrationNow) == .none)
    state.handle(.nativeReconciled(arbitrationRequest), now: arbitrationNow)
    #expect(!state.mayInhibitAdapter)
    state.handle(.authorizeThermalSession, now: arbitrationNow)
    #expect(state.mayInhibitAdapter)
}

@Test func lifecycleInterruptionsCancelPendingDispatchAndRequireFreshRecovery() {
    for event in [ThermalNativeArbitration.Event.sleep, .quit, .leaseExpired, .recoveryFault] {
        let boot = UUID()
        var state = ThermalNativeArbitration(bootID: boot)
        state.handle(.authorizeThermalSession, now: arbitrationNow)
        state.handle(.requestNative(arbitrationRequest), now: arbitrationNow)
        #expect(state.handle(event, now: arbitrationNow + 1) == .restoreOwnedAdapter)
        #expect(state.nativeState == .idle && state.recoveryRequired && !state.mayInhibitAdapter)
        #expect(state.handle(restored(boot), now: arbitrationNow + 1) == .none)
        state.handle(.authorizeThermalSession, now: arbitrationNow + 1)
        #expect(!state.mayInhibitAdapter)
        #expect(state.handle(restored(boot, at: arbitrationNow + 1), now: arbitrationNow + 1) == .none)
        #expect(!state.recoveryRequired && !state.mayInhibitAdapter)
        // The cancelled shortcut must not dispatch after delayed recovery.
        #expect(state.nativeState == .idle)
    }
}

@Test func interruptionOfRunningNativeRequiresRecoveryAndReconciliationIndependently() {
    let boot = UUID()
    var state = ThermalNativeArbitration(bootID: boot)
    state.handle(.requestNative(arbitrationRequest), now: arbitrationNow)
    state.handle(restored(boot), now: arbitrationNow)
    state.handle(.sleep, now: arbitrationNow + 1)
    state.handle(.nativeReconciled(arbitrationRequest), now: arbitrationNow + 1)
    state.handle(.authorizeThermalSession, now: arbitrationNow + 1)
    #expect(state.recoveryRequired && !state.mayInhibitAdapter)
    state.handle(restored(boot, at: arbitrationNow + 1), now: arbitrationNow + 1)
    #expect(!state.mayInhibitAdapter)
    state.handle(.authorizeThermalSession, now: arbitrationNow + 1)
    #expect(state.mayInhibitAdapter)
}

@Test func delayedNativeCompletionCannotCompleteAnotherRequest() {
    let boot = UUID()
    let first = UUID(), second = UUID()
    var state = ThermalNativeArbitration(bootID: boot)
    state.handle(.requestNative(first), now: arbitrationNow)
    state.handle(restored(boot), now: arbitrationNow)
    state.handle(.nativeCompleted(first), now: arbitrationNow)
    state.handle(.requestNative(second), now: arbitrationNow)
    state.handle(restored(boot), now: arbitrationNow)
    state.handle(.nativeCompleted(first), now: arbitrationNow)
    #expect(state.nativeState == .running && state.nativeRequestID == second)
    #expect(!state.mayInhibitAdapter)
}
