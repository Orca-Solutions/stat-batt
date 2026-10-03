import Foundation
import IOKit
import IOKit.pwr_mgt
import StatBattDomain
import StatBattTelemetry

/// Callback and run loop use the same thread. Acknowledgment always precedes output.
final class PowerObservation {
    var connection: io_connect_t = 0
    var woke = false
    var events = 0
    var pending: [[String: Any]] = []
    var droppedEvents = 0
    var acknowledge: (io_connect_t, Int) -> IOReturn = { IOAllowPowerChange($0, $1) }

    func receive(_ message: UInt32, argument: UnsafeMutableRawPointer?) {
        let name: String
        let needsAck: Bool
        // IOMessage.h iokit_common_msg constants; C function-like macros are not imported by Swift.
        switch message {
        case 0xe0000270: name = "canSystemSleep"; needsAck = true
        case 0xe0000280: name = "systemWillSleep"; needsAck = true
        case 0xe0000320: name = "systemWillPowerOn"; needsAck = false
        case 0xe0000300: name = "systemHasPoweredOn"; needsAck = false; woke = true
        case 0xe0000290: name = "systemWillNotSleep"; needsAck = false
        default: return
        }
        // Token is intentionally never logged. Never veto or defer system sleep.
        let ack = needsAck ? acknowledge(connection, Int(bitPattern: argument)) : nil
        events += 1
        guard pending.count < 64 else { droppedEvents += 1; return }
        pending.append(["kind": "powerEvent", "event": name, "timestampUTC": ISO8601DateFormatter().string(from: Date()),
              "continuousNanoseconds": SampleClock.nowNanoseconds(), "acknowledgmentRequired": needsAck,
              "acknowledgmentReturn": ack.map { NSNumber(value: $0) } ?? NSNull()])
    }

    func emit(_ object: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) {
            FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data("\n".utf8))
        }
    }
}

// Not actor-isolated: IOKit invokes this on the run loop where its source is installed.
private let powerObservationCallback: IOServiceInterestCallback = { context, _, message, argument in
    guard let context else { return }
    Unmanaged<PowerObservation>.fromOpaque(context).takeUnretainedValue().receive(message, argument: argument)
}

enum SleepWakeObserver {
    @MainActor static func run(reader: PublicTelemetry) throws {
        let state = PowerObservation()
        var port: IONotificationPortRef?
        var notifier: io_object_t = 0
        state.connection = IORegisterForSystemPower(Unmanaged.passUnretained(state).toOpaque(), &port,
                                                    powerObservationCallback, &notifier)
        guard state.connection != 0, let port else {
            throw NSError(domain: "StatBattSleepObservation", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Power notification registration failed"])
        }
        let loop = CFRunLoopGetCurrent()
        let source = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(loop, source, .defaultMode)
        defer {
            IODeregisterForSystemPower(&notifier)
            CFRunLoopRemoveSource(loop, source, .defaultMode)
            IOServiceClose(state.connection)
            IONotificationPortDestroy(port)
        }
        let deadline = SampleClock.nowNanoseconds() + 120_000_000_000
        state.emit(["kind": "ready", "durationSecondsIncludingSleep": 120,
                    "note": "No sleep request, assertion, or charging write. Timeout checked when this process can run."])
        repeat {
            CFRunLoopRunInMode(.defaultMode, 0.1, false)
            let pending = state.pending
            state.pending.removeAll(keepingCapacity: true)
            for event in pending { state.emit(event) }
            if state.woke {
                state.woke = false
                let snapshot = reader.snapshot()
                state.emit(["kind": "postWakeTelemetry", "continuousNanoseconds": SampleClock.nowNanoseconds(),
                            "source": snapshot.supplyingSource.value.map { String(describing: $0) } ?? "unavailable",
                            "sourceQuality": String(describing: snapshot.supplyingSource.quality),
                            "sourceSampleNanoseconds": snapshot.supplyingSource.sampledAtContinuousNanoseconds,
                            "temperatureCelsius": snapshot.batteryTemperatureCelsius.value.map { NSNumber(value: $0) } ?? NSNull(),
                            "temperatureQuality": String(describing: snapshot.batteryTemperatureCelsius.quality)])
            }
        } while SampleClock.nowNanoseconds() < deadline
        state.emit(["kind": "completed", "eventCount": state.events, "droppedEventCount": state.droppedEvents,
                    "note": "No events means unexercised, not a successful sleep recovery test."])
    }
}
