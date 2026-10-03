import AppKit
import Foundation
import Darwin
import CStatBattAdapterLab
import StatBattDomain
import StatBattTelemetry
import StatBattNativeLimit

enum LabMode: String, Codable {
    case inspect, testRestore, testRestoreAdmin, trialDisconnect, guardianRestore, guardianSleepHold
    static let disconnectTrialEnabled = false
    static func parse(_ arguments: [String]) -> LabMode? {
        if arguments.isEmpty { return .inspect }
        if arguments == ["--test-restore"] { return .testRestore }
        if arguments == ["--test-restore-admin"] { return .testRestoreAdmin }
        if arguments == ["--trial-disconnect-worker"] { return .trialDisconnect }
        if arguments == ["--guardian-restore"] { return .guardianRestore }
        return arguments == ["--guardian-sleep-hold"] ? .guardianSleepHold : nil
    }
}

enum LabAdmission {
    static func identityAllowed(mode: LabMode, realUID: UInt32, effectiveUID: UInt32) -> Bool {
        [.testRestoreAdmin, .trialDisconnect, .guardianRestore, .guardianSleepHold].contains(mode) ? realUID == 0 && effectiveUID == 0 : realUID != 0 && effectiveUID != 0
    }
    static func targetMatches(_ p: PlatformFingerprint) -> Bool {
        p.model == "Mac16,13" && p.architecture == "arm64" &&
        p.operatingSystemVersion == "27.0.1" && p.operatingSystemBuild == "26A434" &&
        p.firmwareVersion == "mBoot-20457.1.29"
    }
    static func restorationSourceObserved(snapshot s: BatterySnapshot, now: UInt64, postWriteFloor: UInt64) -> Bool {
        s.supplyingSource.quality == .observed && s.supplyingSource.value == .adapter &&
        s.supplyingSource.isFresh(at: now, maximumAgeSeconds: 2, minimumSampleNanoseconds: postWriteFloor)
    }
    static func rejection(snapshot s: BatterySnapshot, now: UInt64) -> String? {
        guard s.batteryPresent.isFresh(at: now, maximumAgeSeconds: 2), s.batteryPresent.value == true,
              s.adapterAttached.isFresh(at: now, maximumAgeSeconds: 2), s.adapterAttached.value == true,
              s.supplyingSource.isFresh(at: now, maximumAgeSeconds: 2), s.supplyingSource.value == .adapter else {
            return "freshExternalPowerRequired"
        }
        guard s.stateOfChargePercent.isFresh(at: now, maximumAgeSeconds: 2),
              let soc = s.stateOfChargePercent.value, soc.isFinite, (50...100).contains(soc) else {
            return "freshReserveAtLeast50Required"
        }
        guard s.thermalPressure.isFresh(at: now, maximumAgeSeconds: 2), s.thermalPressure.value == .nominal else {
            return "freshNominalThermalStateRequired"
        }
        return nil
    }
}

private struct Step: Codable {
    let attempted: Bool
    let transport: UInt32?
    let responseLength: UInt32?
    let smcResult: UInt8?
    let smcStatus: UInt8?
    init(_ s: SBAdapterStep) {
        attempted = s.attempted == 1
        transport = attempted ? s.transport : nil
        responseLength = attempted ? s.length : nil
        let responseValid = attempted && s.transport == 0 && s.length == 80
        smcResult = responseValid ? s.smc_result : nil
        smcStatus = responseValid ? s.smc_status : nil
    }
}
private struct Hardware: Codable {
    let outcome: UInt8
    let serviceOpen, clientOpen, clientClose, serviceClose: UInt32?
    let metadata, baseline, restore, readback: Step
    let size: UInt32
    let type: UInt32
    let attributes: UInt8
    let baselineHex, readbackHex: String?
    init(_ r: SBAdapterReport) {
        outcome = r.outcome
        serviceOpen = r.service_open_attempted == 1 ? r.service_open : nil
        clientOpen = r.client_open_attempted == 1 ? r.client_open : nil
        clientClose = r.client_close_attempted == 1 ? r.client_close : nil
        serviceClose = r.service_close_attempted == 1 ? r.service_close : nil
        metadata = Step(r.metadata); baseline = Step(r.baseline)
        restore = Step(r.restore); readback = Step(r.readback)
        size = r.data_size; type = r.data_type; attributes = r.attributes
        baselineHex = baseline.smcResult == 0 && baseline.smcStatus == 0 ? String(format: "%02x", r.baseline_value) : nil
        readbackHex = readback.smcResult == 0 && readback.smcStatus == 0 ? String(format: "%02x", r.readback_value) : nil
    }
}
private struct Observation: Codable {
    let source: PowerSource?
    let adapterAttached: Bool?
    let batteryPercent: Double?
    let thermal: ThermalPressure?
    init(_ s: BatterySnapshot) {
        source = s.supplyingSource.value; adapterAttached = s.adapterAttached.value
        batteryPercent = s.stateOfChargePercent.value; thermal = s.thermalPressure.value
    }
}
private struct Report: Encodable {
    let schemaVersion = 1
    let generatedAtUTC = Date()
    let mode: LabMode
    let platform: PlatformFingerprint
    var rejection: String?
    var before: Observation?
    var after: Observation?
    var hardware: Hardware?
    var result = "notRun"
    let limitations = [
        "Default inspection and enabled-state tests retain their original behavior. Disconnect/guardian modes are hard-disabled source-only preparation.",
        "Write acknowledgement and 00 readback do not prove restoration from an inhibited state, discharge capability, sleep safety, or emergency recovery.",
        "Known-controller checks are incomplete; the operator must stop all charging controllers and shortcut executions before the explicit test.",
        "Telemetry is sampled before and after, not atomically with the SMC call. No electrical transition is expected or established.",
        "This lab is not linked into the app and enables no app capability. Administrator mode requires its separate explicit flag; no automatic privilege retry, daemon, guardian or arbitrary key/value operation exists."
    ]
}

@main struct AdapterLabCommand {
    @MainActor static func main() async throws {
        guard let mode = LabMode.parse(Array(CommandLine.arguments.dropFirst())) else {
            FileHandle.standardError.write(Data("Usage: statbatt-adapter-lab [--test-restore | --test-restore-admin]. Default inspects only; explicit test writes only CHIE 00 after baseline 00. No other arguments accepted.\n".utf8))
            exit(64)
        }
        guard LabMode.disconnectTrialEnabled || (mode != .trialDisconnect && mode != .guardianRestore && mode != .guardianSleepHold) else {
            FileHandle.standardError.write(Data("Disconnect/guardian preparation is source-only; physical recovery remains unqualified.\n".utf8))
            exit(78)
        }
        let platform = PlatformProbe.readOnly()
        var report = Report(mode: mode, platform: platform)
        guard LabAdmission.identityAllowed(mode: mode, realUID: getuid(), effectiveUID: geteuid()) else {
            report.rejection = "executionIdentityDoesNotMatchExplicitMode"; try output(report); exit(1)
        }
        guard LabAdmission.targetMatches(platform) else {
            report.rejection = "exactTargetRequired"; try output(report); exit(1)
        }
        if mode == .guardianSleepHold {
            var assertion: UInt32 = 0
            guard sb_adapter_prevent_idle_sleep(&assertion) == 0 else { exit(1) }
            defer { _ = sb_adapter_release_idle_sleep(assertion) }
            FileHandle.standardOutput.write(Data("READY\n".utf8))
            _ = FileHandle.standardInput.readData(ofLength: 1)
            return
        }
        if mode != .inspect && mode != .guardianRestore, let reason = await controllerRejection() {
            report.rejection = reason; try output(report); exit(1)
        }
        let telemetry = PublicTelemetry()
        let before = telemetry.snapshot()
        report.before = Observation(before)
        if mode != .inspect && mode != .guardianRestore, let reason = LabAdmission.rejection(snapshot: before, now: SampleClock.nowNanoseconds()) {
            report.rejection = reason; try output(report); exit(1)
        }
        var assertion: UInt32 = 0
        if mode == .trialDisconnect {
            guard sb_adapter_prevent_idle_sleep(&assertion) == 0 else {
                report.rejection = "idleSleepAssertionFailed"; try output(report); exit(1)
            }
            // Guardian holds the only gate writer. EOF never authorizes inhibition.
            FileHandle.standardOutput.write(Data("READY\n".utf8))
            guard FileHandle.standardInput.readData(ofLength: 1) == Data([0x47]) else {
                _ = sb_adapter_release_idle_sleep(assertion); exit(1)
            }
            guard LabAdmission.rejection(snapshot: telemetry.snapshot(), now: SampleClock.nowNanoseconds()) == nil else {
                _ = sb_adapter_release_idle_sleep(assertion); exit(1)
            }
        }
        defer { if assertion != 0 { _ = sb_adapter_release_idle_sleep(assertion) } }
        let operation: UInt8 = mode == .guardianRestore ? 4 : mode == .trialDisconnect ? 3 : mode == .testRestoreAdmin ? 2 : mode == .testRestore ? 1 : 0
        let raw = sb_adapter_lab(operation)
        report.hardware = Hardware(raw)
        let postWriteFloor = SampleClock.nowNanoseconds()
        let after = telemetry.snapshot()
        report.after = Observation(after)
        if raw.outcome != 0 { report.result = "hardwareStepFailed" }
        else if mode == .inspect { report.result = "readOnlyInspectionCompleted" }
        else if mode == .trialDisconnect {
            let batteryObserved = after.supplyingSource.quality == .observed && after.supplyingSource.value == .battery &&
                after.supplyingSource.isFresh(at: SampleClock.nowNanoseconds(), maximumAgeSeconds: 2,
                    minimumSampleNanoseconds: postWriteFloor)
            report.result = batteryObserved ? "inhibitionReadbackAndBatterySourceObservedRestorationRequired"
                : "inhibitionReadbackOnlyElectricalEffectInconclusiveRestorationRequired"
        }
        else if mode == .guardianRestore {
            // Restoration must never be blocked by low reserve, battery source or hot state.
            report.result = LabAdmission.restorationSourceObserved(snapshot: after, now: SampleClock.nowNanoseconds(), postWriteFloor: postWriteFloor)
                ? "restoredZeroExternalSourceObserved" : "restoredZeroExternalSourceNotYetObserved"
        }
        else if LabAdmission.rejection(snapshot: after, now: SampleClock.nowNanoseconds()) != nil {
            report.result = "writeAndReadbackCompletedSourceConditionsChanged"
        } else { report.result = "zeroWriteAcknowledgedZeroReadbackExternalSourceObserved" }
        try output(report)
        if raw.outcome != 0 { exit(1) }
        if mode == .guardianRestore && report.result != "restoredZeroExternalSourceObserved" { exit(1) }
        if [.testRestore, .testRestoreAdmin].contains(mode) && report.result != "zeroWriteAcknowledgedZeroReadbackExternalSourceObserved" { exit(1) }
        if mode == .trialDisconnect {
            // Retain sleep assertion until guardian closes gate or sends stop; never writes twice.
            _ = FileHandle.standardInput.readData(ofLength: 1)
        }
    }

    @MainActor private static func controllerRejection() async -> String? {
        let knownApps = ["dev.statbatt.local", "de.appgineers.energiza", "me.mhaeuser.Battery-Toolkit", "cc.chlc.batt"]
        guard knownApps.allSatisfy({ NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }) else {
            return "closeKnownChargingAppsIncludingStatBatt"
        }
        // Conservative installed-helper checks supplement the existing bounded Energiza launchd probe.
        let labels = ["cc.chlc.batt", "homebrew.mxcl.batt", "me.mhaeuser.batterytoolkitd"]
        var consoleInfo = stat()
        guard stat("/dev/console", &consoleInfo) == 0, consoleInfo.st_uid != 0,
              let account = getpwuid(consoleInfo.st_uid), let home = account.pointee.pw_dir else {
            return "activeConsoleUserRequired"
        }
        let consoleHome = String(cString: home)
        let directories = ["/Library/LaunchDaemons", "/Library/LaunchAgents",
                           consoleHome + "/Library/LaunchAgents"]
        guard !directories.contains(where: { directory in
            labels.contains { FileManager.default.fileExists(atPath: directory + "/" + $0 + ".plist") }
        }) else { return "knownControllerInstalled" }
        guard await NativeKnownControllerProbe.check() == .clear else { return "knownControllerProbeNotClear" }
        // Recheck foreground apps after the asynchronous helper lookup.
        guard knownApps.allSatisfy({ NSRunningApplication.runningApplications(withBundleIdentifier: $0).isEmpty }) else {
            return "closeKnownChargingAppsIncludingStatBatt"
        }
        return nil
    }
    private static func output(_ report: Report) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        FileHandle.standardOutput.write(try encoder.encode(report))
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
