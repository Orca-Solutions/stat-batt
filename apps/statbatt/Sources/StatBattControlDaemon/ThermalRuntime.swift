import Foundation
import SystemConfiguration
import StatBattControlProtocol
import StatBattAdapterBackend
import StatBattTelemetry

/// Owns recovery even when automatic policy admission is disabled. A successful
/// short adapter trial is not authority to advertise recurring temperature control.
actor ThermalRuntime {
    private let ledger: ThermalOwnershipLedger?
    private let backend: LocalThermalAdapterBackend?
    private let controller: ThermalControlOrchestrator?
    private var invalidatedConnections: Set<UUID> = []
    private var connectionHistoryFull = false
    private var uninstallRequested = false
    private var nativeOwner: UUID?
    private var qualificationOwner: UUID?
    private var qualificationConsumed = false
    private var qualificationRunning = false
    private var recoveryCount = 0
    private var recovering: Bool { recoveryCount > 0 }

    init() {
        guard let text = PublicTelemetry.sysctlString("kern.bootsessionuuid"), let boot = UUID(uuidString: text),
              let storage = try? FileThermalOwnershipJournal(),
              let ledger = try? ThermalOwnershipLedger(storage: storage, bootID: boot) else {
            self.ledger = nil; backend = nil; controller = nil; return
        }
        self.ledger = ledger
        let backend = LocalThermalAdapterBackend(ledger: ledger, bootID: boot)
        self.backend = backend
        controller = ThermalControlOrchestrator(ledger: ledger, backend: backend, bootID: boot,
                                              clock: { SampleClock.nowNanoseconds() })
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
            // Deliberately independent of the two-second backend qualification gate.
            return await status(message: "Automatic temperature control is awaiting end-to-end qualification. No adapter command was sent.")
        case .prepareUninstall:
            uninstallRequested = true
            await recover()
            return await status()
        case .stop:
            await recover()
            return await status()
        case .prepareNative:
            await recover()
            guard let ledger, !(await ledger.blocksInhibitionAndUninstall), !recovering,
                  nativeOwner == nil || nativeOwner == connection else {
                return await status(message: "Adapter recovery or another native request must finish first.")
            }
            nativeOwner = connection
            return await status(nativeMayProceed: true)
        case .finishNative:
            if nativeOwner == connection { nativeOwner = nil }
            return await status()
        case .status, .heartbeat:
            return await status()
        }
    }

    func legacyRemovalSafe() async -> Bool {
        guard let ledger else { return false }
        return !(await ledger.blocksInhibitionAndUninstall) && !recovering && !qualificationRunning && !LocalThermalAdapterBackend.qualificationEnabled
    }

    func disconnected(_ connection: UUID) async {
        if invalidatedConnections.count < 4096 { invalidatedConnections.insert(connection) }
        else { connectionHistoryFull = true }
        // An unresolved native fence deliberately survives connection loss in this
        // process. Automatic policy is unavailable, including after restart.
        if qualificationOwner == connection { await recover() }
    }
    func recover(forSleep: Bool = false) async {
        recoveryCount += 1
        qualificationOwner = nil
        _ = await controller?.stop(forSleep: forSleep)
        recoveryCount -= 1
    }
    func woke() async { await controller?.woke() }

    private func qualify(connection: UUID, uid: uid_t) async -> ThermalControlStatus {
        guard LocalThermalAdapterBackend.qualificationEnabled, LocalThermalAdapterBackend.recoveryEnabled,
              Self.activeConsoleUser() == uid, !invalidatedConnections.contains(connection), !connectionHistoryFull, !uninstallRequested, !qualificationConsumed,
              !qualificationRunning, !recovering, nativeOwner == nil,
              let ledger, let backend, let controller else {
            return await status(message: "This build is not enabled for the one-shot adapter test.")
        }
        qualificationConsumed = true
        qualificationRunning = true
        qualificationOwner = connection
        defer { qualificationRunning = false; qualificationOwner = nil }
        guard !(await ledger.blocksInhibitionAndUninstall), qualificationOwner == connection,
              !recovering, nativeOwner == nil, Self.activeConsoleUser() == uid, !invalidatedConnections.contains(connection), !connectionHistoryFull, !uninstallRequested else {
            return await status(message: "An existing recovery must complete before testing.")
        }
        let operation: UUID
        do { operation = try await ledger.prepareInhibition(sessionID: connection, now: SampleClock.nowNanoseconds()) }
        catch { return await status(message: "Could not save the test ownership record. No adapter command was sent.") }
        guard qualificationOwner == connection, !recovering, nativeOwner == nil, Self.activeConsoleUser() == uid, !invalidatedConnections.contains(connection), !connectionHistoryFull, !uninstallRequested else {
            _ = await controller.stop()
            return await status(message: "Test cancelled before adapter inhibition.")
        }
        let intent = await ledger.snapshot
        guard qualificationOwner == connection, !recovering, nativeOwner == nil, Self.activeConsoleUser() == uid, !invalidatedConnections.contains(connection), !connectionHistoryFull, !uninstallRequested,
              let boot = intent?.originatingBootID, intent?.operationID == operation else {
            _ = await controller.stop()
            return await status(message: "Test cancelled before adapter inhibition.")
        }
        let start = SampleClock.nowNanoseconds()
        let acknowledged = await backend.inhibitAdapter(operationID: operation)
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
        return await status(message: positive && restored
            ? "One-shot adapter test observed battery power and verified restoration. Automatic temperature control remains off."
            : "One-shot adapter test did not establish the full transition. Check recovery status; do not repeat automatically.")
    }

    nonisolated static func qualifiesObservation(_ observation: ThermalInhibitionObservation?, operation: UUID,
                                                 boot: UUID, floor: UInt64, now: UInt64) -> Bool {
        guard let observation else { return false }
        return observation.operationID == operation && observation.bootID == boot && observation.inhibited &&
            observation.batterySupplyingPower && observation.observedAt >= floor && observation.observedAt <= now &&
            now - observation.observedAt <= 2_000_000_000
    }

    private func status(nativeMayProceed: Bool = false, message: String? = nil) async -> ThermalControlStatus {
        guard let ledger else {
            return .init(phase: .recoveryRequired, controlAvailable: false,
                         message: "The ownership journal is unavailable. Temperature control and native changes are blocked until recovery can be checked.")
        }
        let observation = await backend?.freshInspection()
        let blocked = await ledger.blocksInhibitionAndUninstall
        let now = SampleClock.nowNanoseconds()
        let fresh = observation?.sampledAt.map { $0 <= now && now - $0 <= 2_000_000_000 } == true
            && observation?.sourceAt.map { $0 <= now && now - $0 <= 2_000_000_000 } == true
        let restored = fresh && observation?.key == 0 && observation?.adapter == true
        let safe = !blocked && !recovering && !qualificationRunning
        return .init(phase: qualificationRunning ? .qualifying : (blocked ? .recoveryRequired : (recovering ? .restoring : .unavailable)),
                     controlAvailable: false, qualificationAvailable: LocalThermalAdapterBackend.qualificationEnabled && !uninstallRequested && !qualificationConsumed && safe && nativeOwner == nil,
                     nativeMayProceed: nativeMayProceed && safe,
                     adapterRestored: restored, safeToExit: safe,
                     message: message ?? (blocked ? "Adapter restoration is not verified. Keep the app open for recovery." : "Temperature control is not yet qualified for automatic operation. The 80% and 100% controls remain available."),
                     temperatureCelsius: observation?.temperatureCelsius,
                     estimatedTemperature: observation?.temperatureEstimated ?? true)
    }
}
