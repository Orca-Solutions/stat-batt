import Foundation
import Testing
import StatBattDomain
@testable import StatBattControlProtocol

private func nativeIntent() -> NativeIntent { NativeIntent(limitPercent: 80, agreedReturnLimitPercent: 100, baselineProvenance: .explicitUserConfirmation) }

@Test func nativeCannotRunBeforeVerifiedCustomRestoration() throws {
    var machine = NativeFenceContract()
    try machine.enableCustomPolicy()
    let version = StateVersion()
    let fence = try machine.begin(ownerUID: 501, version: version, commandID: UUID(), intent: nativeIntent())
    #expect(!machine.customPolicyEnabled)
    #expect(machine.fence?.phase == .restoringCustom)
    #expect(throws: WireFailure(.recoveryRequired)) { try machine.recordOwnerNativeOutcome(requesterUID: 501, fenceID: fence, generation: version.generation, settingObserved: true) }
    #expect(throws: WireFailure(.restoreFailed)) { try machine.customRestorationCompleted(verified: false) }
    #expect(throws: WireFailure(.nativeModeFenced)) { try machine.enableCustomPolicy() }
    try machine.customRestorationCompleted(verified: true)
    #expect(machine.fence?.phase == .readyForNative)
}

@Test func unknownNativeOutcomeSurvivesSerializationAndStopWithoutExpiry() throws {
    var machine = NativeFenceContract()
    let version = StateVersion()
    let fence = try machine.begin(ownerUID: 501, version: version, commandID: UUID(), intent: nativeIntent())
    try machine.customRestorationCompleted(verified: true)
    try machine.recordOwnerNativeOutcome(requesterUID: 501, fenceID: fence, generation: version.generation, settingObserved: false)
    var restored = try JSONDecoder().decode(NativeFenceContract.self, from: JSONEncoder().encode(machine))
    restored.stopCustom()
    #expect(restored.fence?.phase == .nativeOutcomeUnknown)
    #expect(!restored.customActivationAllowed)
    #expect(throws: WireFailure(.uninstallNotReady)) { try restored.checkUninstallReadiness() }
    #expect(throws: WireFailure(.nativeModeFenced)) { try restored.enableCustomPolicy() }
}

@Test func secondUserAndWrongGenerationCannotResolveFence() throws {
    var machine = NativeFenceContract()
    let version = StateVersion()
    let fence = try machine.begin(ownerUID: 501, version: version, commandID: UUID(), intent: nativeIntent())
    try machine.customRestorationCompleted(verified: true)
    #expect(throws: WireFailure(.ownerConflict)) { try machine.reconcileOwner(requesterUID: 502, fenceID: fence, generation: version.generation, evidence: .observedLimit(percent: 100)) }
    #expect(throws: WireFailure(.revisionConflict)) { try machine.reconcileOwner(requesterUID: 501, fenceID: fence, generation: UUID(), evidence: .observedLimit(percent: 100)) }
    #expect(machine.fence?.ownerUID == 501)
}

@Test func reconciliationRequiresAgreedSettingAndLeavesCustomDisabled() throws {
    var machine = NativeFenceContract()
    let version = StateVersion()
    let fence = try machine.begin(ownerUID: 501, version: version, commandID: UUID(), intent: nativeIntent())
    try machine.customRestorationCompleted(verified: true)
    try machine.recordOwnerNativeOutcome(requesterUID: 501, fenceID: fence, generation: version.generation, settingObserved: true)
    #expect(throws: WireFailure(.nativeLimitUnobservable)) {
        try machine.reconcileOwner(requesterUID: 501, fenceID: fence, generation: version.generation, evidence: .observedLimit(percent: 80))
    }
    #expect(throws: WireFailure(.nativeLimitUnobservable)) {
        try machine.reconcileOwner(requesterUID: 501, fenceID: fence, generation: version.generation, evidence: .visibleUserConfirmation(percent: 100, disclosureVersion: ""))
    }
    try machine.reconcileAfterAdminAuthorization(fenceID: fence, generation: version.generation, evidence: .visibleUserConfirmation(percent: 100, disclosureVersion: "v1"))
    #expect(machine.fence == nil)
    #expect(!machine.customPolicyEnabled)
    try machine.checkUninstallReadiness()
    try machine.enableCustomPolicy()
    #expect(machine.customPolicyEnabled)
}

@Test func corruptCheckpointCannotEnableCustomInsideNativeFence() throws {
    var machine = NativeFenceContract()
    _ = try machine.begin(ownerUID: 501, version: StateVersion(), commandID: UUID(), intent: nativeIntent())
    let encoded = try JSONEncoder().encode(machine)
    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    object["customPolicyEnabled"] = true
    #expect(throws: WireFailure(.recoveryRequired)) {
        try JSONDecoder().decode(NativeFenceContract.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
