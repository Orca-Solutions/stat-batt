import Testing
import StatBattDomain
@testable import StatBattAdapterLabCommand

@Test func labRejectsAllUnrecognizedArguments() {
    #expect(LabMode.parse([]) == .inspect)
    #expect(LabMode.parse(["--test-restore"]) == .testRestore)
    for args in [["--test-restore", "--test-restore"], ["CHIE", "08"], ["--write"], ["--test-restore", "00"], ["--inspect"]] {
        #expect(LabMode.parse(args) == nil)
    }
}
@Test func restoreAdmissionRequiresFreshSafeExternalPower() {
    let now: UInt64 = 10_000_000_000
    var s = BatterySnapshot(bootID: .init(), sampledAtContinuousNanoseconds: now)
    s.batteryPresent = Metric(value: true, quality: .observed, sampledAtContinuousNanoseconds: now, source: "fixture")
    s.adapterAttached = Metric(value: true, quality: .observed, sampledAtContinuousNanoseconds: now, source: "fixture")
    s.supplyingSource = Metric(value: .adapter, quality: .observed, sampledAtContinuousNanoseconds: now, source: "fixture")
    s.stateOfChargePercent = Metric(value: 50, quality: .observed, sampledAtContinuousNanoseconds: now, source: "fixture")
    s.thermalPressure = Metric(value: .nominal, quality: .observed, sampledAtContinuousNanoseconds: now, source: "fixture")
    #expect(LabAdmission.rejection(snapshot: s, now: now) == nil)
    #expect(LabAdmission.rejection(snapshot: s, now: now + 2_000_000_001) != nil)
    #expect(LabAdmission.rejection(snapshot: s, now: now - 1) != nil)
    s.stateOfChargePercent.value = 49.9
    #expect(LabAdmission.rejection(snapshot: s, now: now) != nil)
    s.stateOfChargePercent.value = 75
    s.thermalPressure.value = .fair
    #expect(LabAdmission.rejection(snapshot: s, now: now) != nil)
    s.thermalPressure.value = .nominal
    s.supplyingSource.value = .battery
    #expect(LabAdmission.rejection(snapshot: s, now: now) != nil)
}

@Test func labRequiresEveryExactPlatformField() {
    let target = PlatformFingerprint(model: "Mac16,13", architecture: "arm64",
        operatingSystemVersion: "27.0.1", operatingSystemBuild: "26A434",
        firmwareVersion: "mBoot-20457.1.29", providerVersion: "test")
    #expect(LabAdmission.targetMatches(target))
    for key in [\PlatformFingerprint.model, \.architecture, \.operatingSystemVersion,
                \.operatingSystemBuild, \.firmwareVersion] {
        var other = target
        other[keyPath: key] = "different"
        #expect(!LabAdmission.targetMatches(other))
    }
}

@Test func administratorModeRequiresExplicitFlagAndRootIdentity() {
    #expect(LabMode.parse(["--test-restore-admin"]) == .testRestoreAdmin)
    #expect(LabMode.parse(["--test-restore-admin", "--test-restore"]) == nil)
    for mode in [LabMode.inspect, .testRestore, .testRestoreAdmin] {
        for pair: (UInt32, UInt32) in [(0,0), (501,501), (0,501), (501,0)] {
            let expected = mode == .testRestoreAdmin ? pair == (0,0) : pair == (501,501)
            #expect(LabAdmission.identityAllowed(mode: mode, realUID: pair.0, effectiveUID: pair.1) == expected)
        }
    }
}

@Test func disconnectPreparationCannotBeEnabledByArguments() {
    #expect(!LabMode.disconnectTrialEnabled)
    #expect(LabMode.parse(["--trial-disconnect-worker"]) == .trialDisconnect)
    #expect(LabMode.parse(["--guardian-restore"]) == .guardianRestore)
    #expect(LabMode.parse(["--trial-disconnect-worker", "3"]) == nil)
    for mode in [LabMode.trialDisconnect, .guardianRestore] {
        #expect(LabAdmission.identityAllowed(mode: mode, realUID: 0, effectiveUID: 0))
        #expect(!LabAdmission.identityAllowed(mode: mode, realUID: 501, effectiveUID: 501))
    }
}

@Test func restorationRequiresFreshObservedSourceAfterWrite() {
    let floor: UInt64 = 1_000_000_000
    var s = BatterySnapshot(bootID: .init())
    s.supplyingSource = Metric(value: .adapter, quality: .observed,
        sampledAtContinuousNanoseconds: floor, source: "fixture")
    #expect(LabAdmission.restorationSourceObserved(snapshot: s, now: floor, postWriteFloor: floor))
    #expect(!LabAdmission.restorationSourceObserved(snapshot: s, now: floor + 2_000_000_001, postWriteFloor: floor))
    #expect(!LabAdmission.restorationSourceObserved(snapshot: s, now: floor, postWriteFloor: floor + 1))
    s.supplyingSource.quality = .stale
    #expect(!LabAdmission.restorationSourceObserved(snapshot: s, now: floor, postWriteFloor: floor))
    s.supplyingSource.quality = .estimated
    #expect(!LabAdmission.restorationSourceObserved(snapshot: s, now: floor, postWriteFloor: floor))
    s.supplyingSource.quality = .observed
    s.supplyingSource.value = .battery
    #expect(!LabAdmission.restorationSourceObserved(snapshot: s, now: floor, postWriteFloor: floor))
}
