import AppKit
import Combine
import Foundation
import ServiceManagement
import StatBattControlProtocol
import StatBattDomain

/// The app never writes hardware. Only authenticated daemon replies establish
/// active or restored state; a lost reply preserves recovery uncertainty.
@MainActor final class ThermalUIModel: ObservableObject {
    @Published private(set) var status: ThermalControlStatus?
    @Published private(set) var busy = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var serviceStatus = SMAppService.Status.notRegistered
    @Published var disconnectAt: Double = 40 { didSet { normalizeAndSave() } }
    @Published var reconnectAt: Double = 37 { didSet { normalizeAndSave() } }
    @Published private(set) var nativeBlocked = false
    private var connection: NSXPCConnection?
    private var connectionID: UUID?
    private var monitor: Task<Void, Never>?
    private var pending: [UUID: CheckedContinuation<ThermalControlStatus, Error>] = [:]
    private var deadlines: [UUID: Task<Void, Never>] = [:]
    private var normalizing = false
    private var commandEpoch: UInt64 = 0
    private let uncertaintyKey = "thermalUnresolvedRequest"
    private var uncertain: Bool {
        get { UserDefaults.standard.bool(forKey: uncertaintyKey) }
        set { UserDefaults.standard.set(newValue, forKey: uncertaintyKey); objectWillChange.send() }
    }
    init() {
        let defaults = UserDefaults.standard
        let upper = defaults.double(forKey: "thermalDisconnectCelsius")
        let lower = defaults.double(forKey: "thermalReconnectCelsius")
        if upper.isFinite && lower.isFinite && (35...50).contains(upper) && (25...(upper - 3)).contains(lower) {
            disconnectAt = upper; reconnectAt = lower
        }
        serviceStatus = SMAppService.daemon(plistName: ThermalServiceContract.daemonPlistName).status
    }
    var active: Bool { status?.phase == .watching || status?.phase == .paused }
    var recoveryPending: Bool { uncertain || status?.phase == .restoring || status?.phase == .recoveryRequired }
    var needsServiceSetup: Bool { serviceStatus != .enabled }
    var awaitingApproval: Bool { serviceStatus == .requiresApproval }
    var canStart: Bool { status?.controlAvailable == true && !active && !recoveryPending && !busy && !nativeBlocked && serviceStatus == .enabled }
    var temperature: Double? { status?.temperatureCelsius }
    var estimatedTemperature: Bool { status?.estimatedTemperature ?? true }
    var phaseLabel: String {
        guard let status else { return recoveryPending ? "Recovery not confirmed" : "Off" }
        switch status.phase {
        case .unavailable: return "Not available on this build"
        case .off: return "Off"
        case .watching: return "Watching temperature"
        case .paused: return "Using battery power"
        case .qualifying: return "Testing adapter recovery…"
        case .restoring: return "Restoring adapter input…"
        case .recoveryRequired: return "Recovery needs attention"
        }
    }
    var statusMessage: String { status?.message ?? "Check the background service to see whether this Mac is qualified. The Apple 80% and 100% buttons work independently." }
    private func normalizeAndSave() {
        guard !normalizing else { return }
        normalizing = true
        disconnectAt = disconnectAt.isFinite ? min(50, max(35, disconnectAt)) : 40
        reconnectAt = reconnectAt.isFinite ? min(disconnectAt - 3, max(25, reconnectAt)) : 37
        UserDefaults.standard.set(disconnectAt, forKey: "thermalDisconnectCelsius")
        UserDefaults.standard.set(reconnectAt, forKey: "thermalReconnectCelsius")
        normalizing = false
    }
    func beginMonitoring() {
        guard monitor == nil else { return }
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if !self.busy && self.pending.isEmpty { await self.refresh() }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
    func refreshFromUI() { Task { await refresh() } }
    private func refresh() async {
        serviceStatus = SMAppService.daemon(plistName: ThermalServiceContract.daemonPlistName).status
        guard serviceStatus == .enabled else { return }
        let epoch = commandEpoch
        do {
            let reply = try await call(active ? .heartbeat : .status)
            if epoch == commandEpoch { accept(reply) }
        }
        catch { errorMessage = "Background service could not be reached. Active control or restoration is not confirmed." }
    }
    func setupService() {
        if awaitingApproval { SMAppService.openSystemSettingsLoginItems(); return }
        busy = true; errorMessage = nil
        defer { busy = false }
        do {
            _ = try ThermalServiceSigning.peerRequirement(ownIdentifier: ThermalServiceContract.appIdentifier, peerIdentifier: ThermalServiceContract.daemonIdentifier)
            let plist = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchDaemons/" + ThermalServiceContract.daemonPlistName)
            guard FileManager.default.fileExists(atPath: plist.path) else { throw ClientError.missingBundle }
            let service = SMAppService.daemon(plistName: ThermalServiceContract.daemonPlistName)
            do { try service.register() } catch { guard service.status == .requiresApproval else { throw error } }
            serviceStatus = service.status
            if awaitingApproval { SMAppService.openSystemSettingsLoginItems() }
            beginMonitoring()
        } catch { errorMessage = "Could not set up the background service. Use the complete signed local StatBatt package." }
    }
    func startFromUI() {
        guard canStart else { return }
        busy = true; errorMessage = nil
        commandEpoch &+= 1
        let epoch = commandEpoch
        // This is uncertainty evidence, not a saved enabled preference.
        uncertain = true
        Task {
            defer { busy = false }
            do {
                let policy = ThermalAdapterPolicy(enabled: true, disconnectAtCelsius: disconnectAt,
                    reconnectAtCelsius: reconnectAt, reservePercent: 30, maximumPauseSeconds: 2, cooldownSeconds: 60)
                let reply = try await call(.start, policy: policy)
                guard epoch == commandEpoch else { return }
                accept(reply)
                if !active { errorMessage = reply.message }
            } catch { errorMessage = "The start request was not confirmed. Stop and restore before trying again." }
        }
    }
    func qualifyFromUI() {
        guard status?.qualificationAvailable == true, !busy, !nativeBlocked, !recoveryPending else { return }
        busy = true; uncertain = true; errorMessage = nil
        commandEpoch &+= 1
        let epoch = commandEpoch
        Task {
            defer { busy = false }
            do {
                let reply = try await call(.qualifyAdapterOneShot)
                if epoch == commandEpoch { accept(reply) }
            } catch { errorMessage = "The adapter test outcome is not confirmed. Stop and restore before continuing." }
        }
    }
    func stopFromUI() { Task { _ = await stopAndVerify() } }
    func stopAndVerify() async -> Bool {
        serviceStatus = SMAppService.daemon(plistName: ThermalServiceContract.daemonPlistName).status
        if serviceStatus != .enabled && !uncertain && !active { return true }
        busy = true
        commandEpoch &+= 1
        let epoch = commandEpoch
        defer { busy = false }
        do {
            let reply = try await call(.stop)
            guard epoch == commandEpoch else { return false }
            accept(reply)
            guard reply.safeToExit && (reply.phase == .off || reply.phase == .unavailable) else {
                errorMessage = "Adapter restoration is not yet confirmed. Keep StatBatt open and check status."; return false
            }
            return true
        } catch { errorMessage = "Could not confirm adapter restoration. Keep StatBatt open; do not start another control request."; return false }
    }
    func prepareNative() async -> Bool {
        nativeBlocked = true
        commandEpoch &+= 1
        let epoch = commandEpoch
        serviceStatus = SMAppService.daemon(plistName: ThermalServiceContract.daemonPlistName).status
        if serviceStatus != .enabled && !uncertain && !active { return true }
        do {
            let reply = try await call(.prepareNative)
            guard epoch == commandEpoch else { return false }
            accept(reply)
            guard reply.nativeMayProceed else { errorMessage = reply.message; return false }
            return true
        } catch { errorMessage = "The Apple limit is waiting for confirmed adapter restoration."; return false }
    }
    func setNativeBlocked(_ blocked: Bool) {
        let previous = nativeBlocked; nativeBlocked = blocked
        if previous && !blocked && serviceStatus == .enabled {
            commandEpoch &+= 1
            let epoch = commandEpoch
            busy = true
            Task {
                defer { busy = false }
                do {
                    let reply = try await call(.finishNative)
                    if epoch == commandEpoch { accept(reply) }
                } catch { errorMessage = "The background service has not confirmed the end of the Apple limit request." }
            }
        }
    }
    func sleeping() { Task { _ = await stopAndVerify() } }
    func woke() { Task { await refresh() } }
    private func accept(_ reply: ThermalControlStatus) {
        status = reply
        if reply.safeToExit && (reply.phase == .off || reply.phase == .unavailable) { uncertain = false }
        if reply.phase == .watching || reply.phase == .paused || reply.phase == .restoring || reply.phase == .qualifying || reply.phase == .recoveryRequired { uncertain = true }
    }
    private enum ClientError: Error { case connection, timeout, invalidReply, missingBundle }
    private func connected() throws -> NSXPCConnection {
        if let connection { return connection }
        let requirement = try ThermalServiceSigning.peerRequirement(ownIdentifier: ThermalServiceContract.appIdentifier, peerIdentifier: ThermalServiceContract.daemonIdentifier)
        let id = UUID()
        let value = NSXPCConnection(machServiceName: ThermalServiceContract.machServiceName, options: .privileged)
        value.setCodeSigningRequirement(requirement)
        value.remoteObjectInterface = NSXPCInterface(with: ThermalControlService.self)
        value.interruptionHandler = { [weak self] in Task { @MainActor in self?.disconnected(id) } }
        value.invalidationHandler = { [weak self] in Task { @MainActor in self?.disconnected(id) } }
        connectionID = id; connection = value; value.activate()
        return value
    }
    private func call(_ action: ThermalControlAction, policy: ThermalAdapterPolicy? = nil) async throws -> ThermalControlStatus {
        let data = try BoundedCodec().encode(ThermalControlRequest(action: action, policy: policy))
        let connection = try connected()
        let id = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            deadlines[id] = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(action == .qualifyAdapterOneShot ? 15 : 5)) } catch { return }
                self?.complete(id, data: nil, error: ClientError.timeout)
            }
            guard let remote = connection.remoteObjectProxyWithErrorHandler({ [weak self] error in
                Task { @MainActor in self?.complete(id, data: nil, error: error) }
            }) as? ThermalControlService else { complete(id, data: nil, error: ClientError.connection); return }
            remote.perform(data) { [weak self] data, error in
                Task { @MainActor in self?.complete(id, data: data, error: error) }
            }
        }
    }
    private func complete(_ id: UUID, data: Data?, error: Error?) {
        guard let continuation = pending.removeValue(forKey: id) else { return }
        deadlines.removeValue(forKey: id)?.cancel()
        if let error {
            if let clientError = error as? ClientError, case .timeout = clientError { connection?.invalidate() }
            continuation.resume(throwing: error); return
        }
        do {
            guard let data else { throw ClientError.invalidReply }
            continuation.resume(returning: try BoundedCodec().decode(ThermalControlStatus.self, from: data))
        } catch { continuation.resume(throwing: error) }
    }
    private func disconnected(_ id: UUID) {
        guard connectionID == id else { return }
        connectionID = nil; connection = nil
        for request in Array(pending.keys) { complete(request, data: nil, error: ClientError.connection) }
        status = nil
        if uncertain { errorMessage = "Connection lost. The service must confirm restoration before charging controls continue." }
    }
}
