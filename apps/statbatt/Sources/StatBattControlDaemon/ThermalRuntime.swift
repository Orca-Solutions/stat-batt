import Foundation
import SystemConfiguration
import StatBattControlProtocol
import StatBattAdapterBackend
import StatBattTelemetry
import StatBattDomain

/// Owns recovery even when automatic policy admission is disabled. A successful
/// short adapter trial is not authority to advertise recurring temperature control.
actor ThermalRuntime {
    private let ledger: ThermalOwnershipLedger?
    private let nativeStorage: FileThermalOwnershipJournal?
    private let backend: LocalThermalAdapterBackend?
    private let controller: ThermalControlOrchestrator?
    private let policySession: ThermalPolicySession?
    private var policyLoop: Task<Void, Never>?
    private var leaseWatchdog: Task<Void, Never>?
    private var policyGeneration: UInt64 = 0
    private var policyPhase: ThermalControlPhase = .off
    private var policyMessage: String?
    private var policyTemperature: Metric<Double>?
    private var invalidatedConnections: Set<UUID> = []
    private var connectionHistoryFull = false
    private var uninstallRequested = false
    private var nativeOwner: UUID?
    private var nativeNeedsReconciliation = false
    private var qualificationOwner: UUID?
    private var qualificationConsumed = false
    private var qualificationResult: String?
    private var qualificationRunning = false
    private var recoveryCount = 0
    private var recovering: Bool { recoveryCount > 0 }

    init() {
        guard let text = PublicTelemetry.sysctlString("kern.bootsessionuuid"), let boot = UUID(uuidString: text),
              let storage = try? FileThermalOwnershipJournal(),
              let ledger = try? ThermalOwnershipLedger(storage: storage, bootID: boot) else {
            self.ledger = nil; nativeStorage = nil; backend = nil; controller = nil; policySession = nil; return
        }
        do { nativeOwner = try storage.loadNativeRequest(); nativeNeedsReconciliation = nativeOwner != nil }
        catch {
            self.ledger = nil; nativeStorage = nil; backend = nil; controller = nil; policySession = nil; return
        }
        nativeStorage = storage
        self.ledger = ledger
        // Only a reviewed source admission can select the longer fixed worker mode.
        // XPC clients never choose a guardian mode or extend its lease.
        let pauseMode: AdapterPauseMode = ThermalAutomaticQualification.current?.maximumPauseSeconds == 120 ? .oneHundredTwentySeconds : .twoSeconds
        let backend = LocalThermalAdapterBackend(ledger: ledger, bootID: boot, pauseMode: pauseMode)
        self.backend = backend
        let controller = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot,
                                              clock: { SampleClock.nowNanoseconds() })
        self.controller = controller
        policySession = ThermalPolicySession(controller: controller, clock: { SampleClock.nowNanoseconds() },
                                           activeUID: { Self.activeConsoleUser() })
    }

    static func activeConsoleUser() -> uid_t? {
        var uid: uid_t = 0, gid: gid_t = 0
        guard let name = SCDynamicStoreCopyConsoleUser(nil, &uid, &gid) as String?,
              name != "loginwindow", uid != 0 else { return nil }
        return uid
    }

    func perform(_ request: ThermalControlRequest, connection: UUID, uid: uid_t) async -> ThermalControlStatus {
        guard !connectionHistoryFull, !invalidatedConnections.contains(connection), Self.activeConsoleUser() == uid else {
            return .init(phase: .unavailable, controlAvailable: false, message: "Only the active signed-in user can control this service.")
        }
        switch request.action {
        case .qualifyAdapterOneShot:
            return await qualify(connection: connection, uid: uid)
        case .start:
            return await startPolicy(request.policy, connection: connection, uid: uid)
        case .prepareUninstall:
            guard nativeOwner == nil else {
                await recover()
                return await status(message: "Finish or reconcile the previous Apple shortcut before removing the service.")
            }
            uninstallRequested = true
            await recover()
            return await status()
        case .stop:
            await recover()
            return await status()
        case .prepareNative:
            guard !nativeNeedsReconciliation, nativeOwner == nil || nativeOwner == connection, let nativeStorage else {
                return await status(message: "A prior Apple limit request must be reconciled before continuing.")
            }
            // Reserve before the first suspension so no new thermal session can
            // enter between restoration and shortcut authorization.
            nativeOwner = connection
            do { try nativeStorage.saveNativeRequest(connection) }
            catch {
                await recover()
                return await status(message: "Could not save the Apple limit request fence. No shortcut is authorized.")
            }
            await recover()
            guard let ledger, !(await ledger.blocksInhibitionAndUninstall), !recovering,
                  nativeOwner == nil || nativeOwner == connection else {
                return await status(message: "Adapter recovery or another native request must finish first.")
            }
            return await status(nativeMayProceed: true, nativeConnection: connection, nativeUID: uid)
        case .reconcileNative:
            guard nativeNeedsReconciliation, let nativeStorage else {
                return await status(message: "No interrupted Apple shortcut needs reconciliation.")
            }
            // The signed UI asks the owner to check/stop the previous shortcut.
            // This records that explicit assertion; it never executes a setter.
            do { try nativeStorage.saveNativeRequest(nil); nativeOwner = nil; nativeNeedsReconciliation = false }
            catch { return await status(message: "Could not save the reconciliation. Charging controls remain blocked.") }
            return await status(message: "Previous shortcut confirmed finished or stopped. Temperature control remains off.")
        case .finishNative:
            if nativeOwner == connection {
                do { try nativeStorage?.saveNativeRequest(nil); nativeOwner = nil; nativeNeedsReconciliation = false }
                catch { return await status(message: "Could not save completion of the Apple limit request. Temperature control remains blocked.") }
            }
            return await status()
        case .heartbeat:
            _ = await policySession?.heartbeat(owner: connection, activeUID: Self.activeConsoleUser())
            return await status()
        case .status:
            return await status()
        }
    }

    func legacyRemovalSafe() async -> Bool {
        guard let ledger else { return false }
        return !(await ledger.blocksInhibitionAndUninstall) && !recovering && !qualificationRunning && nativeOwner == nil && !LocalThermalAdapterBackend.qualificationEnabled
    }

    func disconnected(_ connection: UUID) async {
        if invalidatedConnections.count < 4096 { invalidatedConnections.insert(connection) }
        else { connectionHistoryFull = true }
        if nativeOwner == connection { nativeNeedsReconciliation = true }
        // An unresolved native fence deliberately survives connection loss in this
        // process. Automatic policy is unavailable, including after restart.
        let policyOwner = await policySession?.owner
        if qualificationOwner == connection || policyOwner == connection { await recover() }
        await policySession?.disconnected(connection)
    }
    func recover(forSleep: Bool = false) async {
        recoveryCount += 1
        policyGeneration &+= 1
        policyLoop?.cancel(); policyLoop = nil
        leaseWatchdog?.cancel(); leaseWatchdog = nil
        policyPhase = .off
        qualificationOwner = nil
        _ = await policySession?.stop(forSleep: forSleep)
        recoveryCount -= 1
    }
    func woke() async { await controller?.woke() }

    private func startPolicy(_ policy: ThermalAdapterPolicy?, connection: UUID, uid: uid_t) async -> ThermalControlStatus {
        // Hardware and sensor admission are independent of a one-shot test gate.
        let platform = await MainActor.run { PlatformProbe.readOnly() }
        guard let admission = ThermalAutomaticQualification.current,
              admission.capabilities.supportsBoundedAdapterInhibition,
              admission.capabilities.platform == platform,
              let policy, policy.enabled, policy.isValid,
              policy.maximumPauseSeconds <= admission.maximumPauseSeconds,
              policy.reservePercent >= admission.minimumReservePercent,
              !uninstallRequested, !qualificationRunning, !recovering, nativeOwner == nil,
              let policySession else {
            return await status(message: "Automatic temperature control is awaiting end-to-end qualification. No adapter command was sent.")
        }
        let expected = policyGeneration
        guard await policySession.start(owner: connection, uid: uid, policy: policy) else {
            return await status(message: "A prior session or recovery must finish first.")
        }
        guard expected == policyGeneration, !invalidatedConnections.contains(connection), !connectionHistoryFull,
              Self.activeConsoleUser() == uid, !uninstallRequested, !recovering, nativeOwner == nil else {
            await recover()
            return await status(message: "Temperature control start was cancelled.")
        }
        policyGeneration &+= 1
        let runningGeneration = policyGeneration
        policyPhase = .watching; policyMessage = "Watching temperature. This session ends on quit, sleep, lost connection, or after one hour."
        policyLoop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, await self.evaluatePolicy(admission, generation: runningGeneration) else { return }
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
        leaseWatchdog = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                guard let self, await self.checkPolicyLease(generation: runningGeneration) else { return }
            }
        }
        return await status()
    }

    private func checkPolicyLease(generation: UInt64) async -> Bool {
        guard generation == policyGeneration, let policySession else { return false }
        let valid = await policySession.enforceLease(activeUID: Self.activeConsoleUser())
        guard generation == policyGeneration else { return false }
        if !valid { await recover(); policyMessage = "Temperature session ended; enable it again to resume." }
        return valid
    }

    private func evaluatePolicy(_ admission: ThermalAutomaticQualification, generation: UInt64) async -> Bool {
        guard generation == policyGeneration, let policySession, let backend, let ledger,
              let policy = await policySession.activePolicy else { return false }
        let inspection = await backend.freshInspection()
        let sample = await MainActor.run { PublicTelemetry().snapshot() }
        let now = SampleClock.nowNanoseconds()
        let record = await ledger.snapshot
        let blocked = await ledger.blocksInhibitionAndUninstall
        let owner = await policySession.owner
        guard generation == policyGeneration, owner != nil else { return false }
        var input = ThermalAdapterInput(policy: policy, capabilities: admission.capabilities,
            telemetry: sample, bootID: sample.bootID, now: now, sessionStartedAt: now, sessionDeadline: now)
        input.recoveryComplete = !blocked || (record?.unresolved == true && record?.sessionID == owner)
        input.nativeRequestInProgress = nativeOwner != nil
        input.observation = inspection?.key == 0 && inspection?.outcome == 0 ? .enabled : .unknown
        input.controlObservedAt = inspection?.sampledAt ?? 0
        input.estimatedTemperatureAdmission = admission.estimatedTemperature
        let result = await policySession.tick(input, activeUID: Self.activeConsoleUser())
        guard generation == policyGeneration else { return false }
        policyTemperature = sample.batteryTemperatureCelsius
        let active = await policySession.owner != nil
        guard generation == policyGeneration else { return false }
        if !active {
            await recover()
            policyMessage = result == .recoveryUnknown ? "Adapter recovery needs attention." : "Temperature session ended; enable it again to resume."
            return false
        }
        policyPhase = result == .inhibited || result == .holding ? .paused : .watching
        policyMessage = policyPhase == .paused ? "Using battery power until the lower temperature threshold or safety limit is reached." : "Watching temperature; adapter input is enabled."
        return true
    }

    private func qualify(connection: UUID, uid: uid_t) async -> ThermalControlStatus {
        let policyOwner = await policySession?.owner
        guard LocalThermalAdapterBackend.qualificationEnabled, LocalThermalAdapterBackend.recoveryEnabled,
              Self.activeConsoleUser() == uid, !invalidatedConnections.contains(connection), !connectionHistoryFull, !uninstallRequested, !qualificationConsumed,
              !qualificationRunning, !recovering, nativeOwner == nil, policyOwner == nil,
              let ledger, let backend, let controller else {
            return await status(message: "This build is not enabled for the one-shot adapter test.")
        }
        qualificationConsumed = true
        qualificationRunning = true
        qualificationOwner = connection
        defer { qualificationRunning = false; qualificationOwner = nil }
        guard !(await ledger.blocksInhibitionAndUninstall), qualificationOwner == connection,
              !recovering, nativeOwner == nil, Self.activeConsoleUser() == uid, !invalidatedConnections.contains(connection), !connectionHistoryFull, !uninstallRequested else {
            return await finishQualification("An existing recovery must complete before testing. No adapter command was sent.")
        }
        let operation: UUID
        do { operation = try await ledger.prepareInhibition(sessionID: connection, now: SampleClock.nowNanoseconds()) }
        catch { return await finishQualification("Could not save the test ownership record. No adapter command was sent.") }
        guard qualificationOwner == connection, !recovering, nativeOwner == nil, Self.activeConsoleUser() == uid, !invalidatedConnections.contains(connection), !connectionHistoryFull, !uninstallRequested else {
            _ = await controller.stop()
            return await finishQualification("Test cancelled before adapter inhibition.")
        }
        let intent = await ledger.snapshot
        guard qualificationOwner == connection, !recovering, nativeOwner == nil, Self.activeConsoleUser() == uid, !invalidatedConnections.contains(connection), !connectionHistoryFull, !uninstallRequested,
              let boot = intent?.originatingBootID, intent?.operationID == operation else {
            _ = await controller.stop()
            return await finishQualification("Test cancelled before adapter inhibition.")
        }
        let acknowledged = await backend.inhibitAdapterForOneShotQualification(operationID: operation)
        // Startup/signature verification is not part of the hardware interval.
        // This observation budget cannot renew the independent worker deadline.
        let start = SampleClock.nowNanoseconds()
        // The physical source can lag key readback. Collect repeated new reads,
        // never extend the independent guardian's nonrenewable two-second cut.
        var positive = false
        while acknowledged, qualificationOwner == connection, !recovering, nativeOwner == nil,
              Self.activeConsoleUser() == uid, !invalidatedConnections.contains(connection), !connectionHistoryFull, !uninstallRequested, SampleClock.nowNanoseconds() - start < 1_800_000_000 {
            let floor = SampleClock.nowNanoseconds()
            let observed = await backend.observeInhibition(operationID: operation)
            guard qualificationOwner == connection, !recovering, nativeOwner == nil,
                  Self.activeConsoleUser() == uid, !invalidatedConnections.contains(connection), !connectionHistoryFull, !uninstallRequested else { break }
            if observed == nil { break }
            positive = Self.qualifiesObservation(observed, operation: operation, boot: boot,
                                                 floor: floor, now: SampleClock.nowNanoseconds())
            if positive { break }
        }
        let result = await controller.stop()
        let restored = result == .stopped || result == .restored
        qualificationRunning = false; qualificationOwner = nil
        let diagnostics = await backend.diagnosticSnapshot()
        let failure = diagnostics.first(where: { $0.failure != nil })
        let detail = failure.map { " Diagnostic: \($0.failure!.rawValue), outcome=\($0.outcome.map(String.init) ?? "unknown"), transport=\($0.transport.map(String.init) ?? "unknown")." } ?? ""
        let summary = positive && restored
            ? "One-shot adapter test observed battery power and verified restoration. Automatic temperature control remains off."
            : "Test inconclusive. Inhibit acknowledged: \(acknowledged ? "yes" : "no"); battery transition observed: \(positive ? "yes" : "no"); restoration verified: \(restored ? "yes" : "no"). Do not repeat automatically."
        return await finishQualification(summary + detail)
    }

    private func finishQualification(_ message: String) async -> ThermalControlStatus {
        qualificationRunning = false; qualificationOwner = nil
        qualificationResult = message
        return await status(message: message)
    }

    nonisolated static func qualifiesObservation(_ observation: ThermalInhibitionObservation?, operation: UUID,
                                                 boot: UUID, floor: UInt64, now: UInt64) -> Bool {
        guard let observation else { return false }
        return observation.operationID == operation && observation.bootID == boot && observation.inhibited &&
            observation.batterySupplyingPower && observation.observedAt >= floor && observation.observedAt <= now &&
            now - observation.observedAt <= 2_000_000_000
    }

    private func status(nativeMayProceed: Bool = false, nativeConnection: UUID? = nil, nativeUID: uid_t? = nil, message: String? = nil) async -> ThermalControlStatus {
        guard let ledger else {
            return .init(phase: .recoveryRequired, controlAvailable: false,
                         message: "The ownership journal is unavailable. Temperature control and native changes are blocked until recovery can be checked.")
        }
        let generation = policyGeneration
        let observation = await backend?.freshInspection()
        let activePolicy = await policySession?.activePolicy
        let blocked = await ledger.blocksInhibitionAndUninstall
        let now = SampleClock.nowNanoseconds()
        let fresh = observation?.sampledAt.map { $0 <= now && now - $0 <= 2_000_000_000 } == true
            && observation?.sourceAt.map { $0 <= now && now - $0 <= 2_000_000_000 } == true
        let restored = fresh && observation?.outcome == 0 && observation?.key == 0 && observation?.adapter == true
        let safe = generation == policyGeneration && !blocked && !recovering && !qualificationRunning && activePolicy == nil
        let nativeReady = nativeMayProceed && safe && nativeConnection != nil && nativeOwner == nativeConnection &&
            !nativeNeedsReconciliation && !connectionHistoryFull && !invalidatedConnections.contains(nativeConnection!) &&
            nativeUID != nil && Self.activeConsoleUser() == nativeUID
        let admitted = ThermalAutomaticQualification.current != nil
        return .init(phase: qualificationRunning ? .qualifying : (blocked && activePolicy == nil ? .recoveryRequired : (recovering ? .restoring : (admitted ? policyPhase : .unavailable))),
                     controlAvailable: admitted, qualificationAvailable: LocalThermalAdapterBackend.qualificationEnabled && !uninstallRequested && !qualificationConsumed && safe && nativeOwner == nil && activePolicy == nil,
                     nativeMayProceed: nativeReady,
                     adapterRestored: restored, safeToExit: safe && nativeOwner == nil,
                     message: message ?? (activePolicy != nil ? policyMessage : nil) ?? (blocked ? "Adapter restoration is not verified. Keep the app open for recovery." : "Temperature control is not yet qualified for automatic operation. The 80% and 100% controls remain available."),
                     temperatureCelsius: observation?.temperatureCelsius ?? (activePolicy != nil ? policyTemperature?.value : nil),
                     estimatedTemperature: observation?.temperatureEstimated ?? true, policy: activePolicy, qualificationResult: qualificationResult,
                     nativeReconciliationRequired: nativeNeedsReconciliation,
                     maximumPauseSeconds: ThermalAutomaticQualification.current?.maximumPauseSeconds,
                     minimumReservePercent: ThermalAutomaticQualification.current?.minimumReservePercent)
    }
}
