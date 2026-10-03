import Foundation
import Darwin

public enum ThermalJournalError: Error { case unavailable, unresolvedIntent, wrongOperation, invalidObservation }

public struct ThermalOwnershipRecord: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable { case inhibitionIntent, restorationIntent, restored }
    public let version: Int
    public let operationID: UUID
    public let sessionID: UUID
    public let originatingBootID: UUID
    public let intendedAt: UInt64
    public var phase: Phase
    public var restorationBootID: UUID?
    public var restorationFloor: UInt64?
    public var recoveredAt: UInt64?
    public var unresolved: Bool { phase != .restored }

    fileprivate func validate() throws {
        guard version == 1 else { throw ThermalJournalError.unavailable }
        switch phase {
        case .inhibitionIntent:
            guard restorationBootID == nil, restorationFloor == nil, recoveredAt == nil else { throw ThermalJournalError.unavailable }
        case .restorationIntent:
            guard restorationBootID != nil, restorationFloor != nil, recoveredAt == nil else { throw ThermalJournalError.unavailable }
        case .restored:
            guard restorationBootID != nil, let floor = restorationFloor, let recovered = recoveredAt,
                  recovered >= floor else { throw ThermalJournalError.unavailable }
        }
    }
}

public protocol ThermalOwnershipJournalStorage: Sendable {
    func load() throws -> ThermalOwnershipRecord?
    /// Success means replacement and containing-directory synchronization completed.
    func save(_ record: ThermalOwnershipRecord) throws
}

/// No hardware calls. A returned operation ID authorizes only the caller's next
/// independently qualified actuation; it is returned only after durable intent.
public actor ThermalOwnershipLedger {
    private let storage: any ThermalOwnershipJournalStorage
    private let bootID: UUID
    private var record: ThermalOwnershipRecord?
    private var storageFault = false
    private var restorationFloorThisProcess: UInt64?

    public init(storage: any ThermalOwnershipJournalStorage, bootID: UUID) throws {
        self.storage = storage; self.bootID = bootID
        let loaded = try storage.load()
        try loaded?.validate()
        record = loaded
    }
    public var blocksInhibitionAndUninstall: Bool { storageFault || record?.unresolved == true }
    public var snapshot: ThermalOwnershipRecord? { record }

    public func prepareInhibition(sessionID: UUID, now: UInt64) throws -> UUID {
        guard !blocksInhibitionAndUninstall else { throw ThermalJournalError.unresolvedIntent }
        let next = ThermalOwnershipRecord(version: 1, operationID: UUID(), sessionID: sessionID,
            originatingBootID: bootID, intendedAt: now, phase: .inhibitionIntent)
        try persist(next)
        restorationFloorThisProcess = nil
        return next.operationID
    }

    /// Call before attempting restore, including after restart. A journal error
    /// must NEVER prevent the caller attempting emergency restoration itself.
    public func recordRestorationIntent(operationID: UUID, now: UInt64) throws {
        guard var next = record, next.operationID == operationID, next.unresolved else {
            throw ThermalJournalError.wrongOperation
        }
        next.phase = .restorationIntent; next.restorationBootID = bootID
        next.restorationFloor = now; next.recoveredAt = nil
        restorationFloorThisProcess = now
        try persist(next)
    }

    public func confirmRestored(operationID: UUID, observationBootID: UUID,
                                keyIsZero: Bool, keyObservedAt: UInt64,
                                adapterSupplyingPower: Bool, sourceObservedAt: UInt64,
                                now: UInt64) throws {
        guard var next = record, next.operationID == operationID, next.phase == .restorationIntent,
              let floor = restorationFloorThisProcess, next.restorationBootID == bootID,
              observationBootID == bootID, keyIsZero, adapterSupplyingPower,
              keyObservedAt >= floor, sourceObservedAt >= floor,
              keyObservedAt <= now, sourceObservedAt <= now,
              now - keyObservedAt <= 2_000_000_000, now - sourceObservedAt <= 2_000_000_000 else {
            throw ThermalJournalError.invalidObservation
        }
        next.phase = .restored; next.recoveredAt = now
        try persist(next)
        restorationFloorThisProcess = nil
        storageFault = false
    }

    private func persist(_ next: ThermalOwnershipRecord) throws {
        // Retain unresolved knowledge even if a rename succeeded but sync failed.
        do { try storage.save(next); record = next }
        catch {
            if next.unresolved { record = next }
            storageFault = true
            throw ThermalJournalError.unavailable
        }
    }
}

/// Fixed daemon-owned location; no path can arrive from a wire request. The
/// exclusive directory lock prevents concurrent journal owners in this process
/// or another daemon. Production construction requires root-owned ancestry.
public final class FileThermalOwnershipJournal: ThermalOwnershipJournalStorage, @unchecked Sendable {
    private let directoryFD: Int32
    private let name = "thermal-ownership.json"
    public convenience init() throws {
        guard getuid() == 0, geteuid() == 0 else { throw ThermalJournalError.unavailable }
        for path in ["/Library", "/Library/Application Support"] {
            var s = stat()
            guard lstat(path, &s) == 0, s.st_mode & S_IFMT == S_IFDIR,
                  s.st_uid == 0, s.st_mode & 0o022 == 0 else { throw ThermalJournalError.unavailable }
        }
        try self.init(directory: URL(fileURLWithPath: "/Library/Application Support/StatBattThermalOwnership"))
    }
    // Internal injection is for tests only; never exposed in an XPC DTO.
    init(directory: URL) throws {
        guard directory.isFileURL else { throw ThermalJournalError.unavailable }
        let created = mkdir(directory.path, 0o700) == 0
        if !created && errno != EEXIST { throw ThermalJournalError.unavailable }
        if created {
            let parent = open(directory.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard parent >= 0 else { throw ThermalJournalError.unavailable }
            let synced = fsync(parent) == 0
            close(parent)
            guard synced else { throw ThermalJournalError.unavailable }
        }
        let fd = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw ThermalJournalError.unavailable }
        var s = stat()
        guard fstat(fd, &s) == 0, s.st_uid == geteuid(), s.st_mode & 0o077 == 0,
              flock(fd, LOCK_EX | LOCK_NB) == 0 else { close(fd); throw ThermalJournalError.unavailable }
        directoryFD = fd
    }
    deinit { close(directoryFD) }
    public func load() throws -> ThermalOwnershipRecord? {
        guard let data = try readData(name: name) else { return nil }
        let result = try JSONDecoder().decode(ThermalOwnershipRecord.self, from: data)
        try result.validate()
        return result
    }
    private struct NativeRequest: Codable {
        let version: Int
        let connection: UUID?
    }
    public func loadNativeRequest() throws -> UUID? {
        guard let data = try readData(name: "native-request.json") else { return nil }
        let result = try JSONDecoder().decode(NativeRequest.self, from: data)
        guard result.version == 1 else { throw ThermalJournalError.unavailable }
        return result.connection
    }
    public func saveNativeRequest(_ connection: UUID?) throws {
        try writeData(JSONEncoder().encode(NativeRequest(version: 1, connection: connection)), name: "native-request.json")
    }
    private func readData(name: String) throws -> Data? {
        let fd = openat(directoryFD, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        if fd < 0 { if errno == ENOENT { return nil }; throw ThermalJournalError.unavailable }
        defer { close(fd) }
        var s = stat()
        guard fstat(fd, &s) == 0, s.st_mode & S_IFMT == S_IFREG, s.st_uid == geteuid(),
              s.st_mode & 0o077 == 0, s.st_nlink == 1, s.st_size > 0, s.st_size <= 16_384 else {
            throw ThermalJournalError.unavailable
        }
        var bytes = [UInt8](repeating: 0, count: Int(s.st_size))
        var offset = 0
        while offset < bytes.count {
            let remaining = bytes.count - offset
            let count = bytes.withUnsafeMutableBytes { read(fd, $0.baseAddress!.advanced(by: offset), remaining) }
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw ThermalJournalError.unavailable }
            offset += count
        }
        return Data(bytes)
    }
    public func save(_ record: ThermalOwnershipRecord) throws {
        try record.validate()
        try writeData(JSONEncoder().encode(record), name: name)
    }
    private func writeData(_ bytes: Data, name: String) throws {
        var existing = stat()
        if fstatat(directoryFD, name, &existing, AT_SYMLINK_NOFOLLOW) == 0 {
            guard existing.st_mode & S_IFMT == S_IFREG, existing.st_uid == geteuid(),
                  existing.st_mode & 0o077 == 0, existing.st_nlink == 1 else { throw ThermalJournalError.unavailable }
        } else if errno != ENOENT { throw ThermalJournalError.unavailable }
        guard bytes.count <= 16_384 else { throw ThermalJournalError.unavailable }
        let temporary = ".thermal-" + UUID().uuidString
        let fd = openat(directoryFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw ThermalJournalError.unavailable }
        defer { close(fd); unlinkat(directoryFD, temporary, 0) }
        try bytes.withUnsafeBytes { buffer in
            var offset = 0
            while offset < bytes.count {
                let count = write(fd, buffer.baseAddress!.advanced(by: offset), bytes.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw ThermalJournalError.unavailable }
                offset += count
            }
        }
        guard fsync(fd) == 0, fcntl(fd, F_FULLFSYNC) == 0,
              renameat(directoryFD, temporary, directoryFD, name) == 0,
              fsync(directoryFD) == 0 else { throw ThermalJournalError.unavailable }
    }
}
