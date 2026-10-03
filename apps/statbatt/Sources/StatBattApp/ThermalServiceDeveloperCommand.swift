import Foundation
import ServiceManagement
import StatBattControlProtocol
import Darwin

/// Explicit development commands only. Normal launches never register a service.
@MainActor enum ThermalServiceDeveloperCommand {
    static func runIfRequested() {
        let args = Array(CommandLine.arguments.dropFirst())
        let flags = ["--thermal-service-status", "--thermal-service-register", "--thermal-service-unregister"]
        guard args.contains(where: flags.contains) else { return }
        guard args.count == 1, flags.contains(args[0]), getuid() != 0, geteuid() != 0 else { exit(64) }
        do {
            let requirement = try ThermalServiceSigning.peerRequirement(
                ownIdentifier: ThermalServiceContract.appIdentifier,
                peerIdentifier: ThermalServiceContract.daemonIdentifier)
            let service = SMAppService.daemon(plistName: ThermalServiceContract.daemonPlistName)
            switch args[0] {
            case "--thermal-service-register":
                let plist = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchDaemons/" + ThermalServiceContract.daemonPlistName)
                guard FileManager.default.fileExists(atPath: plist.path) else { throw CommandFailure.missingBundle }
                do { try service.register() }
                catch {
                    // Some OS versions create the approval record but return EPERM.
                    // Consult SMAppService instead of treating that as no registration.
                    guard service.status == .requiresApproval else { throw error }
                }
                if service.status == .requiresApproval {
                    print("Status-only service is waiting for approval in System Settings → General → Login Items & Extensions. Charging control remains disabled.")
                } else if service.status == .enabled {
                    print("Status-only service registered and enabled. Charging control remains disabled.")
                } else {
                    throw CommandFailure.registrationIncomplete
                }
            case "--thermal-service-unregister":
                // Refuse to remove a future actuating service using this bootstrap command.
                _ = try status(requirement: requirement)
                try service.unregister()
                print("Status-only service unregistered.")
            default:
                let response = try status(requirement: requirement)
                print(String(decoding: try BoundedCodec().encode(response), as: UTF8.self))
            }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("Thermal service development check failed: \(error). No charging command exists in this bootstrap.\n".utf8))
            exit(1)
        }
    }

    private enum CommandFailure: Error { case missingBundle, timeout, connection, invalidReply, registrationIncomplete }
    private final class ReplyBox: @unchecked Sendable {
        private let lock = NSLock()
        private var result: Result<Data, Error>?
        func complete(_ value: Result<Data, Error>) { lock.lock(); defer { lock.unlock() }; if result == nil { result = value } }
        func read() -> Result<Data, Error>? { lock.lock(); defer { lock.unlock() }; return result }
    }
    // XPC replies run on its own queue; do not inherit MainActor isolation.
    nonisolated private static func status(requirement: String) throws -> ThermalStatusResponse {
        let connection = NSXPCConnection(machServiceName: ThermalServiceContract.machServiceName, options: .privileged)
        connection.setCodeSigningRequirement(requirement)
        connection.remoteObjectInterface = NSXPCInterface(with: ThermalStatusService.self)
        let box = ReplyBox()
        connection.interruptionHandler = { box.complete(.failure(CommandFailure.connection)) }
        connection.invalidationHandler = { box.complete(.failure(CommandFailure.connection)) }
        connection.activate()
        defer { connection.invalidate() }
        guard let remote = connection.remoteObjectProxyWithErrorHandler({ box.complete(.failure($0)) }) as? ThermalStatusService else {
            throw CommandFailure.connection
        }
        remote.getStatus(try BoundedCodec().encode(ThermalStatusRequest())) { data, error in
            if let error { box.complete(.failure(error)) }
            else if let data { box.complete(.success(data)) }
            else { box.complete(.failure(CommandFailure.invalidReply)) }
        }
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while box.read() == nil && ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        guard let result = box.read() else { throw CommandFailure.timeout }
        return try BoundedCodec().decode(ThermalStatusResponse.self, from: result.get())
    }
}
