import Foundation
import Darwin
import Testing
@testable import StatBattNativeLimit

private actor LaunchGate {
    private var launched = false
    private var waiter: CheckedContinuation<Void, Never>?
    func signal() { launched = true; waiter?.resume(); waiter = nil }
    func wait() async {
        if launched { return }
        await withCheckedContinuation { waiter = $0 }
    }
}

@Test func subprocessBothPipesDrainWithoutDeadlock() async {
    let result = await NativeProcessTestHarness.run(.bothStreams)
    #expect(result.launched)
    #expect(result.result == .acknowledged)
    #expect(result.stdoutBytes == 17_000)
    #expect(result.stderrBytes == 17_000)
}

@Test func subprocessOutputOverflowTerminatesWithBoundedBuffers() async {
    let result = await NativeProcessTestHarness.run(.excessiveOutput)
    #expect(result.launched)
    #expect(result.result == .outputOverflow)
    #expect(result.stdoutBytes <= 65_536)
    #expect(result.stderrBytes <= 65_536)
    assertChildGone(result)
}

@Test func subprocessDeadlineBoundsUnresponsiveInvocation() async {
    let start = Date()
    let result = await NativeProcessTestHarness.run(.sleeping, timeoutSeconds: 0.1)
    #expect(result.launched)
    #expect(result.result == .timedOut)
    #expect(Date().timeIntervalSince(start) < 5)
    assertChildGone(result)
}

@Test func subprocessCancellationAfterLaunchDoesNotReportSuccess() async {
    let gate = LaunchGate()
    let task = Task { await NativeProcessTestHarness.run(.sleeping, didLaunch: { Task { await gate.signal() } }) }
    await gate.wait()
    task.cancel()
    let result = await task.value
    #expect(result.launched)
    #expect(result.result == .cancelled)
    assertChildGone(result)
}

private func assertChildGone(_ result: NativeProcessFixtureResult) {
    guard let pid = result.processID else { Issue.record("No owned test child PID recorded"); return }
    let signalResult = kill(pid, 0)
    let signalError = errno
    #expect(signalResult == -1)
    #expect(signalError == ESRCH)
}

@Test func termIgnoringFixtureIsGoneBeforeTimeoutReceipt() async {
    let result = await NativeProcessTestHarness.run(.ignoresTermination, timeoutSeconds: 0.1)
    #expect(result.result == .timedOut)
    #expect(result.stdoutBytes > 0)
    assertChildGone(result)
}

@Test func termIgnoringFixtureIsGoneBeforeCancellationReceipt() async throws {
    let gate = LaunchGate()
    let task = Task { await NativeProcessTestHarness.run(.ignoresTermination, didLaunch: { Task { await gate.signal() } }) }
    await gate.wait()
    // Allow the fixed script to install its SIGTERM handler; no hardware process is launched.
    try await Task.sleep(for: .milliseconds(50))
    task.cancel()
    let result = await task.value
    #expect(result.result == .cancelled)
    #expect(result.stdoutBytes > 0)
    assertChildGone(result)
}

@Test func termIgnoringFixtureIsGoneBeforeOverflowReceipt() async {
    let result = await NativeProcessTestHarness.run(.ignoresTerminationAndOverflows)
    #expect(result.result == .outputOverflow)
    #expect(result.stdoutBytes <= 65_536)
    assertChildGone(result)
}

@Test func subprocessNonzeroExitIsAnUnknownControlOutcome() async {
    let result = await NativeProcessTestHarness.run(.failureExit)
    #expect(result.launched)
    #expect(result.result == .failed)
}
