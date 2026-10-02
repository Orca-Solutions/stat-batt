import Foundation
import Darwin
import Testing
import StatBattDomain
@testable import StatBattNativeLimit

private func temporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("StatBattNativeTests-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    return directory
}

@Test func listingParsesObservedParenthesizedUUIDFormatWithoutLosingNames() throws {
    let id = UUID()
    let name = NativeLimitCoordinator.expectedShortcutName
    let data = Data((name + " (" + id.uuidString + ")\nOther (synthetic) name (" + UUID().uuidString + ")\n").utf8)
    let list = try ShortcutListingParser.parse(data)
    #expect(list.count == 2)
    #expect(list[0] == NativeShortcutIdentity(id: id, name: name))
    #expect(list[1].name == "Other (synthetic) name")
    #expect(try ShortcutListingParser.parse(Data()).isEmpty)
}

@Test func malformedDuplicateAndOversizeListingsFailClosed() throws {
    for data in [Data([0xFF]), Data("name without identity\n".utf8), Data("name (not-a-uuid)\n".utf8),
                 Data("name\twith control (00000000-0000-0000-0000-000000000001)\n".utf8)] {
        #expect(throws: NativeLimitFailure.malformedListing) { try ShortcutListingParser.parse(data) }
    }
    #expect(throws: NativeLimitFailure.outputTooLarge) { try ShortcutListingParser.parse(Data(repeating: 32, count: 65_537)) }
    let id = UUID().uuidString
    #expect(throws: NativeLimitFailure.shortcutAmbiguous) {
        try ShortcutListingParser.parse(Data(("First (" + id + ")\nSecond (" + id + ")\n").utf8))
    }
}

@Test func controllerProbeAcceptsOnlyExplicitNoSuchServiceEvidence() {
    switch NativeKnownControllerProbe.classify(exitCode: 0, stderr: Data()) {
    case .conflictingController: break
    default: Issue.record("Present service not classified as conflict")
    }
    switch NativeKnownControllerProbe.classify(exitCode: 113, stderr: Data("Could not find service synthetic\n".utf8)) {
    case .clear: break
    default: Issue.record("Explicit missing service not recognized")
    }
    for (code, text) in [(Int32(1), "Could not find service"), (113, "permission denied"), (113, "")] {
        switch NativeKnownControllerProbe.classify(exitCode: code, stderr: Data(text.utf8)) {
        case .unavailable: break
        default: Issue.record("Ambiguous failure inferred service absence")
        }
    }
}

@Test func fileJournalRoundTripFlushesRestrictedAtomicUserState() throws {
    let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
    let store = try FileNativeLimitJournal(directory: directory)
    #expect(try store.load() == nil)
    let initial = NativeLimitJournal(ownerUID: UInt32(geteuid()))
    try store.save(initial)
    #expect(try store.load()?.phase == .notConfigured)
    let file = directory.appendingPathComponent("native-limit.json")
    let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
    #expect(permissions?.intValue == 0o600)
    try store.save(initial)
    #expect(try store.load()?.ownerUID == UInt32(geteuid()))
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["native-limit.json"])
}

@Test func corruptJournalAndSymlinkAreNeverOverwrittenOrFollowed() throws {
    let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
    let store = try FileNativeLimitJournal(directory: directory)
    let file = directory.appendingPathComponent("native-limit.json")
    try Data("corrupt synthetic state".utf8).write(to: file)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    #expect(throws: NativeLimitFailure.journalUnavailable) { try store.load() }
    #expect(try Data(contentsOf: file) == Data("corrupt synthetic state".utf8))
    try FileManager.default.removeItem(at: file)
    let target = directory.appendingPathComponent("outside-synthetic.json")
    try Data("unchanged".utf8).write(to: target)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: target)
    #expect(throws: NativeLimitFailure.journalUnavailable) { try store.load() }
    #expect(throws: NativeLimitFailure.journalUnavailable) { try store.save(NativeLimitJournal(ownerUID: UInt32(geteuid()))) }
    #expect(try Data(contentsOf: target) == Data("unchanged".utf8))
}

@Test func sameAccountInstanceLockExcludesCooperatingInstances() throws {
    let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
    var first: FileNativeLimitInstanceLock? = try FileNativeLimitInstanceLock(directory: directory)
    try first?.acquire()
    let second = try FileNativeLimitInstanceLock(directory: directory)
    #expect(throws: NativeLimitFailure.anotherInstance) { try second.acquire() }
    #expect(throws: NativeLimitFailure.anotherInstance) { try first?.acquire() }
    first = nil
    try second.acquire()
}

@Test func overlyPermissiveJournalDirectoryIsRejected() throws {
    let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: directory.path)
    #expect(throws: NativeLimitFailure.journalUnavailable) { try FileNativeLimitJournal(directory: directory) }
    #expect(throws: NativeLimitFailure.journalUnavailable) { try FileNativeLimitInstanceLock(directory: directory) }
}
