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
