import Foundation
import Darwin

private let maximumJournalBytes = 65_536

private func secureDirectoryDescriptor(_ directory: URL) throws -> Int32 {
    guard directory.isFileURL, geteuid() != 0 else { throw NativeLimitFailure.journalUnavailable }
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: 0o700)])
    } catch { throw NativeLimitFailure.journalUnavailable }
    let fd = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    guard fd >= 0 else { throw NativeLimitFailure.journalUnavailable }
    var info = stat()
    guard fstat(fd, &info) == 0, info.st_uid == geteuid(), info.st_mode & 0o077 == 0 else {
        close(fd); throw NativeLimitFailure.journalUnavailable
    }
    return fd
}

/// Fixed-scope user-owned journal. No file path is accepted by any charging operation.
public final class FileNativeLimitJournal: NativeLimitJournalStorage, @unchecked Sendable {
    private let directoryFD: Int32
    public init(directory: URL) throws { directoryFD = try secureDirectoryDescriptor(directory) }
    deinit { close(directoryFD) }

    public func load() throws -> NativeLimitJournal? {
        let fd = openat(directoryFD, "native-limit.json", O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        if fd < 0 {
            if errno == ENOENT { return nil }
            throw NativeLimitFailure.journalUnavailable
        }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == geteuid(), info.st_mode & 0o077 == 0,
              info.st_size > 0, info.st_size <= maximumJournalBytes else { throw NativeLimitFailure.journalUnavailable }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while true {
            let count = read(fd, &buffer, buffer.count)
            if count < 0 {
                if errno == EINTR { continue }
                throw NativeLimitFailure.journalUnavailable
            }
            if count == 0 { break }
            guard data.count + count <= maximumJournalBytes else { throw NativeLimitFailure.journalUnavailable }
            data.append(contentsOf: buffer.prefix(count))
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let text = try container.decode(String.self)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                guard text.hasSuffix("Z"), let date = formatter.date(from: text) else { throw NativeLimitFailure.journalUnavailable }
                return date
            }
            let journal = try decoder.decode(NativeLimitJournal.self, from: data)
            try journal.validate(ownerUID: UInt32(geteuid()))
            return journal
        } catch { throw NativeLimitFailure.journalUnavailable }
    }

    public func save(_ journal: NativeLimitJournal) throws {
        try journal.validate(ownerUID: UInt32(geteuid()))
        var existing = stat()
        let existingResult = fstatat(directoryFD, "native-limit.json", &existing, AT_SYMLINK_NOFOLLOW)
        if existingResult == 0 {
            guard existing.st_mode & S_IFMT == S_IFREG, existing.st_uid == geteuid(), existing.st_mode & 0o077 == 0 else {
                throw NativeLimitFailure.journalUnavailable
            }
        } else if errno != ENOENT {
            throw NativeLimitFailure.journalUnavailable
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        encoder.outputFormatting = [.sortedKeys]
        let data: Data
        do { data = try encoder.encode(journal) } catch { throw NativeLimitFailure.journalUnavailable }
        guard data.count <= maximumJournalBytes else { throw NativeLimitFailure.journalUnavailable }
        let temporaryName = ".native-limit-" + UUID().uuidString + ".tmp"
        let fd = openat(directoryFD, temporaryName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw NativeLimitFailure.journalUnavailable }
        defer { close(fd); unlinkat(directoryFD, temporaryName, 0) }
        try data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { throw NativeLimitFailure.journalUnavailable }
            var written = 0
            while written < bytes.count {
                let count = write(fd, base.advanced(by: written), bytes.count - written)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw NativeLimitFailure.journalUnavailable }
                written += count
            }
        }
        // fsync orders data; macOS F_FULLFSYNC additionally requests a physical device flush.
        guard fsync(fd) == 0, fcntl(fd, F_FULLFSYNC) == 0,
              renameat(directoryFD, temporaryName, directoryFD, "native-limit.json") == 0,
              fsync(directoryFD) == 0 else { throw NativeLimitFailure.journalUnavailable }
    }
}

/// Advisory exclusion for cooperating StatBatt instances of this user. Another controller or
/// another user is outside this lock's scope. The OS releases the lock after a process crash;
/// pending journal state then blocks fresh dispatch until visible manual reconciliation.
public final class FileNativeLimitInstanceLock: NativeLimitInstanceLock, @unchecked Sendable {
    private let descriptor: Int32
    private let stateLock = NSLock()
    private var acquired = false
    public init(directory: URL) throws {
        let directoryFD = try secureDirectoryDescriptor(directory)
        defer { close(directoryFD) }
        let fd = openat(directoryFD, "native-limit.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw NativeLimitFailure.journalUnavailable }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              info.st_uid == geteuid(), info.st_mode & 0o077 == 0 else {
            close(fd); throw NativeLimitFailure.journalUnavailable
        }
        descriptor = fd
    }
    deinit { close(descriptor) }
    public func acquire() throws {
        stateLock.lock(); defer { stateLock.unlock() }
        guard !acquired else { throw NativeLimitFailure.anotherInstance }
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { throw NativeLimitFailure.anotherInstance }
        acquired = true
    }
}
