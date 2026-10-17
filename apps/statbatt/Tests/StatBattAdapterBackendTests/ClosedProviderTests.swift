import Foundation
import Testing
import Darwin
import StatBattControlProtocol
@testable import StatBattAdapterBackend

private final class MemoryJournal: ThermalOwnershipJournalStorage, @unchecked Sendable {
    let lock = NSLock()
    var value: ThermalOwnershipRecord?
    func load() throws -> ThermalOwnershipRecord? { lock.withLock { value } }
    func save(_ record: ThermalOwnershipRecord) throws { lock.withLock { value = record } }
}

@Test func unqualifiedBackendCannotActuateEvenWithDurableIntent() async throws {
    let boot = UUID(), storage = MemoryJournal()
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
    let operation = try await ledger.prepareInhibition(sessionID: UUID(), now: 1)
    let backend = LocalThermalAdapterBackend(ledger: ledger, bootID: boot)
    #expect(!LocalThermalAdapterBackend.qualificationEnabled)
    #expect(!LocalThermalAdapterBackend.recoveryEnabled)
    #expect(await backend.inhibitAdapter(operationID: operation) == false)
    #expect(await backend.restoreAdapter() == nil)
    #expect(await ledger.blocksInhibitionAndUninstall)
    #expect(await backend.stopAndReapWriter())
}

@Test func missingOwnershipCannotAuthorizeProvider() async throws {
    let boot = UUID(), ledger = try ThermalOwnershipLedger(storage: MemoryJournal(), bootID: UUID())
    let backend = LocalThermalAdapterBackend(ledger: ledger, bootID: boot)
    #expect(await backend.inhibitAdapter(operationID: UUID()) == false)
    #expect(await backend.restoreAdapter() == nil)
    #expect(await ledger.snapshot == nil)
}

@Test func adapterFailureHistoryIsBoundedAndRejectsArbitraryStrings() throws {
    var history = AdapterDiagnosticHistory()
    var packet = AdapterPacket(phase: "/private/sensitive/path")
    packet.failure = .thermalNotNominalOrStale; packet.outcome = 5
    for index in 0..<100 { history.append(.init(event: "arbitrary user text", at: UInt64(index), packet: packet)) }
    #expect(history.entries.count == 64)
    #expect(history.entries.first?.at == 36)
    #expect(history.entries.last?.phase == "rejected")
    #expect(history.entries.last?.event == "failed")
    #expect(history.entries.last?.failure == .thermalNotNominalOrStale)
    #expect(history.entries.last?.outcome == 5)
    let encoded = try JSONEncoder().encode(history.entries)
    #expect(!String(decoding: encoded, as: UTF8.self).contains("sensitive"))
}

private actor InspectionFixture {
    var calls = 0
    func inspect() async -> AdapterPacket? {
        calls += 1
        try? await Task.sleep(for: .milliseconds(100))
        var packet = AdapterPacket(phase: "inspection")
        packet.sampledAt = UInt64(calls); packet.sourceAt = UInt64(calls)
        packet.outcome = 0; packet.key = 0; packet.adapter = true
        return packet
    }
}

@Test func concurrentInspectionReadersShareOneUncachedSample() async throws {
    let fixture = InspectionFixture()
    let ledger = try ThermalOwnershipLedger(storage: MemoryJournal(), bootID: UUID())
    let backend = LocalThermalAdapterBackend(ledger: ledger, bootID: UUID(), inspection: { await fixture.inspect() })
    async let first = backend.freshInspection()
    async let second = backend.freshInspection()
    let samples = await (first, second)
    #expect(await fixture.calls == 1)
    #expect(samples.0?.sampledAt == 1)
    #expect(samples.1?.sampledAt == 1)
    #expect(samples.0?.sourceAt == samples.1?.sourceAt)
    let later = await backend.freshInspection()
    #expect(await fixture.calls == 2)
    #expect(later?.sampledAt == 2)
}

@Test func pendingInhibitionWaitsForReadOnlyInspectionWithoutBusyFailure() async throws {
    let fixture = InspectionFixture()
    let ledger = try ThermalOwnershipLedger(storage: MemoryJournal(), bootID: UUID())
    let operation = try await ledger.prepareInhibition(sessionID: UUID(), now: 1)
    let backend = LocalThermalAdapterBackend(ledger: ledger, bootID: UUID(), inspection: { await fixture.inspect() })
    let inspection = Task { await backend.freshInspection() }
    while await fixture.calls == 0 { await Task.yield() }
    #expect(await backend.inhibitAdapter(operationID: operation) == false)
    let history = await backend.diagnosticSnapshot()
    #expect(history.contains { $0.failure == .identityOrGate })
    #expect(!history.contains { $0.failure == .backendBusy })
    #expect(await inspection.value?.sampledAt == 1)
}

@Test func inheritedWriterLeaseSurvivesParentDescriptorClosure() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let lease = open(path.path, O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)
    #expect(lease >= 0)
    guard lease >= 0 else { return }
    defer { try? FileManager.default.removeItem(at: path) }
    #expect(flock(lease, LOCK_SH | LOCK_NB) == 0)
    let child = Process(), ready = Pipe()
    child.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    child.arguments = ["-I", "-c", "import time; print('READY', flush=True); time.sleep(10)"]
    child.standardInput = FileHandle(fileDescriptor: lease, closeOnDealloc: false)
    child.standardOutput = ready
    do { try child.run() } catch { close(lease); throw error }
    defer { if child.isRunning { child.terminate() }; child.waitUntilExit() }
    #expect(ready.fileHandleForReading.readData(ofLength: 6) == Data("READY\n".utf8))
    close(lease)
    let contender = open(path.path, O_RDWR | O_CLOEXEC)
    defer { close(contender) }
    #expect(flock(contender, LOCK_EX | LOCK_NB) != 0)
    child.terminate(); child.waitUntilExit()
    #expect(flock(contender, LOCK_EX | LOCK_NB) == 0)
}

@Test func stopAndRestoreWaitForReadOnlyInspection() async throws {
    let fixture = InspectionFixture()
    let ledger = try ThermalOwnershipLedger(storage: MemoryJournal(), bootID: UUID())
    _ = try await ledger.prepareInhibition(sessionID: UUID(), now: 1)
    let backend = LocalThermalAdapterBackend(ledger: ledger, bootID: UUID(), inspection: { await fixture.inspect() })
    let reading = Task { await backend.freshInspection() }
    while await fixture.calls == 0 { await Task.yield() }
    #expect(await backend.stopAndReapWriter())
    #expect(await reading.value?.sampledAt == 1)
    let second = Task { await backend.freshInspection() }
    while await fixture.calls < 2 { await Task.yield() }
    #expect(await backend.restoreAdapter() == nil) // Closed write gate, not reader contention.
    let history = await backend.diagnosticSnapshot()
    #expect(history.contains { $0.failure == .identityOrGate })
    #expect(!history.contains { $0.failure == .backendBusy })
    #expect(await second.value?.sampledAt == 2)
    #expect(await ledger.blocksInhibitionAndUninstall)
}

@Test func packetDrainSelectsFreshLastPacketBeyondOneRead() throws {
    let channel = Pipe()
    let fd = channel.fileHandleForReading.fileDescriptor
    #expect(fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) == 0)
    var bytes = Data()
    for index in 1...90 {
        var packet = AdapterPacket(phase: "inhibited")
        packet.sampledAt = UInt64(index); packet.key = 8; packet.outcome = 0; packet.battery = true
        bytes.append(try JSONEncoder().encode(packet)); bytes.append(10)
    }
    #expect(bytes.count > 4096 && bytes.count < 16000)
    try channel.fileHandleForWriting.write(contentsOf: bytes)
    var buffered = Data(), latest: AdapterPacket?, count = 0
    drainAdapterPackets(fileDescriptor: fd, buffered: &buffered) { latest = $0; count += 1 }
    #expect(count == 90 && latest?.sampledAt == 90)
    #expect(buffered.isEmpty)
    // No EOF is required: EAGAIN terminates immediately with the writer open.
    drainAdapterPackets(fileDescriptor: fd, buffered: &buffered) { _ in count += 1 }
    #expect(count == 90)
}

@Test func packetDrainPreservesSplitFrameAcrossCalls() throws {
    let channel = Pipe(), packet = AdapterPacket(phase: "inspection")
    let fd = channel.fileHandleForReading.fileDescriptor
    #expect(fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK) == 0)
    var bytes = try JSONEncoder().encode(packet); bytes.append(10)
    let split = bytes.count / 2
    try channel.fileHandleForWriting.write(contentsOf: bytes.prefix(split))
    var buffered = Data(), phases: [String] = []
    drainAdapterPackets(fileDescriptor: fd, buffered: &buffered) { phases.append($0.phase) }
    #expect(phases.isEmpty && !buffered.isEmpty)
    try channel.fileHandleForWriting.write(contentsOf: bytes.suffix(from: split))
    drainAdapterPackets(fileDescriptor: fd, buffered: &buffered) { phases.append($0.phase) }
    #expect(phases == ["inspection"] && buffered.isEmpty)
}
