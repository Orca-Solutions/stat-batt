import Foundation
import Testing
@testable import StatBattControlProtocol

@Test @MainActor func thermalRequestsWaitForReadAndNeverRetryMutation() async throws {
    let lane = ThermalRequestLane()
    var events: [String] = []
    var unblock: CheckedContinuation<Void, Never>?
    let read = Task { try await lane.perform {
        events.append("read")
        await withCheckedContinuation { unblock = $0 }
        events.append("readDone")
        return 1
    } }
    while unblock == nil { await Task.yield() }
    let mutation = Task { try await lane.perform { () throws -> Int in
        events.append("mutation")
        throw WireFailure(.malformedRequest)
    } }
    for _ in 0..<10 { await Task.yield() }
    #expect(events == ["read"])
    unblock?.resume()
    #expect(try await read.value == 1)
    do { _ = try await mutation.value; Issue.record("Expected one failed mutation") } catch { }
    #expect(events == ["read", "readDone", "mutation"])
    let status = try await lane.perform { events.append("status"); return 2 }
    #expect(status == 2)
    #expect(events.filter { $0 == "mutation" }.count == 1)
}

@Test func everyThermalActionRoundTripsBeforeDispatch() throws {
    let actions: [ThermalControlAction] = [.status, .heartbeat, .stop, .prepareNative, .finishNative, .prepareUninstall, .qualifyAdapterOneShot, .reconcileNative]
    for action in actions {
        let data = try BoundedCodec().encode(ThermalControlRequest(action: action))
        #expect(try BoundedCodec().decode(ThermalControlRequest.self, from: data).action == action)
    }
}
