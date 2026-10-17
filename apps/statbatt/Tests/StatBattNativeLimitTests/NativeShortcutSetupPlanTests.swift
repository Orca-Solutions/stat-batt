import Testing
import StatBattNativeLimit

private func plan(discovered: Set<NativeFixedLimit> = [], missing: Set<NativeFixedLimit> = [],
                  bundled: Set<NativeFixedLimit> = [.eighty, .hundred], qualified: Bool = true,
                  clear: Bool = true, recovery: Bool = false, busy: Bool = false) -> NativeShortcutSetupPlan {
    NativeShortcutSetupPlan(discovered: discovered, missing: missing, bundled: bundled,
        deviceQualified: qualified, controllerClear: clear, recoveryRequired: recovery, busy: busy)
}

@Test func setupImportsMissingTargetsInOrderAndNeverDuplicatesExistingEntries() {
    #expect(plan(missing: [.eighty, .hundred]).nextImport == .eighty)
    #expect(plan(discovered: [.eighty], missing: [.hundred]).nextImport == .hundred)
    let completed = plan(discovered: [.eighty, .hundred])
    #expect(completed.nextImport == nil && completed.canEnable)
    #expect(plan(discovered: [.eighty], missing: [.eighty]).nextImport == nil)
}

@Test func ambiguousDiscoveryAndMissingBundleDoNotOfferUnusableImport() {
    #expect(plan().nextImport == nil) // Unknown or failed discovery is not absence.
    #expect(plan(missing: [.eighty], bundled: []).nextImport == nil)
    #expect(plan(missing: [.eighty], bundled: []).unavailableBundledImports == [.eighty])
    #expect(plan(missing: [.eighty], busy: true).unavailableBundledImports.isEmpty)
    #expect(plan(missing: [.eighty], qualified: false).unavailableBundledImports.isEmpty)
    #expect(!plan(discovered: [.eighty]).canEnable)
}

@Test func setupRespectsRecoveryPlatformAndInFlightOperations() {
    for candidate in [plan(missing: [.eighty], qualified: false),
                      plan(missing: [.eighty], recovery: true),
                      plan(missing: [.eighty], busy: true)] {
        #expect(candidate.nextImport == nil && !candidate.canEnable)
    }
    #expect(!plan(discovered: [.eighty, .hundred], clear: false).canEnable)
}
