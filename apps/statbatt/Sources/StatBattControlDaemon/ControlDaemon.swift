import Foundation
import Darwin
import StatBattControlProtocol

private final class StatusConnection: NSObject, ThermalCombinedService, @unchecked Sendable {
    private let runtime: ThermalRuntime
    private let id = UUID()
    private let uid: uid_t
    private let lock = NSLock()
    private var outstanding = false
    init(runtime: ThermalRuntime, uid: uid_t) { self.runtime = runtime; self.uid = uid }
    func getStatus(_ request: Data, reply: @escaping (Data?, NSError?) -> Void) {
        guard let data = try? ThermalStatusEndpoint.response(to: request) else {
            reply(nil, NSError(domain: ThermalServiceContract.machServiceName, code: 1)); return
        }
        let completion = Reply(reply)
        Task {
            // Older developer clients use this response before unregistering.
            // Never let a status-only compatibility response bypass ownership recovery.
            completion.send(await runtime.legacyRemovalSafe() ? data : nil)
        }
    }
    func perform(_ request: Data, reply: @escaping (Data?, NSError?) -> Void) {
        guard request.count <= 2048,
              let decoded = try? BoundedCodec().decode(ThermalControlRequest.self, from: request) else {
            reply(nil, NSError(domain: ThermalServiceContract.machServiceName, code: 1)); return
        }
        lock.lock()
        let accepted = !outstanding
        if accepted { outstanding = true }
        lock.unlock()
        guard accepted else { reply(nil, NSError(domain: ThermalServiceContract.machServiceName, code: 2)); return }
        let completion = Reply(reply)
        Task {
            let status = await runtime.perform(decoded, connection: id, uid: uid)
            let data = try? BoundedCodec().encode(status)
            finish()
            completion.send(data)
        }
    }
    private func finish() { lock.lock(); outstanding = false; lock.unlock() }
    func disconnected() { Task { await runtime.disconnected(id) } }
}
private final class Reply: @unchecked Sendable {
    let block: (Data?, NSError?) -> Void
    init(_ block: @escaping (Data?, NSError?) -> Void) { self.block = block }
    func send(_ data: Data?) { block(data, data == nil ? NSError(domain: ThermalServiceContract.machServiceName, code: 1) : nil) }
}
private final class StatusListener: NSObject, NSXPCListenerDelegate {
    private let peerRequirement: String
    private let runtime: ThermalRuntime
    init(peerRequirement: String, runtime: ThermalRuntime) { self.peerRequirement = peerRequirement; self.runtime = runtime }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let uid = connection.effectiveUserIdentifier
        guard uid != 0, ThermalRuntime.activeConsoleUser() == uid else { return false }
        connection.setCodeSigningRequirement(peerRequirement)
        let endpoint = StatusConnection(runtime: runtime, uid: uid)
        connection.exportedInterface = NSXPCInterface(with: ThermalCombinedService.self)
        connection.exportedObject = endpoint
        connection.invalidationHandler = { endpoint.disconnected() }
        connection.interruptionHandler = { endpoint.disconnected() }
        connection.activate()
        return true
    }
}

@main struct ControlDaemon {
    static func main() {
        guard CommandLine.arguments.count == 1, getuid() == 0, geteuid() == 0 else {
            FileHandle.standardError.write(Data("Control daemon requires launchd administrator identity and no arguments.\n".utf8)); exit(64)
        }
        do {
            let requirement = try ThermalServiceSigning.peerRequirement(
                ownIdentifier: ThermalServiceContract.daemonIdentifier,
                peerIdentifier: ThermalServiceContract.appIdentifier)
            let runtime = ThermalRuntime()
            let power = ThermalPowerObserver(runtime: runtime)
            guard power.start() else { exit(78) }
            let delegate = StatusListener(peerRequirement: requirement, runtime: runtime)
            let listener = NSXPCListener(machServiceName: ThermalServiceContract.machServiceName)
            listener.setConnectionCodeSigningRequirement(requirement)
            listener.delegate = delegate
            listener.activate()
            Task { await runtime.recover() }
            withExtendedLifetime((delegate, listener, power)) { dispatchMain() }
        } catch {
            FileHandle.standardError.write(Data("Control daemon requires a valid Apple-issued signature and matching product identity; listener not started.\n".utf8)); exit(78)
        }
    }
}
