import Foundation
import Darwin
import IOKit
import IOKit.pwr_mgt

private let sleepTrialEnabled = false

private final class SleepState {
    var connection: io_connect_t = 0
    var gate = SleepGate()
    var tokens: [Int] = []
    var requested = false
    var finished = false
    var pendingWillSleep = false
    func marker(_ text: String) { FileHandle.standardOutput.write(Data((text + "\n").utf8)) }
    func receive(_ message: UInt32, _ argument: UnsafeMutableRawPointer?) {
        let token = Int(bitPattern: argument)
        if message == 0xe0000270 { _ = IOAllowPowerChange(connection, token) }
        if message == 0xe0000280 {
            if !requested || finished || tokens.count >= 4 {
                _ = IOAllowPowerChange(connection, token)
                return
            }
            gate.willSleep(now: ProcessInfo.processInfo.systemUptime)
            tokens.append(token)
            pendingWillSleep = true
        }
    }
    func allow(_ decision: SleepGate.Decision) {
        guard decision != .wait else { return }
        var allAllowed = true
        for token in tokens { if IOAllowPowerChange(connection, token) != 0 { allAllowed = false } }
        tokens.removeAll()
        marker(decision == .allowVerified && allAllowed ? "ACK_RESTORED" : "ACK_UNKNOWN")
        finished = true
    }
}

private let sleepCallback: IOServiceInterestCallback = { context, _, message, argument in
    guard let context else { return }
    Unmanaged<SleepState>.fromOpaque(context).takeUnretainedValue().receive(message, argument)
}

@main enum SleepLabCommand {
    static func main() {
        guard sleepTrialEnabled, getuid() == 0, geteuid() == 0,
              Array(CommandLine.arguments.dropFirst()) == ["--approved-sleep-recovery-observer"] else {
            fputs("Source-only sleep lab; not enabled.\n", stderr); exit(64)
        }
        let state = SleepState()
        var port: IONotificationPortRef?
        var notifier: io_object_t = 0
        state.connection = IORegisterForSystemPower(Unmanaged.passUnretained(state).toOpaque(), &port, sleepCallback, &notifier)
        guard state.connection != 0, let port else { exit(1) }
        let source = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        defer {
            // Never strand a sleep acknowledgment on ordinary exit.
            if !state.tokens.isEmpty { state.allow(.allowUnknown) }
            IODeregisterForSystemPower(&notifier)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
            IOServiceClose(state.connection); IONotificationPortDestroy(port)
        }
        let initialFlags = fcntl(STDIN_FILENO, F_GETFL)
        guard initialFlags >= 0, fcntl(STDIN_FILENO, F_SETFL, initialFlags | O_NONBLOCK) == 0 else { exit(1) }
        state.marker("READY")
        let end = ProcessInfo.processInfo.systemUptime + 15
        while !state.finished && ProcessInfo.processInfo.systemUptime < end {
            CFRunLoopRunInMode(.defaultMode, 0.01, false)
            if state.pendingWillSleep {
                state.pendingWillSleep = false
                state.marker("WILL_SLEEP")
            }
            var byte: UInt8 = 0
            let count = read(STDIN_FILENO, &byte, 1)
            let gone = count == 0 || (count < 0 && errno != EAGAIN && errno != EINTR)
            if count == 1 && !state.requested {
                guard byte == 0x53 else { break }
                state.requested = true
                // Keep the notification run loop responsive even if the public sleep request blocks.
                DispatchQueue.global().async {
                    let root = IOPMFindPowerManagement(kIOMainPortDefault)
                    if root != 0 { _ = IOPMSleepSystem(root); IOServiceClose(root) }
                }
                state.marker("SLEEP_REQUESTED")
            } else {
                let decision = state.gate.poll(now: ProcessInfo.processInfo.systemUptime,
                                               reply: count == 1 ? byte : nil, ownerGone: gone)
                state.allow(decision)
                if gone { break }
            }
        }
        if !state.finished { state.marker("INCONCLUSIVE") }
    }
}
