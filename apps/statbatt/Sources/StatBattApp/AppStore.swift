import AppKit
import Combine
import ServiceManagement
import UniformTypeIdentifiers
import UserNotifications
import StatBattDomain
import StatBattPersistence
import StatBattTelemetry
import StatBattNativeLimit

enum DashboardTab: Hashable { case battery, charging, history, settings }

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedDashboardTab: DashboardTab = .battery
    @Published var snapshot = BatterySnapshot(bootID: UUID())
    @Published var preferences = AppPreferences()
    @Published var points: [HistoryPoint] = []
    @Published var gaps: [HistoryGap] = []
    @Published var message: String?
    @Published var sleeping = false
    @Published var notificationStatus = "Notifications are off"
    @Published var nativePresentation = NativeLimitPresentation(phase: .unavailable,
        message: "Checking native shortcut setup…")
    var nativeCoordinator: NativeLimitCoordinator?
    @Published var nativeTaskInProgress = false
    let platform = PlatformProbe.readOnly()
    private let telemetry = PublicTelemetry()
    private var history: HistoryStore?
    private var preferenceStore: PreferencesStore?
    private var observers: [NSObjectProtocol] = []
    private var sleepStart: Date?
    private var historyPauseStart: Date?
    private var notificationReducer = BatteryNotificationReducer()
    private var notificationPermissionRequestID: UUID?
    private var nativeNotificationObserver: NSObjectProtocol?

    var capabilities: CapabilitySnapshot {
        var result = CapabilityProbe.readOnly(platform: platform, snapshot: snapshot)
        result.nativeRestorationMode = "deliberateTrustedTargetRequestOrManualSettings"
        if nativePresentation.deviceQualified {
            let ready = canSetNativeLimit80 || canSetNativeLimit100
            result.allowedNativeLimitsPercent = nativePresentation.qualifiedLimits.map(\.percent).sorted()
            result.canSetNativeChargeLimit = Capability(status: ready ? .verified : .temporarilyUnavailable,
                scope: .appleDelegated,
                reasonCode: ready ? nil : nativePresentation.message ?? "Native setup or prior execution reconciliation required",
                evidence: [EvidenceReference(identifier: "native80-app-setting-readback",
                    provenance: "observedSettingOnly", reference: "docs/research/NATIVE_APP_FLOW_RESULT.md"),
                    EvidenceReference(identifier: "mutable-user-workflow-trust", provenance: "ownerApproved",
                        reference: "docs/decisions/0003-two-target-native-limit.md")],
                verifiedAtUTC: Date())
        }
        return result
    }
    var shouldPresentInitialDashboard: Bool {
        !preferences.launchAtLogin && !UserDefaults.standard.bool(forKey: "initialDashboardShown")
    }
    func dashboardPresented() {
        UserDefaults.standard.set(true, forKey: "initialDashboardShown")
    }
    init() {
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                       appropriateFor: nil, create: true)
            let directory = support.appendingPathComponent("StatBatt", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
            let prefs = PreferencesStore(url: directory.appendingPathComponent("preferences.json"))
            preferenceStore = prefs
            let loaded = try prefs.load()
            preferences = loaded.preferences
            switch loaded.status {
            case .recoveredCorruption: message = "Preferences could not be read. Defaults are active; the original file was preserved."
            case .unsupportedVersion: message = "Preferences are from a newer app version. Defaults are active."
            default: break
            }
            history = try HistoryStore(url: directory.appendingPathComponent("history.sqlite"), recordingEnabled: preferences.historyEnabled)
            reloadHistory()
            initializeNativeLimit(storageDirectory: directory.appendingPathComponent("NativeLimit", isDirectory: true))
        } catch { message = "Local data is unavailable. Monitoring continues; history and preferences may not be saved." }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.willSleep() }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.didWake() }
        })
        nativeNotificationObserver = NotificationCenter.default.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.telemetry.refresh() }
        }
        configureNotificationReducer()
        startMonitoring()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshNativeLimit() }
            })
        if preferences.notificationsEnabled { refreshNotificationStatus() }
    }
    func startMonitoring() {
        telemetry.start { [weak self] sample in self?.accept(sample) }
    }
    private func accept(_ sample: BatterySnapshot) {
        notifyTransitions(sample)
        snapshot = sample
        do {
            try history?.record(HistoryPoint(timestamp: sample.stateOfChargePercent.sampledAtUTC,
                percentage: sample.stateOfChargePercent.value,
                temperatureCelsius: sample.batteryTemperatureCelsius.value,
                batteryWatts: sample.batteryPowerWatts.value,
                isCharging: sample.isCharging.value,
                source: sample.supplyingSource.value == .battery ? .battery : sample.supplyingSource.value == .adapter ? .adapter : .unknown))
            reloadHistory()
        } catch { message = "History could not be saved. Monitoring continues." }
    }
    func refresh() { telemetry.refresh(); refreshNativeLimit() }
    func savePreferences() {
        configureNotificationReducer()
        if history?.recordingEnabled == true && !preferences.historyEnabled { historyPauseStart = Date() }
        history?.recordingEnabled = preferences.historyEnabled
        if preferences.historyEnabled, let paused = historyPauseStart {
            do { try history?.recordGap(HistoryGap(start: paused, end: Date(), reason: .recordingDisabled)) }
            catch { message = "Recording gap could not be saved." }
            historyPauseStart = nil
        }
        do { try preferenceStore?.save(preferences) }
        catch { message = "Preferences could not be saved." }
    }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            preferences.launchAtLogin = SMAppService.mainApp.status == .enabled
            savePreferences()
            if enabled && SMAppService.mainApp.status == .requiresApproval {
                message = "Approve StatBatt in System Settings → General → Login Items."
            }
        } catch {
            preferences.launchAtLogin = SMAppService.mainApp.status == .enabled
            message = "Login item could not be changed. This local development build may require a signed app."
        }
    }
    var loginEnabled: Bool { SMAppService.mainApp.status == .enabled }
    func enableNotifications(_ enabled: Bool) {
        guard enabled else {
            notificationPermissionRequestID = nil
            preferences.notificationsEnabled = false; notificationStatus = "Notifications are off"; savePreferences(); return
        }
        let requestID = UUID()
        notificationPermissionRequestID = requestID
        Task {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                guard notificationPermissionRequestID == requestID else { return }
                notificationPermissionRequestID = nil
                preferences.notificationsEnabled = allowed
                notificationStatus = allowed ? "Notifications enabled" : "Permission denied · change this in System Settings"
                savePreferences()
            } catch {
                guard notificationPermissionRequestID == requestID else { return }
                notificationPermissionRequestID = nil
                notificationStatus = "Notifications unavailable for this build"
            }
        }
    }
    private func refreshNotificationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationStatus = settings.authorizationStatus == .authorized ? "Notifications enabled" : "Permission denied · change this in System Settings"
        }
    }
    private func notifyTransitions(_ sample: BatterySnapshot) {
        notificationReducer.observe(sample, nowNanoseconds: SampleClock.nowNanoseconds())
        deliverPendingNotifications()
    }
    private func configureNotificationReducer() {
        notificationReducer.configure(BatteryNotificationSettings(enabled: preferences.notificationsEnabled,
            chargingTransitions: preferences.notifyChargingTransitions, temperature: preferences.notifyTemperature,
            failures: preferences.notifyFailures, lowBatteryPercent: preferences.lowBatteryThresholdPercent,
            highTemperatureCelsius: preferences.highTemperatureThresholdCelsius))
    }
    func notifyNativeFailure(id: String, message: String) {
        notificationReducer.recordFailure(id: id, message: message)
        if !sleeping { deliverPendingNotifications() }
    }
    func clearNativeFailureNotification() { notificationReducer.clearFailure() }
    private func deliverPendingNotifications() {
        let alerts = notificationReducer.drain(nowNanoseconds: SampleClock.nowNanoseconds())
        guard !alerts.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = "StatBatt"; content.body = alerts.map(\.message).joined(separator: "\n")
        let request = UNNotificationRequest(identifier: "statbatt-transition", content: content, trigger: nil)
        Task {
            guard preferences.notificationsEnabled, !sleeping else { return }
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
    private func willSleep() {
        sleeping = true; sleepStart = Date(); telemetry.stop(); notificationReducer.suspend()
    }
    private func didWake() {
        if let sleepStart {
            do { try history?.recordGap(HistoryGap(start: sleepStart, end: Date(), reason: .sleep)) }
            catch { message = "Sleep gap could not be saved." }
        }
        sleepStart = nil; sleeping = false
        startMonitoring()
    }
    func reloadHistory() {
        do { points = try history?.points() ?? []; gaps = try history?.gaps() ?? [] }
        catch { message = "History could not be read." }
    }
    func clearHistory() {
        do { try history?.clear(); reloadHistory() }
        catch { message = "History could not be cleared." }
    }
    func exportHistory() {
        do {
            guard let history else { message = "History is unavailable."; return }
            let data = Data(try history.exportCSV().utf8)
            save(data, name: "StatBatt-history.csv", type: .commaSeparatedText)
        } catch { message = "History could not be exported." }
    }
    func exportDiagnostics() {
        do {
            let report = DiagnosticReport(platform: platform, telemetry: snapshot,
                capabilities: capabilities, nativeState: nativeDiagnosticState)
            save(try report.encoded(), name: "StatBatt-diagnostics.json", type: .json)
        } catch { message = "Diagnostics could not be exported." }
    }
    private func save(_ data: Data, name: String, type: UTType) {
        let panel = NSSavePanel(); panel.nameFieldStringValue = name; panel.allowedContentTypes = [type]
        if panel.runModal() == .OK, let url = panel.url {
            do { try data.write(to: url, options: .atomic); message = "Export saved." }
            catch { message = "Export could not be saved." }
        }
    }
    func openBatterySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") { NSWorkspace.shared.open(url) }
    }
    func openNativeShortcutSetup() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
    }
    func quit() { telemetry.stop(); NSApplication.shared.terminate(nil) }
}
