import SwiftUI
import Foundation
import StatBattPersistence

struct PreferencesView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        Form {
            Section("General") {
                Picker("Menu bar shows", selection: $store.preferences.menuDisplay) {
                    Text("Percentage").tag(MenuDisplay.percentage)
                    Text("Temperature").tag(MenuDisplay.temperature)
                    Text("Battery watts").tag(MenuDisplay.batteryWatts)
                    Text("Time remaining").tag(MenuDisplay.timeRemaining)
                }
                Picker("Temperature unit", selection: $store.preferences.temperatureUnit) {
                    Text("Celsius").tag(TemperatureUnit.celsius)
                    Text("Fahrenheit").tag(TemperatureUnit.fahrenheit)
                }
                Toggle("Launch at login", isOn: Binding(get: { store.loginEnabled }, set: store.setLogin))
            }
            Section("Notifications") {
                Toggle("Allow battery notifications", isOn: Binding(get: { store.preferences.notificationsEnabled }, set: store.enableNotifications))
                Text(store.notificationStatus).font(.caption).foregroundStyle(.secondary)
                Toggle("Charging and power-source transitions", isOn: $store.preferences.notifyChargingTransitions).disabled(!store.preferences.notificationsEnabled)
                Toggle("Temperature threshold", isOn: $store.preferences.notifyTemperature).disabled(!store.preferences.notificationsEnabled)
                Toggle("Charging setup and recovery failures", isOn: $store.preferences.notifyFailures).disabled(!store.preferences.notificationsEnabled)
                Text("Failure alerts tell you when a native request needs attention or manual recovery. They do not restore the Apple charge limit.")
                    .font(.caption).foregroundStyle(.secondary)
                Stepper("Low battery: \(Int(store.preferences.lowBatteryThresholdPercent))%", value: $store.preferences.lowBatteryThresholdPercent, in: 1...50, step: 1)
                Stepper("High temperature: \(Int(store.displayTemperature(store.preferences.highTemperatureThresholdCelsius).rounded())) \(store.temperatureSuffix)",
                        value: Binding(get: { store.displayTemperature(store.preferences.highTemperatureThresholdCelsius) },
                                       set: { store.preferences.highTemperatureThresholdCelsius = store.celsiusFromDisplay($0) }),
                        in: store.displayTemperature(30)...store.displayTemperature(60), step: 1)
                Text("Temperature notifications require available battery temperature readings. These alerts do not control charging.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Local data") {
                Toggle("Record battery history", isOn: $store.preferences.historyEnabled)
                Text("Keeps seven days of one-minute summaries. Pausing does not erase saved history. CSV and diagnostics exports are user initiated.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Export history…") { store.exportHistory() }
                    Button("Export diagnostics…") { store.exportDiagnostics() }
                }
            }
            Section("Control & recovery") {
                Text("Quit stops monitoring. An Apple charge limit applied through the trusted shortcut remains active after StatBatt quits. Return to 100% manually in Battery settings, after checking that the shortcut finished or stopping it in Shortcuts.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Custom controls are unavailable, and no privileged helper is installed. Other battery controllers continue independently.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("About StatBatt") {
                LabeledContent("Version", value: versionLabel)
            }
        }
        .formStyle(.grouped)
        .onChange(of: store.preferences) { _, _ in store.savePreferences() }
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "development"
        return "\(version) (\(build))"
    }
}
