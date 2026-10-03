import Foundation
import Darwin
import IOKit
import IOKit.pwr_mgt
import CStatBattAdapterControl
import StatBattAdapterBackend
import StatBattTelemetry
import StatBattDomain

private let guardianQualificationEnabled = false
private let guardianRecoveryEnabled = false
private let directory = "/Library/Application Support/StatBattAdapterGuardian"

func ignoreBrokenOutput() { sb_control_ignore_broken_output() }

private final class SleepState {
    var connection: io_connect_t = 0
    var tokens: [Int] = []
    var sleeping = false
    func event(_ message: UInt32, _ argument: UnsafeMutableRawPointer?) {
        if message == 0xe0000270 { _ = IOAllowPowerChange(connection, Int(bitPattern: argument)) }
        if message == 0xe0000280 {
            sleeping = true
            if tokens.count < 4 { tokens.append(Int(bitPattern: argument)) }
            else { _ = IOAllowPowerChange(connection, Int(bitPattern: argument)) }
        }
    }
    func acknowledge() { for token in tokens { _ = IOAllowPowerChange(connection, token) }; tokens.removeAll() }
}
private let callback: IOServiceInterestCallback = { context, _, message, argument in
    if let context { Unmanaged<SleepState>.fromOpaque(context).takeUnretainedValue().event(message, argument) }
}

private func emit(_ packet: AdapterPacket) {
    if let data = try? JSONEncoder().encode(packet) {
        var line = data; line.append(10)
        line.withUnsafeBytes { bytes in _ = Darwin.write(STDOUT_FILENO, bytes.baseAddress, bytes.count) }
    }
}

private func lockDirectory(sharedWorker: Bool = false) -> Int32 {
    for path in ["/Library", "/Library/Application Support"] {
        var info = stat()
        guard lstat(path, &info) == 0, info.st_uid == 0, info.st_mode & S_IFMT == S_IFDIR,
              info.st_mode & 0o022 == 0 else { return -1 }
    }
    let created = mkdir(directory, 0o700) == 0
    if !created && errno != EEXIST { return -1 }
    if created {
        let parent = open("/Library/Application Support", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { return -1 }
        let synced = fsync(parent) == 0; close(parent)
        guard synced else { return -1 }
    }
    let fd = open(directory, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
    var info = stat()
    guard fd >= 0, fstat(fd, &info) == 0, info.st_uid == 0, info.st_mode & 0o077 == 0 else { if fd >= 0 { close(fd) }; return -1 }
    if !sharedWorker && flock(fd, LOCK_EX | LOCK_NB) != 0 { close(fd); return -1 }
    // Separate writer lease survives guardian death. A new guardian must prove
    // no old worker holds it before launching any fresh writer.
    let lease = openat(fd, "writer.lock", O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC, 0o600)
    var leaseInfo = stat()
    guard lease >= 0, fstat(lease, &leaseInfo) == 0, leaseInfo.st_uid == 0,
          leaseInfo.st_mode & S_IFMT == S_IFREG, leaseInfo.st_mode & 0o077 == 0,
          flock(lease, (sharedWorker ? LOCK_SH : LOCK_EX) | LOCK_NB) == 0 else {
        if lease >= 0 { close(lease) }; close(fd); return -1
    }
    if sharedWorker { close(fd); return lease }
    close(lease)
    return fd
}

private func journal(_ directoryFD: Int32, operation: UUID, phase: String) -> Bool {
    let fd = openat(directoryFD, "intent.json", O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW | O_CLOEXEC, 0o600)
    guard fd >= 0 else { return false }
    defer { close(fd) }
    guard let data = try? JSONSerialization.data(withJSONObject: ["operation": operation.uuidString, "phase": phase,
        "continuousNanoseconds": SampleClock.nowNanoseconds()]) else { return false }
    let count = data.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
    return count == data.count && fsync(fd) == 0 && fsync(directoryFD) == 0
}

/// The root guardian's worker is the only process that calls the fixed hardware shim.
@main enum GuardianCommand {
    @MainActor static func main() throws {
        // Losing the daemon/output consumer must never terminate recovery.
        // This also applies to workers whose guardian disappears.
        ignoreBrokenOutput()
        guard getuid() == 0, geteuid() == 0,
              CommandLine.arguments.count == 2 else { exit(64) }
        let mode = CommandLine.arguments[1]
        let enabled = ["--cycle", "--worker-inhibit"].contains(mode) ? (guardianQualificationEnabled && guardianRecoveryEnabled) :
            ["--recover", "--worker-restore"].contains(mode) ? guardianRecoveryEnabled : ["--inspect", "--worker-inspect"].contains(mode)
        guard enabled else { exit(64) }
        guard ["--cycle", "--recover", "--inspect", "--worker-inhibit", "--worker-restore", "--worker-inspect"].contains(mode),
              let executable = Bundle.main.executableURL else { exit(64) }
        try AdapterExecutableIdentity.verify(url: executable, ownIdentifier: AdapterExecutableIdentity.identifier)
        let platform = PlatformProbe.readOnly()
        guard platform.model == "Mac16,13", platform.architecture == "arm64", platform.operatingSystemVersion == "27.0.1",
              platform.operatingSystemBuild == "26A434", platform.firmwareVersion == "mBoot-20457.1.29" else { exit(1) }
        if mode.hasPrefix("--worker-") { worker(mode); return }
        let fd = lockDirectory(); guard fd >= 0 else { exit(1) }; defer { close(fd) }
        var intentInfo = stat()
        let hasIntent = fstatat(fd, "intent.json", &intentInfo, AT_SYMLINK_NOFOLLOW) == 0
        if hasIntent && (intentInfo.st_uid != 0 || intentInfo.st_mode & S_IFMT != S_IFREG || intentInfo.st_mode & 0o077 != 0) { exit(1) }
        if mode == "--recover" && !hasIntent { exit(1) }
        if mode == "--cycle" && hasIntent {
            guard let saved = try? Data(contentsOf: URL(fileURLWithPath: directory + "/intent.json")),
                  saved.count <= 4096, let object = try? JSONSerialization.jsonObject(with: saved) as? [String: Any],
                  object["phase"] as? String == "restored" else { exit(1) }
        }
        let flags = fcntl(STDIN_FILENO, F_GETFL)
        guard flags >= 0, fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK) == 0 else { exit(1) }
        let outputFlags = fcntl(STDOUT_FILENO, F_GETFL)
        guard outputFlags >= 0, fcntl(STDOUT_FILENO, F_SETFL, outputFlags | O_NONBLOCK) == 0 else { exit(1) }
        if mode != "--cycle" {
            let result = runWorker(executable, mode == "--recover" ? "--worker-restore" : "--worker-inspect", seconds: 4)
            if var packet = result.packet {
                packet.reaped = result.reaped; emit(packet)
                if mode == "--recover", result.reaped, packet.outcome == 0, packet.key == 0, packet.adapter == true,
                   let saved = try? Data(contentsOf: URL(fileURLWithPath: directory + "/intent.json")), saved.count <= 4096,
                   let object = try? JSONSerialization.jsonObject(with: saved) as? [String: Any],
                   let string = object["operation"] as? String, let operation = UUID(uuidString: string) {
                    _ = journal(fd, operation: operation, phase: "restored")
                }
            }
            return
        }
        var input = Data()
        let inputDeadline = ContinuousClock.now + .seconds(1)
        while !input.contains(10) && input.count < 64 && ContinuousClock.now < inputDeadline {
            var bytes = [UInt8](repeating: 0, count: 64)
            let count = read(STDIN_FILENO, &bytes, bytes.count)
            if count == 0 { return }
            if count > 0 { input.append(contentsOf: bytes.prefix(count)) }
            CFRunLoopRunInMode(.defaultMode, 0.01, false)
        }
        guard let text = String(data: input, encoding: .utf8), let operation = UUID(uuidString: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              journal(fd, operation: operation, phase: "inhibitionIntent") else { exit(1) }
        let sleep = SleepState(); var port: IONotificationPortRef?; var notifier: io_object_t = 0
        sleep.connection = IORegisterForSystemPower(Unmanaged.passUnretained(sleep).toOpaque(), &port, callback, &notifier)
        guard sleep.connection != 0, let port else { exit(1) }
        let source = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        var assertion: UInt32 = 0
        guard sb_control_prevent_idle_sleep(&assertion) == 0 else { exit(1) }
        defer {
            sleep.acknowledge()
            _ = sb_control_release_idle_sleep(assertion)
            IODeregisterForSystemPower(&notifier)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
            IOServiceClose(sleep.connection); IONotificationPortDestroy(port)
        }
        // One writer and a nonrenewable two-second deadline. EOF/sleep shortens it.
        let inhibited = runWorker(executable, "--worker-inhibit", seconds: 2, stop: {
            var byte: UInt8 = 0
            let count = read(STDIN_FILENO, &byte, 1)
            return sleep.sleeping || count == 0 || count > 0
        }, report: { emit($0) })
        guard inhibited.reaped else { var packet = AdapterPacket(phase: "writerUnreapedUnknown"); packet.reaped = false; emit(packet); return }
        var reaped = AdapterPacket(phase: "writerReaped"); reaped.reaped = true; emit(reaped)
        // Failure to save recovery evidence must not suppress emergency restoration.
        _ = journal(fd, operation: operation, phase: "restorationIntent")
        let restored = runWorker(executable, "--worker-restore", seconds: 4)
        if var packet = restored.packet {
            packet.reaped = restored.reaped; emit(packet)
            if packet.outcome == 0 && packet.key == 0 && packet.adapter == true {
                _ = journal(fd, operation: operation, phase: "restored")
            }
        }
    }

    private static func runWorker(_ executable: URL, _ mode: String, seconds: Double,
                                  stop: () -> Bool = { false }, report: (AdapterPacket) -> Void = { _ in }) -> (packet: AdapterPacket?, reaped: Bool) {
        let process = Process(), output = Pipe()
        // Acquire BEFORE spawn and inherit as fd0: there is no launch-to-lock gap
        // in which a guardian crash could leave an untracked future writer.
        // Workers never read or close stdin. flock ownership survives dup/exec.
        let writerLease = lockDirectory(sharedWorker: true)
        guard writerLease >= 0 else { return (nil, true) }
        defer { close(writerLease) }
        process.executableURL = executable; process.arguments = [mode]
        process.environment = ["PATH": "/usr/bin:/bin", "HOME": "/var/root"]
        process.standardInput = FileHandle(fileDescriptor: writerLease, closeOnDealloc: false)
        process.standardOutput = output; process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return (nil, true) }
        let fd = output.fileHandleForReading.fileDescriptor
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        var data = Data(), packet: AdapterPacket?
        func drain() {
            var bytes = [UInt8](repeating: 0, count: 4096)
            let count = read(fd, &bytes, bytes.count)
            if count > 0 && data.count + count <= 16384 { data.append(contentsOf: bytes.prefix(count)) }
            while let newline = data.firstIndex(of: 10) {
                let line = data.prefix(upTo: newline); data.removeSubrange(...newline)
                if let decoded = try? JSONDecoder().decode(AdapterPacket.self, from: line) { packet = decoded; report(decoded) }
            }
        }
        let deadline = ContinuousClock.now + .milliseconds(Int(seconds * 1000))
        while process.isRunning && ContinuousClock.now < deadline && !stop() {
            drain(); CFRunLoopRunInMode(.defaultMode, 0.01, false)
        }
        if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        let reapDeadline = ContinuousClock.now + .seconds(1)
        while process.isRunning && ContinuousClock.now < reapDeadline { CFRunLoopRunInMode(.defaultMode, 0.01, false) }
        drain()
        return (packet, !process.isRunning)
    }

    @MainActor private static func worker(_ mode: String) {
        let lock = lockDirectory(sharedWorker: true)
        guard lock >= 0 else { return }
        defer { close(lock) }
        let reader = PublicTelemetry()
        let before = reader.snapshot(), now = SampleClock.nowNanoseconds()
        if mode == "--worker-inhibit" {
            guard before.batteryPresent.value == true, before.batteryPresent.isFresh(at: now, maximumAgeSeconds: 2),
                  before.supplyingSource.value == .adapter, before.supplyingSource.isFresh(at: now, maximumAgeSeconds: 2),
                  before.adapterAttached.value == true, before.adapterAttached.isFresh(at: now, maximumAgeSeconds: 2),
                  let soc = before.stateOfChargePercent.value, soc.isFinite, (50...100).contains(soc),
                  before.stateOfChargePercent.isFresh(at: now, maximumAgeSeconds: 2),
                  before.thermalPressure.value == .nominal, before.thermalPressure.isFresh(at: now, maximumAgeSeconds: 2) else { return }
        }
        let raw = sb_adapter_control(mode == "--worker-inhibit" ? 3 : mode == "--worker-restore" ? 4 : 0)
        var keyAt = SampleClock.nowNanoseconds()
        var key = mode == "--worker-inspect" ? raw.baseline_value : raw.readback_value
        var outcome = raw.outcome
        let end = ContinuousClock.now + .seconds(mode == "--worker-inhibit" ? 2 : mode == "--worker-restore" ? 3 : 0)
        repeat {
            let sample = reader.snapshot()
            var packet = AdapterPacket(phase: mode == "--worker-inhibit" ? "inhibited" : mode == "--worker-restore" ? "restored" : "inspection")
            packet.key = key; packet.outcome = outcome; packet.sampledAt = keyAt
            packet.sourceAt = sample.supplyingSource.sampledAtContinuousNanoseconds
            let observed = sample.supplyingSource.quality == .observed && sample.supplyingSource.isFresh(at: SampleClock.nowNanoseconds(), maximumAgeSeconds: 2, minimumSampleNanoseconds: keyAt)
            packet.adapter = observed && sample.supplyingSource.value == .adapter
            packet.battery = observed && sample.supplyingSource.value == .battery
            packet.temperatureCelsius = sample.batteryTemperatureCelsius.value
            packet.temperatureEstimated = sample.batteryTemperatureCelsius.quality == .estimated
            packet.stateOfCharge = sample.stateOfChargePercent.value
            emit(packet)
            if mode == "--worker-inspect" || raw.outcome != 0 || (mode == "--worker-restore" && packet.adapter == true) { break }
            CFRunLoopRunInMode(.defaultMode, 0.1, false)
            if mode == "--worker-inhibit" {
                let fresh = sb_adapter_control(0)
                key = fresh.baseline_value; outcome = fresh.outcome; keyAt = SampleClock.nowNanoseconds()
            }
        } while ContinuousClock.now < end
    }
}
