import Foundation
import Darwin

/// The redacted local read-only format check on2026-10-02 verified NAME (UUID) for every
/// returned row. Unknown/malformed formats fail closed instead of guessing an execution ID.
public enum ShortcutListingParser {
    public static func parse(_ data: Data) throws -> [NativeShortcutIdentity] {
        guard data.count <= 65_536 else { throw NativeLimitFailure.outputTooLarge }
        guard let text = String(data: data, encoding: .utf8) else { throw NativeLimitFailure.malformedListing }
        var result: [NativeShortcutIdentity] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.hasSuffix("\r") ? String(rawLine.dropLast()) : String(rawLine)
            guard line.count > 39, line.utf8.count <= 2_048 else { throw NativeLimitFailure.malformedListing }
            let suffix = line.suffix(39)
            guard suffix.hasPrefix(" ("), suffix.hasSuffix(")"),
                  let id = UUID(uuidString: String(suffix.dropFirst(2).dropLast())) else { throw NativeLimitFailure.malformedListing }
            let name = String(line.dropLast(39))
            guard !name.isEmpty, !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw NativeLimitFailure.malformedListing
            }
            result.append(NativeShortcutIdentity(id: id, name: name))
            guard result.count <= 512 else { throw NativeLimitFailure.outputTooLarge }
        }
        guard Set(result.map(\.id)).count == result.count else { throw NativeLimitFailure.shortcutAmbiguous }
        return result
    }
}

public struct ShortcutsProcessTransport: NativeShortcutTransport {
    public init() {}
    public func listShortcuts() async throws -> [NativeShortcutIdentity] {
        let result = await executeFixedJob(.list)
        switch result.end {
        case .exited(0): return try ShortcutListingParser.parse(result.stdout)
        case .outputOverflow: throw NativeLimitFailure.outputTooLarge
        default: throw NativeLimitFailure.transportUnavailable
        }
    }
    public func executeTrusted(_ shortcut: TrustedNativeShortcut) async -> NativeExecutionResult {
        let result = await executeFixedJob(.nativeLimit(shortcut.id))
        return executionResult(result.end)
    }
}

private func executionResult(_ end: ProcessEnd) -> NativeExecutionResult {
        switch end {
        case .exited(0): return .acknowledged
        case .exited: return .failed
        case .timedOut: return .timedOut
        case .cancelled: return .cancelled
        case .outputOverflow: return .outputOverflow
        case .notLaunched: return .notLaunched
        }
}

/// Fixed read-only known-controller check. Absence is accepted only for the observed launchctl
/// no-such-service exit/signature. Other errors are unavailable, never evidence of absence.
public enum NativeKnownControllerProbe {
    public static func check() async -> NativePreflightResult {
        let result = await executeFixedJob(.energizaProbe)
        switch result.end {
        case .exited(let code): return classify(exitCode: code, stderr: result.stderr)
        default: return .unavailable
        }
    }
    static func classify(exitCode: Int32, stderr: Data) -> NativePreflightResult {
        if exitCode == 0 { return .conflictingController }
        guard exitCode == 113, let text = String(data: stderr, encoding: .utf8), text.contains("Could not find service") else { return .unavailable }
        return .clear
    }
}

private enum FixedNativeJob: Sendable {
    case list
    case nativeLimit(UUID)
    case energizaProbe
    #if DEBUG
    case testFixture(NativeProcessFixture, timeout: Double)
    #endif
    var executable: URL {
        #if DEBUG
        if case .testFixture(let fixture, _) = self { return URL(fileURLWithPath: fixture.executable) }
        #endif
        return URL(fileURLWithPath: self.isProbe ? "/bin/launchctl" : "/usr/bin/shortcuts")
    }
    private var isProbe: Bool { if case .energizaProbe = self { return true }; return false }
    var arguments: [String] {
        switch self {
        case .list: return ["list", "--show-identifiers"]
        case .nativeLimit(let id): return ["run", id.uuidString]
        case .energizaProbe: return ["print", "system/de.appgineers.energiza.helper"]
        #if DEBUG
        case .testFixture(let fixture, _): return fixture.arguments
        #endif
        }
    }
    var timeoutSeconds: Double {
        #if DEBUG
        if case .testFixture(_, let timeout) = self { return timeout }
        #endif
        return 20
    }
}
private enum ProcessEnd: Sendable { case exited(Int32), timedOut, cancelled, outputOverflow, notLaunched }
private struct BoundedProcessResult: Sendable {
    let end: ProcessEnd
    let stdout: Data
    let stderr: Data
    let launched: Bool
    let processID: Int32?
}

private func executeFixedJob(_ job: FixedNativeJob, didLaunch: (@Sendable () -> Void)? = nil) async -> BoundedProcessResult {
    let invocation = NativeProcessInvocation(job: job, didLaunch: didLaunch)
    return await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in invocation.start(continuation) }
    } onCancel: {
        invocation.cancel()
    }
}

/// All mutable state belongs to queue. Pipes are drained while the process runs; neither
/// waitUntilExit nor a blocking pipe read is performed on an actor/main thread.
private final class NativeProcessInvocation: @unchecked Sendable {
    private let queue = DispatchQueue(label: "StatBatt.native-process", qos: .utility)
    private let process = Process()
    private let output = Pipe()
    private let errors = Pipe()
    private let job: FixedNativeJob
    private let didLaunch: (@Sendable () -> Void)?
    private var continuation: CheckedContinuation<BoundedProcessResult, Never>?
    private var outputSource: DispatchSourceRead?
    private var errorSource: DispatchSourceRead?
    private var timer: DispatchWorkItem?
    private var stdout = Data()
    private var stderr = Data()
    private var outputClosed = false
    private var errorClosed = false
    private var exited: Int32?
    private var finished = false
    private var cancelled = false
    private var launched = false
    private var stopReason: ProcessEnd?
    private var outputSuspended = false
    private var errorSuspended = false

    init(job: FixedNativeJob, didLaunch: (@Sendable () -> Void)?) { self.job = job; self.didLaunch = didLaunch }
    func start(_ continuation: CheckedContinuation<BoundedProcessResult, Never>) {
        queue.async { [self] in
            self.continuation = continuation
            if cancelled { finish(.cancelled); return }
            process.executableURL = job.executable
            process.arguments = job.arguments
            process.standardInput = FileHandle.nullDevice
            process.standardOutput = output
            process.standardError = errors
            // Retain the invocation through the child's termination/reaping observation.
            process.terminationHandler = { [self] process in
                let code = process.terminationStatus
                self.queue.async { [self] in self.exited = code; self.finishIfDrained() }
            }
            do {
                try process.run()
                launched = true
                didLaunch?()
                // Closing the parent's writers is necessary for an observable EOF.
                try? output.fileHandleForWriting.close()
                try? errors.fileHandleForWriting.close()
                outputSource = makeReader(output.fileHandleForReading, standardError: false)
                errorSource = makeReader(errors.fileHandleForReading, standardError: true)
                let work = DispatchWorkItem { [self] in
                    guard !finished else { return }
                    stopProcess(reason: .timedOut)
                }
                timer = work
                queue.asyncAfter(deadline: .now() + job.timeoutSeconds, execute: work)
            } catch {
                finish(.notLaunched)
            }
        }
    }

    func cancel() {
        queue.async { [self] in
            cancelled = true
            guard continuation != nil, !finished else { return }
            stopProcess(reason: .cancelled)
        }
    }

    private func makeReader(_ handle: FileHandle, standardError: Bool) -> DispatchSourceRead {
        let fd = handle.fileDescriptor
        let flags = fcntl(fd, F_GETFL)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.drain(fd, standardError: standardError) }
        source.setCancelHandler { try? handle.close() }
        source.resume()
        return source
    }

    private func drain(_ fd: Int32, standardError: Bool) {
        guard !finished, stopReason == nil else { return }
        var buffer = [UInt8](repeating: 0, count: 8_192)
        while !finished {
            let count = read(fd, &buffer, buffer.count)
            if count > 0 {
                let existing = standardError ? stderr.count : stdout.count
                guard existing + count <= 65_536 else {
                    stopProcess(reason: .outputOverflow); return
                }
                if standardError { stderr.append(contentsOf: buffer.prefix(count)) }
                else { stdout.append(contentsOf: buffer.prefix(count)) }
            } else if count == 0 {
                if standardError { errorClosed = true; errorSource?.cancel() }
                else { outputClosed = true; outputSource?.cancel() }
                finishIfDrained()
                return
            } else if errno == EINTR {
                continue
            } else if errno == EAGAIN || errno == EWOULDBLOCK {
                return
            } else {
                stopProcess(reason: .outputOverflow); return
            }
        }
    }

    private func finishIfDrained() {
        guard let exited else { return }
        if let stopReason {
            // A stopped caller's descendants may retain pipe writers. Once our child is reaped,
            // close the bounded pipes without waiting forever for those unrelated writers.
            finish(stopReason)
        } else if outputClosed, errorClosed {
            finish(.exited(exited))
        }
    }
    private func stopProcess(reason: ProcessEnd) {
        guard !finished else { return }
        if stopReason == nil {
            stopReason = reason
            if let outputSource, !outputClosed { outputSource.suspend(); outputSuspended = true }
            if let errorSource, !errorClosed { errorSource.suspend(); errorSuspended = true }
        }
        if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
        finishIfDrained()
        // Never resume before termination/reaping is observed. The library action can still
        // outlive this CLI; its effect remains unknown and requires manual reconciliation.
    }
    private func finish(_ end: ProcessEnd) {
        guard !finished, let continuation else { return }
        finished = true
        timer?.cancel(); timer = nil
        if outputSuspended { outputSource?.resume(); outputSuspended = false }
        if errorSuspended { errorSource?.resume(); errorSuspended = false }
        outputSource?.cancel(); errorSource?.cancel()
        if outputSource == nil { try? output.fileHandleForReading.close() }
        if errorSource == nil { try? errors.fileHandleForReading.close() }
        try? output.fileHandleForWriting.close(); try? errors.fileHandleForWriting.close()
        self.continuation = nil
        process.terminationHandler = nil
        continuation.resume(returning: BoundedProcessResult(end: end, stdout: stdout, stderr: stderr,
            launched: launched, processID: launched ? process.processIdentifier : nil))
    }
}

#if DEBUG
/// Closed, internal test fixtures only; absent from release builds. Tests exercise the actual
/// pipe/deadline/cancellation implementation without touching Shortcuts or charging controls.
enum NativeProcessFixture: Sendable {
    case bothStreams, excessiveOutput, sleeping, failureExit, ignoresTermination, ignoresTerminationAndOverflows
    var executable: String {
        switch self {
        case .bothStreams, .ignoresTermination, .ignoresTerminationAndOverflows: return "/bin/sh"
        case .excessiveOutput: return "/usr/bin/yes"
        case .sleeping: return "/bin/sleep"
        case .failureExit: return "/usr/bin/false"
        }
    }
    var arguments: [String] {
        switch self {
        case .bothStreams: return ["-c", "i=0; while [ \"$i\" -lt 1000 ]; do printf 'synthetic stdout\\n'; printf 'synthetic stderr\\n' >&2; i=$((i+1)); done"]
        case .excessiveOutput: return ["synthetic"]
        case .sleeping: return ["30"]
        case .failureExit: return []
        case .ignoresTermination: return ["-c", "trap '' TERM; printf 'ready\\n'; while :; do :; done"]
        case .ignoresTerminationAndOverflows: return ["-c", "trap '' TERM; while :; do printf 'synthetic overflow data\\n'; done"]
        }
    }
}
struct NativeProcessFixtureResult: Sendable {
    let result: NativeExecutionResult
    let stdoutBytes: Int
    let stderrBytes: Int
    let launched: Bool
    let processID: Int32?
}
enum NativeProcessTestHarness {
    static func run(_ fixture: NativeProcessFixture, timeoutSeconds: Double = 3,
                    didLaunch: (@Sendable () -> Void)? = nil) async -> NativeProcessFixtureResult {
        let result = await executeFixedJob(.testFixture(fixture, timeout: timeoutSeconds), didLaunch: didLaunch)
        return NativeProcessFixtureResult(result: executionResult(result.end), stdoutBytes: result.stdout.count,
            stderrBytes: result.stderr.count, launched: result.launched, processID: result.processID)
    }
}
#endif
