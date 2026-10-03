import Foundation
import Darwin
import StatBattControlProtocol
import StatBattDomain
import StatBattTelemetry

public enum AdapterPauseMode: Sendable { case twoSeconds, oneHundredTwentySeconds }

/// Closed, nonrenewable leases; extended mode requires separate qualification gates.
public actor LocalThermalAdapterBackend: ThermalControlBackend {
    public static let qualificationEnabled = false
    public static let recoveryEnabled = false
    public static let longPauseQualificationEnabled = false
    private let pauseMode: AdapterPauseMode
    private let ledger: ThermalOwnershipLedger
    private let bootID: UUID
    private var child: Process?
    private var owner: Pipe?
    private var output: Pipe?
    private var data = Data()
    private var latest: AdapterPacket?
    private var operation: UUID?
    private var reaped = false
    private var runningCall = false
    private var childIsReadOnly = false
    private var diagnosticHistory = AdapterDiagnosticHistory()
    private var recordPackets = false
    private var mutationWaiters = 0
    private var inspectionFlight: Task<AdapterPacket?, Never>?
    private let inspectionOverride: (@Sendable () async -> AdapterPacket?)?
    public func diagnosticSnapshot() -> [AdapterDiagnostic] { diagnosticHistory.entries }
    private func note(_ event: String, packet: AdapterPacket? = nil, failure: AdapterFailure? = nil, exitCode: Int32? = nil) {
        diagnosticHistory.append(AdapterDiagnostic(event: event, at: SampleClock.nowNanoseconds(), packet: packet, failure: failure, exitCode: exitCode))
    }

    public init(ledger: ThermalOwnershipLedger, bootID: UUID, pauseMode: AdapterPauseMode = .twoSeconds) {
        self.pauseMode = pauseMode
        self.ledger = ledger; self.bootID = bootID; inspectionOverride = nil
    }
    // Internal read-only injection; never an XPC or production initialization option.
    init(ledger: ThermalOwnershipLedger, bootID: UUID, inspection: @escaping @Sendable () async -> AdapterPacket?) {
        self.pauseMode = .twoSeconds
        self.ledger = ledger; self.bootID = bootID; inspectionOverride = inspection
    }
    private func start(_ mode: String) throws {
        guard (mode == "--cycle-120" ? (Self.longPauseQualificationEnabled && Self.qualificationEnabled && Self.recoveryEnabled) : mode == "--cycle" ? (Self.qualificationEnabled && Self.recoveryEnabled) : mode == "--recover" ? Self.recoveryEnabled : mode == "--inspect"), getuid() == 0, geteuid() == 0 else {
            if mode != "--inspect" { note("failed", failure: .identityOrGate) }
            throw ThermalJournalError.unavailable
        }
        recordPackets = mode != "--inspect"
        if recordPackets { note(mode == "--recover" ? "restoreLaunch" : "launch") }
        let executable = Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("StatBattAdapterGuardian")
        try AdapterExecutableIdentity.verify(url: executable, ownIdentifier: ThermalServiceContract.daemonIdentifier)
        let process = Process(), input = Pipe(), output = Pipe()
        process.executableURL = executable; process.arguments = [mode]
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": "/var/root"]
        process.standardInput = input; process.standardOutput = output; process.standardError = FileHandle.nullDevice
        try process.run()
        let fd = output.fileHandleForReading.fileDescriptor
        child = process; owner = input; self.output = output; data = Data(); latest = nil; reaped = false
        childIsReadOnly = mode == "--inspect"
        let flags = fcntl(fd, F_GETFL)
        guard flags >= 0, fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0 else {
            try? input.fileHandleForWriting.close()
            throw ThermalJournalError.unavailable
        }
    }
    private func receive() {
        guard let output else { return }
        drainAdapterPackets(fileDescriptor: output.fileHandleForReading.fileDescriptor, buffered: &data) { packet in
            latest = packet
            if recordPackets { note("packet", packet: packet) }
            if packet.reaped == true { reaped = true }
        }
    }
    private func waitForExit(seconds: Double) async -> Bool {
        let deadline = ContinuousClock.now + .milliseconds(Int(seconds * 1000))
        repeat {
            receive()
            if child?.isRunning != true { receive(); if recordPackets { note("exit", exitCode: child?.terminationStatus) }; return true }
            try? await Task.sleep(for: .milliseconds(20))
        } while ContinuousClock.now < deadline
        if recordPackets { note("timeout", failure: .deadline) }
        return false // Never race a potentially live writer with a new restore.
    }
    public func inhibitAdapter(operationID: UUID) async -> Bool {
        await inhibit(operationID: operationID, mode: pauseMode)
    }
    public func inhibitAdapterForOneShotQualification(operationID: UUID) async -> Bool {
        await inhibit(operationID: operationID, mode: .twoSeconds)
    }
    public func inhibitAdapterForLongPauseQualification(operationID: UUID) async -> Bool {
        await inhibit(operationID: operationID, mode: .oneHundredTwentySeconds)
    }
    private func inhibit(operationID: UUID, mode: AdapterPauseMode) async -> Bool {
        mutationWaiters += 1
        defer { mutationWaiters -= 1 }
        await drainInspectionBeforeMutation()
        guard !runningCall, child?.isRunning != true else { note("failed", failure: .backendBusy); return false }
        diagnosticHistory = AdapterDiagnosticHistory(); note("admission")
        runningCall = true; defer { runningCall = false }
        guard let intent = await ledger.snapshot, intent.operationID == operationID, intent.unresolved else { note("failed", failure: .missingIntent); return false }
        do {
            try start(mode == .twoSeconds ? "--cycle" : "--cycle-120")
            operation = operationID
            try owner?.fileHandleForWriting.write(contentsOf: Data((operationID.uuidString + "\n").utf8))
            note("dispatch")
            // Startup allowance only: the guardian starts its fixed nonrenewable
            // hardware lease after the prepared worker's READY/G handoff.
            let deadline = ContinuousClock.now + .seconds(5)
            repeat {
                receive()
                if latest?.phase == "inhibited", latest?.key == 8, latest?.outcome == 0 { return true }
                if child?.isRunning != true { note("exit", exitCode: child?.terminationStatus); return false }
                try? await Task.sleep(for: .milliseconds(20))
            } while ContinuousClock.now < deadline
            note("timeout", failure: .deadline)
        } catch { note("failed", failure: error is ThermalSigningError ? .signature : .dispatchFailed) }
        try? owner?.fileHandleForWriting.close()
        return false
    }
    public func observeInhibition(operationID: UUID) async -> ThermalInhibitionObservation? {
        let floor = SampleClock.nowNanoseconds()
        let deadline = ContinuousClock.now + .milliseconds(300)
        repeat {
            receive()
            if let sample = latest?.sampledAt, sample >= floor { break }
            if child?.isRunning != true { return nil }
            try? await Task.sleep(for: .milliseconds(20))
        } while ContinuousClock.now < deadline
        guard operation == operationID, let packet = latest, packet.phase == "inhibited",
              let sampled = packet.sampledAt, sampled >= floor else { return nil }
        return ThermalInhibitionObservation(bootID: bootID, operationID: operationID,
            inhibited: packet.key == 8 && packet.outcome == 0, batterySupplyingPower: packet.battery == true, observedAt: sampled)
    }
    public func stopAndReapWriter() async -> Bool {
        try? owner?.fileHandleForWriting.close()
        mutationWaiters += 1
        defer { mutationWaiters -= 1 }
        await drainInspectionBeforeMutation()
        guard !runningCall else { return false }
        if child == nil { return true } // Restart recovery: guardian lock still prevents overlapping writes.
        return await waitForExit(seconds: 12) && (reaped || childIsReadOnly)
    }
    public func restoreAdapter() async -> UInt64? {
        mutationWaiters += 1
        defer { mutationWaiters -= 1 }
        await drainInspectionBeforeMutation()
        guard !runningCall, child?.isRunning != true else { return nil }
        runningCall = true; defer { runningCall = false }
        guard await ledger.snapshot?.unresolved == true else { return nil }
        do { try start("--recover") } catch { note("failed", failure: error is ThermalSigningError ? .signature : .dispatchFailed); return nil }
        guard await waitForExit(seconds: 6), latest?.phase == "restored", latest?.key == 0,
              latest?.outcome == 0 else { return nil }
        return latest?.sampledAt
    }
    public func observeRestoration() async -> ThermalRestorationObservation? {
        guard let packet = await freshInspection(), let keyAt = packet.sampledAt,
              let sourceAt = packet.sourceAt, packet.outcome == 0 else { return nil }
        return ThermalRestorationObservation(bootID: bootID, keyIsZero: packet.key == 0, keyObservedAt: keyAt,
            adapterSupplyingPower: packet.adapter == true, sourceObservedAt: sourceAt, now: SampleClock.nowNanoseconds())
    }
    /// Wait only for a known read-only flight. Never wait here for or race a live
    /// writer; the orchestrator must drain its bounded mutation before stopping.
    private func drainInspectionBeforeMutation() async {
        guard let inspectionFlight else { return }
        _ = await inspectionFlight.value
    }
    public func freshInspection() async -> AdapterPacket? {
        if let inspectionFlight { return await inspectionFlight.value }
        guard mutationWaiters == 0, !runningCall, child?.isRunning != true else { return nil }
        // Reserve exclusion before creating the task; writers cannot slip into
        // the actor while concurrent readers join the same uncached inspection.
        runningCall = true
        let flight = Task {
            let packet = await self.performInspection()
            // Release read exclusion before waking any mutation waiters. An old
            // reader must not later clear a newer writer's runningCall flag.
            self.inspectionFlight = nil
            self.runningCall = false
            return packet
        }
        inspectionFlight = flight
        return await flight.value
    }
    private func performInspection() async -> AdapterPacket? {
        if let inspectionOverride { return await inspectionOverride() }
        do { try start("--inspect") } catch { return nil }
        guard await waitForExit(seconds: 2), let packet = latest, packet.phase == "inspection", packet.outcome == 0 else { return nil }
        return packet
    }
}

/// Nonblocking packet drain shared with pipe fixtures. Parsing each chunk permits
/// the newest complete observation to replace old backlog without unbounded work.
/// Descriptor must already be O_NONBLOCK; at most 64KiB is read per invocation.
func drainAdapterPackets(fileDescriptor: Int32, buffered: inout Data, receive: (AdapterPacket) -> Void) {
    var buffer = [UInt8](repeating: 0, count: 4096)
    for _ in 0..<16 {
        let count = read(fileDescriptor, &buffer, buffer.count)
        if count <= 0 { break } // EAGAIN/EOF/errors end this bounded drain.
        if buffered.count + count <= 32768 { buffered.append(contentsOf: buffer.prefix(count)) }
        while let newline = buffered.firstIndex(of: 10) {
            let line = buffered.prefix(upTo: newline)
            if let packet = try? JSONDecoder().decode(AdapterPacket.self, from: line) { receive(packet) }
            buffered.removeSubrange(...newline)
        }
    }
}
