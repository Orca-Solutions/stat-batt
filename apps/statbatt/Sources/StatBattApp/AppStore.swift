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
    var nativeTaskInProgress = false
    let platform = PlatformProbe.readOnly()
    private let telemetry = PublicTelemetry()
    private var history: HistoryStore?
    private var preferenceStore: PreferencesStore?
    private var observers: [NSObjectProtocol] = []
    private var sleepStart: Date?
    private var historyPauseStart: Date?
    private var lastAlertNanoseconds: UInt64 = 0
    private var alertBaseline: BatterySnapshot?
    private var nativeNotificationObserver: NSObjectProtocol?

    var capabilities: CapabilitySnapshot {
        var result = CapabilityProbe.readOnly(platform: platform, snapshot: snapshot)
        result.nativeRestorationMode = "explicitUserConfirmationInBatterySettings"
        if nativePresentation.deviceQualified {
            let ready = nativePresentation.phase == .ready &&
                nativePresentation.shortcutDiscovered && nativePresentation.conflictingControllerResolved
            result.allowedNativeLimitsPercent = [80]
            result.canSetNativeChargeLimit = Capability(status: ready ? .verified : .temporarilyUnavailable,
                scope: .appleDelegated,
                reasonCode: ready ? nil : nativePresentation.message ?? "Native setup or manual reconciliation required",
                evidence: [EvidenceReference(identifier: "native80-lab-setting-readback",
                    provenance: "observedSettingOnly", reference: "docs/research/NATIVE_LIMIT_LAB.md"),
                    EvidenceReference(identifier: "mutable-user-workflow-trust", provenance: "ownerApproved",
                        reference: "docs/decisions/0002-trusted-user-native-shortcut.md")],
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
    var percentage: String {
        guard !sleeping, let value = snapshot.stateOfChargePercent.value else { return "—" }
        return "\(Int(value.rounded()))%"
    }
    var sourceText: String {
        guard !sleeping else { return "Sleeping · readings paused" }
        switch snapshot.supplyingSource.value {
        case .adapter: return "On adapter"
        case .battery: return "On battery"
        case .ups: return "On UPS"
        default: return "Power source unavailable"
        }
    }
    var chargingText: String {
        guard !sleeping else { return "Readings paused" }
        guard snapshot.batteryPresent.value == true else { return "Internal battery unavailable" }
        guard let charging = snapshot.isCharging.value else { return "Charging state unavailable" }
        if charging { return "Charging" }
        if snapshot.stateOfChargePercent.value == 100 { return "Fully charged" }
        if snapshot.supplyingSource.value == .battery { return "Using battery power" }
        return "Not charging · reason unavailable"
    }
    var menuText: String {
        switch preferences.menuDisplay {
        case .percentage: percentage
        case .temperature: snapshot.batteryTemperatureCelsius.value == nil ? "— \(temperatureSuffix)" : format(snapshot.batteryTemperatureCelsius, unit: "°C", temperature: true)
        case .batteryWatts: snapshot.batteryPowerWatts.value == nil ? "— W" : format(snapshot.batteryPowerWatts, unit: "W")
        case .timeRemaining:
            estimateText(snapshot.isCharging.value == true ? snapshot.timeToFull : snapshot.timeToEmpty).replacingOccurrences(of: "Unavailable", with: "—")
        }
    }
    var menuAccessibilityLabel: String {
        let name: String
        switch preferences.menuDisplay {
        case .percentage: name = "battery charge"
        case .temperature: name = "battery temperature"
        case .batteryWatts: name = "net battery power"
        case .timeRemaining: name = snapshot.isCharging.value == true ? "time to full" : "time remaining"
        }
        let value = menuText.contains("—") ? "unavailable" : menuText.replacingOccurrences(of: "~", with: "estimated ")
        return "StatBatt, \(name) \(value), \(sourceText), \(chargingText)"
    }
    var symbol: String {
        if snapshot.isCharging.value == true { return "battery.100percent.bolt" }
        guard let percentage = snapshot.stateOfChargePercent.value else { return "battery.0percent" }
        let level = percentage < 12.5 ? 0 : percentage < 37.5 ? 25 : percentage < 62.5 ? 50 : percentage < 87.5 ? 75 : 100
        return "battery.\(level)percent"
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
            preferences.notificationsEnabled = false; notificationStatus = "Notifications are off"; savePreferences(); return
        }
        Task {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                preferences.notificationsEnabled = allowed
                notificationStatus = allowed ? "Notifications enabled" : "Permission denied · change this in System Settings"
                alertBaseline = snapshot
                savePreferences()
            } catch { notificationStatus = "Notifications unavailable for this build" }
        }
    }
    private func refreshNotificationStatus() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationStatus = settings.authorizationStatus == .authorized ? "Notifications enabled" : "Permission denied · change this in System Settings"
        }
    }
    private func notifyTransitions(_ sample: BatterySnapshot) {
        defer { alertBaseline = sample }
        guard preferences.notificationsEnabled, let old = alertBaseline,
              SampleClock.nowNanoseconds() > lastAlertNanoseconds + 60_000_000_000 else { return }
        var text: String?
        if preferences.notifyChargingTransitions,
           let prior = old.isCharging.value, let current = sample.isCharging.value, prior != current {
            text = current ? "Battery charging started." : "Battery charging stopped. Reason unavailable."
        }
        if let prior = old.stateOfChargePercent.value, let value = sample.stateOfChargePercent.value,
           prior > preferences.lowBatteryThresholdPercent, value <= preferences.lowBatteryThresholdPercent {
            text = "Battery reached your low-battery notification threshold."
        }
        if preferences.notifyTemperature, let prior = old.batteryTemperatureCelsius.value,
           let value = sample.batteryTemperatureCelsius.value,
           prior < preferences.highTemperatureThresholdCelsius, value >= preferences.highTemperatureThresholdCelsius {
            text = "Battery reached your temperature notification threshold. StatBatt is monitoring only."
        }
        guard let text else { return }
        lastAlertNanoseconds = SampleClock.nowNanoseconds()
        let content = UNMutableNotificationContent()
        content.title = "StatBatt"; content.body = text
        let request = UNNotificationRequest(identifier: "statbatt-transition", content: content, trigger: nil)
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }
    private func willSleep() {
        sleeping = true; sleepStart = Date(); telemetry.stop(); alertBaseline = nil
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
    func format(_ metric: Metric<Double>, unit: String, temperature: Bool = false) -> String {
        guard !sleeping, let value = metric.value, metric.quality != .stale else { return "Unavailable" }
        if temperature && preferences.temperatureUnit == .fahrenheit {
            return (metric.quality == .estimated ? "~" : "") + String(format: "%.1f °F", value * 9 / 5 + 32)
        }
        return (metric.quality == .estimated || metric.source.hasPrefix("derived.registry.FullCharge") ? "~" : "") + String(format: "%.1f %@", value, unit)
    }
    func estimateText(_ estimate: TimeEstimate) -> String {
        guard !sleeping else { return "Unavailable" }
        switch estimate {
        case .seconds(let seconds, _):
            guard seconds.isFinite, seconds > 0, seconds <= 7 * 24 * 3600 else { return "Unavailable" }
            return "~\(Int((seconds / 60).rounded())) min"
        case .calculating: return "Calculating…"
        case .unlimited: return "On external power"
        case .unavailable: return "Unavailable"
        }
    }
    var temperatureSuffix: String { preferences.temperatureUnit == .fahrenheit ? "°F" : "°C" }
    func displayTemperature(_ celsius: Double) -> Double {
        preferences.temperatureUnit == .fahrenheit ? celsius * 9 / 5 + 32 : celsius
    }
    func celsiusFromDisplay(_ value: Double) -> Double {
        preferences.temperatureUnit == .fahrenheit ? (value - 32) * 5 / 9 : value
    }
    func openBatterySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension") { NSWorkspace.shared.open(url) }
    }
    func openNativeShortcutSetup() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Shortcuts.app"))
    }
    func quit() { telemetry.stop(); NSApplication.shared.terminate(nil) }
}
