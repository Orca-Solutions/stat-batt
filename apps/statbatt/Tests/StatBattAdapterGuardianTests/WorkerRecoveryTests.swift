import Testing
import Foundation
import Darwin
@testable import StatBattAdapterGuardian

@Test func workerCannotArmWithoutOwnerOrWhileSleepingAndCannotRenew() {
    var gate = WorkerRecoveryGate()
    let ownerMissing = gate.begin(now: 1, ownerGone: true, sleeping: false)
    let sleeping = gate.begin(now: 1, ownerGone: false, sleeping: true)
    let accepted = gate.begin(now: 1, ownerGone: false, sleeping: false)
    let renewed = gate.begin(now: 2, ownerGone: false, sleeping: false)
    #expect(!ownerMissing && !sleeping && accepted && !renewed)
    #expect(gate.deadline == 2_000_000_001)
}

@Test func workerRestoresOnceOnDeadlineOwnerLossSleepOrHardwareFailure() {
    for cause in 0..<4 {
        var gate = WorkerRecoveryGate()
        let began = gate.begin(now: 0, ownerGone: false, sleeping: false)
        let early = gate.shouldRestore(now: 1, ownerGone: false, sleeping: false)
        let restore = gate.shouldRestore(now: cause == 0 ? 2_000_000_000 : 2,
                                        ownerGone: cause == 1, sleeping: cause == 2, hardwareFailed: cause == 3)
        let repeated = gate.shouldRestore(now: 3_000_000_000, ownerGone: true, sleeping: true)
        #expect(began && !early && restore && !repeated)
        #expect(gate.cause?.rawValue == ["deadline", "ownerEOF", "sleep", "hardwareFailure"][cause])
    }
}

@Test func privateOwnerPipeDeliversGateThenEOFToIndependentChild() throws {
    let child = Process(), control = Pipe(), output = Pipe()
    child.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    child.arguments = ["-I", "-c", "import os; print('READY', flush=True); gate=os.read(2,1); end=os.read(2,1); print('RESTORE' if gate==b'G' and end==b'' else 'BAD', flush=True)"]
    child.standardInput = FileHandle.nullDevice
    child.standardOutput = output
    child.standardError = control.fileHandleForReading
    try child.run()
    defer { if child.isRunning { child.terminate() }; child.waitUntilExit() }
    #expect(output.fileHandleForReading.readData(ofLength: 6) == Data("READY\n".utf8))
    try control.fileHandleForWriting.write(contentsOf: Data([0x47]))
    try control.fileHandleForWriting.close()
    let deadline = ContinuousClock.now + .seconds(2)
    while child.isRunning && ContinuousClock.now < deadline { Thread.sleep(forTimeInterval: 0.01) }
    #expect(!child.isRunning)
    let fd = output.fileHandleForReading.fileDescriptor
    _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
    var bytes = [UInt8](repeating: 0, count: 64)
    let count = read(fd, &bytes, bytes.count)
    #expect(count == 8 && String(decoding: bytes.prefix(max(0, count)), as: UTF8.self) == "RESTORE\n")
}
