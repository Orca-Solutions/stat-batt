import Foundation
import Security
import Darwin

// Installer-only read-only admission. No hardware-writing mode is accepted.
let app = "/Library/Application Support/StatBattLocal/StatBatt.app"
let launcher = "/Applications/StatBatt Local.app"
func require(_ condition: @autoclosure () throws -> Bool) throws {
    if try !condition() { throw NSError(domain: "StatBattUpdatePreflight", code: 1) }
}
func metadata(_ path: String, directory: Bool, privateMode: Bool = false) throws -> stat {
    var info = stat()
    try require(lstat(path, &info) == 0 && info.st_uid == 0)
    try require(info.st_mode & S_IFMT == (directory ? S_IFDIR : S_IFREG))
    try require(info.st_mode & (privateMode ? 0o077 : 0o022) == 0)
    if !directory { try require(info.st_nlink == 1) }
    return info
}
func absent(_ path: String) throws -> Bool {
    var info = stat()
    if lstat(path, &info) == 0 { return false }
    try require(errno == ENOENT)
    return true
}
func signed(_ path: String, identifier: String, team: String) throws {
    var code: SecStaticCode?; var requirement: SecRequirement?
    let text = "anchor apple generic and identifier \"\(identifier)\" and certificate leaf[subject.OU] = \"\(team)\""
    try require(SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &code) == errSecSuccess)
    try require(SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess)
    try require(SecStaticCodeCheckValidity(code!, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckNestedCode), requirement) == errSecSuccess)
}
func run(_ executable: String, _ arguments: [String], timeout: Double = 5) throws -> (Int32, Data) {
    let task = Process(), output = Pipe()
    task.executableURL = URL(fileURLWithPath: executable); task.arguments = arguments
    task.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "HOME": "/var/root"]
    task.standardInput = FileHandle.nullDevice; task.standardOutput = output; task.standardError = FileHandle.nullDevice
    try task.run()
    let fd = output.fileHandleForReading.fileDescriptor
    try require(fcntl(fd, F_SETFL, O_NONBLOCK) == 0)
    var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
    let deadline = ProcessInfo.processInfo.systemUptime + timeout
    repeat {
        let count = read(fd, &buffer, buffer.count)
        if count > 0 { data.append(contentsOf: buffer.prefix(count)) }
        if data.count > 32768 || ProcessInfo.processInfo.systemUptime >= deadline {
            kill(task.processIdentifier, SIGKILL) // Admission fails; never proceed while a probe may remain alive.
            throw NSError(domain: "StatBattUpdatePreflightTimeout", code: 1)
        }
        if !task.isRunning { break }
        Thread.sleep(forTimeInterval: 0.01)
    } while true
    while true { let count = read(fd, &buffer, buffer.count); if count <= 0 { break }; data.append(contentsOf: buffer.prefix(count)); try require(data.count <= 32768) }
    return (task.terminationStatus, data)
}
struct Record: Decodable {
    let version: Int; let phase: String
    let operationID, sessionID, originatingBootID, restorationBootID: UUID
    let intendedAt, restorationFloor, recoveredAt: UInt64
}
struct Inspection: Decodable { let phase: String; let key, outcome: UInt8; let adapter: Bool; let sampledAt, sourceAt: UInt64 }
func validateRecord(_ data: Data) throws {
    let record = try JSONDecoder().decode(Record.self, from: data)
    try require(record.version == 1 && record.phase == "restored" && record.recoveredAt >= record.restorationFloor)
}
struct NativeRequestRecord: Decodable { let version: Int; let connection: UUID? }
func validateClearedNativeRequest(_ data: Data) throws {
    let record = try JSONDecoder().decode(NativeRequestRecord.self, from: data)
    try require(record.version == 1 && record.connection == nil)
}
func validateInspection(_ data: Data, now: UInt64) throws {
    let lines = data.split(separator: 10)
    try require(lines.count == 1)
    let packet = try JSONDecoder().decode(Inspection.self, from: Data(lines[0]))
    try require(packet.phase == "inspection" && packet.key == 0 && packet.outcome == 0 && packet.adapter)
    for sample in [packet.sampledAt, packet.sourceAt] {
        try require(sample > 0 && sample <= now && now - sample <= 2_000_000_000)
    }
}
#if !PREFLIGHT_TESTING
do {
#if LOCAL_REMOVAL
    try require(getuid() == 0 && CommandLine.arguments.count == 1)
    // Fixed local signing identity; no path or identity is accepted from the caller.
    let team = "TWZA95CB7G"
#else
    try require(getuid() == 0 && CommandLine.arguments.count == 2)
    let team = CommandLine.arguments[1]
#endif
    try require(team.range(of: "^[A-Z0-9]{10}$", options: .regularExpression) != nil)
    for path in ["/", "/Library", "/Library/Application Support", "/Library/Application Support/StatBattLocal", app, app + "/Contents", app + "/Contents/MacOS"] { _ = try metadata(path, directory: true) }
    for (name, identifier) in [("StatBatt", "dev.statbatt.local"), ("StatBattControlDaemon", "dev.statbatt.control-daemon"), ("StatBattAdapterGuardian", "dev.statbatt.adapter-guardian")] {
        _ = try metadata(app + "/Contents/MacOS/" + name, directory: false)
        try signed(name == "StatBatt" ? app : app + "/Contents/MacOS/" + name, identifier: identifier, team: team)
    }
    // Only the expected existing launcher is permitted; preserve it unchanged.
    if try !absent(launcher) {
        var link = stat()
        try require(lstat(launcher, &link) == 0 && link.st_uid == 0 && link.st_mode & S_IFMT == S_IFLNK)
        try require(try FileManager.default.destinationOfSymbolicLink(atPath: launcher) == app)
    }
    let launch = try run("/bin/launchctl", ["print", "system/dev.statbatt.control-daemon"])
    try require(launch.0 == 113)
    let running = try run("/usr/bin/pgrep", ["-x", "StatBatt"])
    try require(running.0 == 1)
    let directory = "/Library/Application Support/StatBattThermalOwnership"
    if try !absent(directory) {
        _ = try metadata(directory, directory: true, privateMode: true)
        let nativeRequest = directory + "/native-request.json"
        if try !absent(nativeRequest) {
            let info = try metadata(nativeRequest, directory: false, privateMode: true)
            try require(info.st_size > 0 && info.st_size <= 16384)
            try validateClearedNativeRequest(Data(contentsOf: URL(fileURLWithPath: nativeRequest)))
        }
        let journal = directory + "/thermal-ownership.json"
        if try !absent(journal) {
            let info = try metadata(journal, directory: false, privateMode: true)
            try require(info.st_size > 0 && info.st_size <= 16384)
            try validateRecord(Data(contentsOf: URL(fileURLWithPath: journal)))
        }
    }
    let inspection = try run(app + "/Contents/MacOS/StatBattAdapterGuardian", ["--inspect"], timeout: 8)
    try require(inspection.0 == 0)
    var timebase = mach_timebase_info_data_t()
    try require(mach_timebase_info(&timebase) == KERN_SUCCESS)
    let now = UInt64(Double(mach_continuous_time()) * Double(timebase.numer) / Double(timebase.denom))
    try validateInspection(inspection.1, now: now)
    // Recheck admission after read-only inspection, before Installer starts replacing files.
    try require(try run("/bin/launchctl", ["print", "system/dev.statbatt.control-daemon"]).0 == 113)
    try require(try run("/usr/bin/pgrep", ["-x", "StatBatt"]).0 == 1)
#if LOCAL_REMOVAL
    // Move the verified bundle aside atomically before deletion. Never recurse
    // through a caller-supplied location or delete shared parents/recovery state.
    let quarantine = "/Library/Application Support/StatBattLocal/.removing-" + UUID().uuidString
    try require(rename(app, quarantine) == 0)
    if try !absent(launcher) {
        try require(try FileManager.default.destinationOfSymbolicLink(atPath: launcher) == app)
        try require(unlink(launcher) == 0)
    }
    try FileManager.default.removeItem(atPath: quarantine)
    // Only remove the now-empty dedicated directory; unrelated contents prevent it.
    _ = rmdir("/Library/Application Support/StatBattLocal")
    print("Local StatBatt removed. User shortcuts, history, preferences and recovery records were preserved.")
#else
    print("Existing signed service is stopped and adapter restoration is verified; update admitted.")
#endif
} catch {
    fputs("StatBatt maintenance refused or incomplete. Quit StatBatt, verify restoration, and unregister its service before continuing. \(error)\n", stderr)
    exit(1)
}

#endif
