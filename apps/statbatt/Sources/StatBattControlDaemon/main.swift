import Foundation
import Darwin
import StatBattControlProtocol

/// A root status-only service. No telemetry, SMC, shell execution or policy dependencies.
private final class StatusConnection: NSObject, ThermalStatusService {
    func getStatus(_ request: Data, reply: @escaping (Data?, NSError?) -> Void) {
        do { reply(try ThermalStatusEndpoint.response(to: request), nil) }
        catch { reply(nil, NSError(domain: ThermalServiceContract.machServiceName, code: 1)) }
    }
}

private final class StatusListener: NSObject, NSXPCListenerDelegate {
    private let peerRequirement: String
    init(peerRequirement: String) { self.peerRequirement = peerRequirement }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // Code requirements authenticate the peer before any request is decoded. This
        // bootstrap has no enrollment/control authority; those must be added separately.
        guard connection.effectiveUserIdentifier != 0 else { return false }
        connection.setCodeSigningRequirement(peerRequirement)
        connection.exportedInterface = NSXPCInterface(with: ThermalStatusService.self)
        connection.exportedObject = StatusConnection()
        connection.activate()
        return true
    }
}

@main struct ControlDaemon {
    static func main() {
        guard CommandLine.arguments.count == 1, getuid() == 0, geteuid() == 0 else {
            FileHandle.standardError.write(Data("Status daemon requires launchd administrator identity and no arguments.\n".utf8))
            exit(64)
        }
        do {
            let requirement = try ThermalServiceSigning.peerRequirement(
                ownIdentifier: ThermalServiceContract.daemonIdentifier,
                peerIdentifier: ThermalServiceContract.appIdentifier)
            let delegate = StatusListener(peerRequirement: requirement)
            let listener = NSXPCListener(machServiceName: ThermalServiceContract.machServiceName)
            listener.setConnectionCodeSigningRequirement(requirement)
            listener.delegate = delegate
            listener.activate()
            withExtendedLifetime((delegate, listener)) { dispatchMain() }
        } catch {
            FileHandle.standardError.write(Data("Status daemon requires a valid Apple-issued signature and matching product identity; listener not started.\n".utf8))
            exit(78)
        }
    }
}
