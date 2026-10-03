import Foundation
import Darwin
import Testing
import StatBattDomain
@testable import StatBattNativeLimit

private struct LegacyTrustFixture: Encodable {
    let shortcutUUID: UUID
    let expectedName = NativeFixedLimit.eighty.expectedShortcutName
    let acknowledgement = NativeTrustAcknowledgement.approvedMutableUserWorkflow
    let approvedAtUTC: Date
    let confirmedBaselinePercent: Double = 100
    let confirmedOtherControllersStopped = true
    let platform = PlatformFingerprint(model: "Mac16,13", architecture: "arm64", operatingSystemVersion: "27.0.1",
        operatingSystemBuild: "26A434", firmwareVersion: "mBoot-20457.1.29", providerVersion: "test.synthetic")
}
private struct LegacyJournalFixture: Encodable {
    let schemaVersion: UInt16 = 1
    let ownerUID: UInt32
    let trust: LegacyTrustFixture?
    let phase: String
    let operationID: UUID?
    let requestedAtUTC: Date?
    let confirmedAtUTC: Date?
    let priorShortcutCompletedOrStoppedAtUTC: Date?
}
private func legacyFixture(_ phase: String) throws -> (Data, LegacyJournalFixture) {
    let time = Date(timeIntervalSince1970: 1_800_000_000.125)
    let hasOperation = !["notConfigured", "ready"].contains(phase)
    let hasConfirmation = ["manuallyConfirmed80", "restoredUserConfirmed100"].contains(phase)
    let fixture = LegacyJournalFixture(ownerUID: UInt32(geteuid()),
        trust: phase == "notConfigured" ? nil : LegacyTrustFixture(shortcutUUID: UUID(), approvedAtUTC: time),
        phase: phase, operationID: hasOperation ? UUID() : nil, requestedAtUTC: hasOperation ? time : nil,
        confirmedAtUTC: hasConfirmation ? time : nil,
        priorShortcutCompletedOrStoppedAtUTC: phase == "restoredUserConfirmed100" ? time : nil)
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    return (try encoder.encode(fixture), fixture)
}
private func decodeJournal(_ data: Data) throws -> NativeLimitJournal {
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(NativeLimitJournal.self, from: data)
}
private final class MigrationStorage: NativeLimitJournalStorage, @unchecked Sendable {
    var value: NativeLimitJournal
    var saved: NativeLimitJournal?
    let failSave: Bool
    init(_ value: NativeLimitJournal, failSave: Bool = false) { self.value = value; self.failSave = failSave }
    func load() throws -> NativeLimitJournal? { value }
    func save(_ journal: NativeLimitJournal) throws {
        if failSave { throw NativeLimitFailure.journalUnavailable }
        saved = journal; value = journal
    }
}
private actor NeverExecutingTransport: NativeShortcutTransport {
    var executionCount = 0
    func listShortcuts() async throws -> [NativeShortcutIdentity] { [] }
    func executeTrusted(_ shortcut: TrustedNativeShortcut) async -> NativeExecutionResult {
        executionCount += 1; Issue.record("Migration executed a shortcut"); return .failed
    }
}
private struct MigrationLock: NativeLimitInstanceLock { func acquire() throws {} }
private func migrationCoordinator(_ store: MigrationStorage, _ transport: NeverExecutingTransport) throws -> NativeLimitCoordinator {
    let platform = PlatformFingerprint(model: "Mac16,13", architecture: "arm64", operatingSystemVersion: "27.0.1",
        operatingSystemBuild: "26A434", firmwareVersion: "mBoot-20457.1.29", providerVersion: "test.synthetic")
    return try NativeLimitCoordinator(platform: platform, storage: store, transport: transport, instanceLock: MigrationLock(), preflight: { .clear })
}

@Test func everyLegacyPhaseMigratesWithoutGranting100TrustOrExecuting() async throws {
    for phase in ["notConfigured", "ready", "requested", "acknowledgedUnverified", "outcomeUnknown", "manuallyConfirmed80", "restoredUserConfirmed100"] {
        let (data, fixture) = try legacyFixture(phase)
        let decoded = try decodeJournal(data)
        let store = MigrationStorage(decoded); let transport = NeverExecutingTransport()
        let coordinator = try migrationCoordinator(store, transport)
        let persisted = try #require(store.saved)
        try persisted.validate(ownerUID: UInt32(geteuid()))
        #expect(persisted.schemaVersion == 2 && !persisted.needsMigration)
        #expect(persisted.trust100 == nil && persisted.qualification100AttemptedAtUTC == nil)
        #expect(persisted.trust80?.shortcutUUID == fixture.trust?.shortcutUUID)
        #expect(persisted.trust80?.acknowledgement == fixture.trust?.acknowledgement)
        #expect(persisted.trust80?.confirmedBaselinePercent == fixture.trust?.confirmedBaselinePercent)
        #expect(persisted.operationID == fixture.operationID)
        #expect(persisted.requestedAtUTC == decoded.requestedAtUTC)
        #expect(persisted.trust80?.approvedAtUTC == decoded.trust80?.approvedAtUTC)
        #expect(persisted.requestedLimit == (fixture.operationID == nil ? nil : .eighty))
        let status = await coordinator.status()
        #expect(status.requiresManualRecovery == ["requested", "outcomeUnknown", "manuallyConfirmed80"].contains(phase))
        #expect(status.canRequest100 == false)
        if phase == "acknowledgedUnverified" { #expect(status.canRequest80 && status.lastObservedLimit == nil) }
        if phase == "manuallyConfirmed80" { #expect(status.lastObservedLimit == .eighty && !status.canRequest80) }
        if phase == "restoredUserConfirmed100" { #expect(status.lastObservedLimit == .hundred && status.canRequest80) }
        #expect(await transport.executionCount == 0)
    }
}
@Test func migrationSaveFailureLeavesLegacyStateAndNoExecution() async throws {
    let (data, _) = try legacyFixture("acknowledgedUnverified")
    let journal = try decodeJournal(data)
    let store = MigrationStorage(journal, failSave: true); let transport = NeverExecutingTransport()
    #expect(throws: NativeLimitFailure.journalUnavailable) { try migrationCoordinator(store, transport) }
    #expect(store.saved == nil && store.value.needsMigration)
    #expect(store.value.operationID == journal.operationID)
    #expect(await transport.executionCount == 0)
}
@Test func schema2RoundTripPreservesUnknownAndHistoricalObservationTogether() throws {
    let (data, _) = try legacyFixture("manuallyConfirmed80")
    let migrated = try decodeJournal(data)
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    let decoded = try decodeJournal(encoder.encode(migrated))
    try decoded.validate(ownerUID: UInt32(geteuid()))
    #expect(decoded.phase == .outcomeUnknown && decoded.observedLimit == .eighty)
    #expect(decoded.confirmedAtUTC == migrated.confirmedAtUTC)
    #expect(decoded.operationID == migrated.operationID && !decoded.needsMigration)
}
@Test func schema2RejectsUnknownTargetVersionOwnerAndInconsistentRecoveryFields() throws {
    let (data, _) = try legacyFixture("manuallyConfirmed80")
    let migrated = try decodeJournal(data)
    let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    let cleanData = try encoder.encode(migrated)
    let base = try #require(JSONSerialization.jsonObject(with: cleanData) as? [String: Any])
    for (key, value) in [("schemaVersion", 3), ("requestedLimit", 81), ("observedLimit", 99)] {
        var changed = base; changed[key] = value
        #expect(throws: (any Error).self) { try decodeJournal(JSONSerialization.data(withJSONObject: changed)) }
    }
    #expect(throws: NativeLimitFailure.journalUnavailable) { try migrated.validate(ownerUID: migrated.ownerUID &+ 1) }
    var broken = migrated; broken.observedLimit = nil
    #expect(throws: NativeLimitFailure.journalUnavailable) { try broken.validate(ownerUID: broken.ownerUID) }
    broken = migrated; broken.phase = .ownerReconciled; broken.priorShortcutCompletedOrStoppedAtUTC = nil
    #expect(throws: NativeLimitFailure.journalUnavailable) { try broken.validate(ownerUID: broken.ownerUID) }
    broken = migrated; broken.requestedLimit = .hundred
    #expect(throws: NativeLimitFailure.journalUnavailable) { try broken.validate(ownerUID: broken.ownerUID) }
}
@Test func legacyFileMigrationUsesExistingRestrictedAtomicStorage() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StatBattMigration-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let (fixtureData, _) = try legacyFixture("manuallyConfirmed80")
    // File storage requires fractional UTC timestamps; convert the synthetic fixture accordingly.
    var text = try #require(String(data: fixtureData, encoding: .utf8))
    text = text.replacingOccurrences(of: "Z\"", with: ".000Z\"")
    let file = directory.appendingPathComponent("native-limit.json")
    try Data(text.utf8).write(to: file)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    let storage = try FileNativeLimitJournal(directory: directory)
    let transport = NeverExecutingTransport()
    let platform = PlatformFingerprint(model: "Mac16,13", architecture: "arm64", operatingSystemVersion: "27.0.1",
        operatingSystemBuild: "26A434", firmwareVersion: "mBoot-20457.1.29", providerVersion: "test.synthetic")
    let coordinator = try NativeLimitCoordinator(platform: platform, storage: storage, transport: transport,
        instanceLock: MigrationLock(), preflight: { .clear })
    #expect(await coordinator.status().requiresManualRecovery)
    let saved = try #require(try storage.load())
    #expect(saved.schemaVersion == 2 && !saved.needsMigration && saved.observedLimit == .eighty)
    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["native-limit.json"])
    #expect(await transport.executionCount == 0)
}
