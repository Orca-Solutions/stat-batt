import Foundation
import Testing
@testable import StatBattControlProtocol

private final class ThermalMemoryJournal: ThermalOwnershipJournalStorage, @unchecked Sendable {
    var record: ThermalOwnershipRecord?
    var fail = false
    func load() throws -> ThermalOwnershipRecord? { record }
    func save(_ record: ThermalOwnershipRecord) throws {
        if fail { throw ThermalJournalError.unavailable }
        self.record = record
    }
}

@Test func thermalIntentMustPersistBeforePermissionAndFailureBlocksUninstall() async throws {
    let storage = ThermalMemoryJournal()
    storage.fail = true
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: UUID())
    await #expect(throws: ThermalJournalError.self) { try await ledger.prepareInhibition(sessionID: UUID(), now: 10) }
    #expect(await ledger.blocksInhibitionAndUninstall)
    #expect(storage.record == nil)
    storage.fail = false
    await #expect(throws: ThermalJournalError.self) { try await ledger.prepareInhibition(sessionID: UUID(), now: 11) }
}

@Test func thermalRestartRetainsIntentAndRequiresNewBootRestorationObservation() async throws {
    let storage = ThermalMemoryJournal(), originalBoot = UUID(), newBoot = UUID(), session = UUID()
    let first = try ThermalOwnershipLedger(storage: storage, bootID: originalBoot)
    let op = try await first.prepareInhibition(sessionID: session, now: 10)
    #expect(storage.record?.sessionID == session && storage.record?.originatingBootID == originalBoot)
    let recovered = try ThermalOwnershipLedger(storage: storage, bootID: newBoot)
    #expect(await recovered.blocksInhibitionAndUninstall)
    await #expect(throws: ThermalJournalError.self) {
        try await recovered.confirmRestored(operationID: op, observationBootID: newBoot, keyIsZero: true,
            keyObservedAt: 11, adapterSupplyingPower: true, sourceObservedAt: 11, now: 11)
    }
    try await recovered.recordRestorationIntent(operationID: op, now: 20)
    for boot in [originalBoot, UUID()] {
        await #expect(throws: ThermalJournalError.self) {
            try await recovered.confirmRestored(operationID: op, observationBootID: boot, keyIsZero: true,
                keyObservedAt: 20, adapterSupplyingPower: true, sourceObservedAt: 20, now: 20)
        }
    }
    try await recovered.confirmRestored(operationID: op, observationBootID: newBoot, keyIsZero: true,
        keyObservedAt: 20, adapterSupplyingPower: true, sourceObservedAt: 20, now: 20)
    #expect(!(await recovered.blocksInhibitionAndUninstall))
    #expect(storage.record?.phase == .restored)
}

@Test func thermalRecoveryRejectsStaleOneSidedAndWrongOperationProof() async throws {
    let storage = ThermalMemoryJournal(), boot = UUID()
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
    let op = try await ledger.prepareInhibition(sessionID: UUID(), now: 10)
    try await ledger.recordRestorationIntent(operationID: op, now: 20)
    for (key, source, keyAt, sourceAt) in [(false,true,20,20),(true,false,20,20),(true,true,19,20),(true,true,20,19),(true,true,21,20)] {
        await #expect(throws: ThermalJournalError.self) {
            try await ledger.confirmRestored(operationID: op, observationBootID: boot, keyIsZero: key,
                keyObservedAt: UInt64(keyAt), adapterSupplyingPower: source, sourceObservedAt: UInt64(sourceAt), now: 20)
        }
    }
    await #expect(throws: ThermalJournalError.self) {
        try await ledger.confirmRestored(operationID: UUID(), observationBootID: boot, keyIsZero: true,
            keyObservedAt: 20, adapterSupplyingPower: true, sourceObservedAt: 20, now: 20)
    }
    await #expect(throws: ThermalJournalError.self) {
        try await ledger.confirmRestored(operationID: op, observationBootID: boot, keyIsZero: true,
            keyObservedAt: 20, adapterSupplyingPower: true, sourceObservedAt: 20, now: 2_000_000_021)
    }
    #expect(await ledger.blocksInhibitionAndUninstall)
}

@Test func thermalFailedRecoveryPersistenceNeverReportsRecovered() async throws {
    let storage = ThermalMemoryJournal(), boot = UUID()
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: boot)
    let op = try await ledger.prepareInhibition(sessionID: UUID(), now: 10)
    try await ledger.recordRestorationIntent(operationID: op, now: 20)
    storage.fail = true
    await #expect(throws: ThermalJournalError.self) {
        try await ledger.confirmRestored(operationID: op, observationBootID: boot, keyIsZero: true,
            keyObservedAt: 20, adapterSupplyingPower: true, sourceObservedAt: 20, now: 20)
    }
    #expect(await ledger.blocksInhibitionAndUninstall)
    #expect(await ledger.snapshot?.phase == .restorationIntent)
}

@Test func thermalFileJournalRoundTripAndExclusiveOwnership() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("thermal-journal-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = try FileThermalOwnershipJournal(directory: directory)
    #expect(throws: ThermalJournalError.self) { try FileThermalOwnershipJournal(directory: directory) }
    let ledger = try ThermalOwnershipLedger(storage: storage, bootID: UUID())
    let op = try await ledger.prepareInhibition(sessionID: UUID(), now: 10)
    #expect(try storage.load()?.operationID == op)
    #expect(try storage.load()?.unresolved == true)
}

@Test func thermalFileJournalRejectsCorruptionAndSymlink() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("thermal-journal-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storage = try FileThermalOwnershipJournal(directory: directory)
    let path = directory.appendingPathComponent("thermal-ownership.json")
    try Data("not json".utf8).write(to: path)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path.path)
    #expect(throws: (any Error).self) { try storage.load() }
    try FileManager.default.removeItem(at: path)
    try FileManager.default.createSymbolicLink(atPath: path.path, withDestinationPath: "/dev/null")
    #expect(throws: ThermalJournalError.self) { try storage.load() }
}
