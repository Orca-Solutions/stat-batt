import SwiftUI
import AppKit
import StatBattDomain
import StatBattNativeLimit

@main
struct StatBattApplication: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        MenuBarExtra {
            MenuPanel(store: store)
        } label: {
            StatusItemLabel(text: store.menuText, symbol: store.symbol,
                            accessibilityDescription: store.menuAccessibilityLabel)
                .equatable()
        }
        .menuBarExtraStyle(.window)
        Window("StatBatt", id: "dashboard") {
            Dashboard(store: store)
                .frame(minWidth: 640, minHeight: 630)
                .onAppear { store.dashboardPresented() }
        }
        .defaultSize(width: 720, height: 720)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(store.shouldPresentInitialDashboard ? .presented : .suppressed)
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsCommand(store: store)
            }
        }
    }
}

private struct StatusItemLabel: View, Equatable {
    let text: String
    let symbol: String
    let accessibilityDescription: String

    var body: some View {
        Label(text, systemImage: symbol)
            .accessibilityLabel(accessibilityDescription)
    }
}

struct MenuPanel: View {
    @ObservedObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("StatBatt").font(.headline)
                Spacer()
                Text(store.nativePresentation.lastObservedLimit.map { "LAST OBSERVED \($0.rawValue)%" } ?? "MONITOR").font(.caption2.bold()).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4).background(.quaternary, in: Capsule())
            }
            BatteryHeader(store: store, compact: true)
            Divider()
            nativeLimitActions
            HStack(alignment: .top) {
                MiniStat(title: "Temperature", value: store.format(store.displaySnapshot.batteryTemperatureCelsius, unit: "°C", temperature: true), explanation: "A tilde means an estimated battery sensor reading.")
                Spacer()
                MiniStat(title: "Health", value: store.format(store.displaySnapshot.healthPercent, unit: "%"), explanation: "Estimated full charge capacity divided by design capacity; separate from the macOS condition.")
                Spacer()
                MiniStat(title: "Cycles", value: store.displaySnapshot.cycleCount.value.map(String.init) ?? "Unavailable")
            }
            Divider()
            HStack {
                Button("Details") { show(.battery) }
                Button("History") { show(.history) }
                Button("Settings…") { show(.settings) }
                Spacer()
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh battery readings").accessibilityLabel("Refresh battery readings")
                Button("Quit") { store.quit() }
            }
        }.padding(20).frame(width: 380)
    }

    @ViewBuilder private var nativeLimitActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Apple charge limit", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.medium))
            NativeLimitActionButtons(presentation: store.nativePresentation,
                request80Enabled: store.canSetNativeLimit80,
                request100Enabled: store.canSetNativeLimit100,
                onApply: { store.setNativeLimit($0) })
            NativeLimitStatusView(presentation: store.nativePresentation)
            if store.nativePresentation.phase == .ready || store.nativePresentation.phase == .completed {
                Text("Uses your trusted shortcuts. Reinspect them if edited.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let message = store.nativePresentation.message, !message.isEmpty {
                Label(message, systemImage: "info.circle")
                    .font(.caption).fixedSize(horizontal: false, vertical: true)
            }
            Button("Charging…") { show(.charging) }
        }
    }

    private func show(_ tab: DashboardTab) {
        store.selectedDashboardTab = tab
        openWindow(id: "dashboard")
        NSApplication.shared.activate()
    }
}

struct SettingsCommand: View {
    @ObservedObject var store: AppStore
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Settings…") {
            store.selectedDashboardTab = .settings
            openWindow(id: "dashboard")
            NSApplication.shared.activate()
        }.keyboardShortcut(",", modifiers: .command)
    }
}

struct MiniStat: View {
    let title: String
    let value: String
    var explanation: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.monospacedDigit())
        }.help(explanation ?? "")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(value.replacingOccurrences(of: "~", with: "Estimated "))
    }
}

struct BatteryHeader: View {
    @ObservedObject var store: AppStore
    var compact = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: store.symbol).font(.system(size: compact ? 32 : 42)).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.percentage).font(.system(size: compact ? 34 : 44, weight: .semibold, design: .rounded)).monospacedDigit()
                    Text(store.sourceText).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if !compact {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(store.chargingText).font(.subheadline.weight(.medium))
                        Text("\(store.displaySnapshot.isCharging.value == true ? "To full" : "Time remaining"): \(store.estimateText(store.displaySnapshot.isCharging.value == true ? store.displaySnapshot.timeToFull : store.displaySnapshot.timeToEmpty))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            if let percent = store.displaySnapshot.stateOfChargePercent.value {
                ProgressView(value: percent, total: 100).tint(.green).accessibilityLabel("Battery charge")
            }
            if compact {
                Text(store.chargingText).font(.subheadline)
                Text("\(store.displaySnapshot.isCharging.value == true ? "To full" : "Remaining"): \(store.estimateText(store.displaySnapshot.isCharging.value == true ? store.displaySnapshot.timeToFull : store.displaySnapshot.timeToEmpty))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct Dashboard: View {
    @ObservedObject var store: AppStore
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("StatBatt").font(.title2.bold())
                Spacer()
                Label(store.nativePresentation.lastObservedLimit != nil ? "Apple limit · last observed by you" : "Monitoring", systemImage: "eye").font(.subheadline).foregroundStyle(.secondary)
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh").accessibilityLabel("Refresh battery readings")
            }.padding(24)
            if let message = store.message {
                HStack {
                    Text(message).font(.callout)
                    Spacer()
                    Button { store.message = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Dismiss message")
                }.padding(12).background(.yellow.opacity(0.12)).padding(.horizontal, 24)
            }
            TabView(selection: $store.selectedDashboardTab) {
                Overview(store: store).tabItem { Label("Battery", systemImage: "battery.100percent") }.tag(DashboardTab.battery)
                ChargingView(store: store).tabItem { Label("Charging", systemImage: "bolt") }.tag(DashboardTab.charging)
                HistoryView(store: store).tabItem { Label("History", systemImage: "chart.xyaxis.line") }.tag(DashboardTab.history)
                PreferencesView(store: store).tabItem { Label("Settings", systemImage: "gearshape") }.tag(DashboardTab.settings)
            }.padding(.horizontal, 16).padding(.bottom, 16)
            Text("Closing this window keeps monitoring in the menu bar.")
                .font(.caption).foregroundStyle(.secondary).padding(.bottom, 12)
        }
    }
}

struct Overview: View {
    @ObservedObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                BatteryHeader(store: store).padding(20).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                GroupBox("Battery condition") {
                    VStack(spacing: 10) {
                        DetailRow(title: "macOS condition", value: store.displaySnapshot.operatingSystemCondition.value ?? "Unavailable", origin: store.displaySnapshot.operatingSystemCondition.source)
                        DetailRow(title: "Estimated health", value: store.format(store.displaySnapshot.healthPercent, unit: "%"), origin: "Full charge capacity ÷ design capacity · estimate, not an OS health diagnosis")
                        DetailRow(title: "Cycle count", value: store.displaySnapshot.cycleCount.value.map(String.init) ?? "Unavailable", origin: store.displaySnapshot.cycleCount.source)
                        DetailRow(title: "Full charge capacity", value: store.displaySnapshot.fullChargeCapacityMilliampHours.value.map { "\(Int($0)) mAh" } ?? "Unavailable", origin: "Reported physical capacity · battery registry")
                        DetailRow(title: "Design capacity", value: store.displaySnapshot.designCapacityMilliampHours.value.map { "\(Int($0)) mAh" } ?? "Unavailable", origin: "Reported physical capacity · battery registry")
                        DetailRow(title: "Battery temperature", value: store.format(store.displaySnapshot.batteryTemperatureCelsius, unit: "°C", temperature: true), origin: store.displaySnapshot.batteryTemperatureCelsius.value == nil ? store.displaySnapshot.batteryTemperatureCelsius.unavailableReason ?? "No validated battery temperature reading" : "Battery sensor · estimated reading" )
                    }.padding(10)
                }
                GroupBox("Power & electrical readings") {
                    VStack(spacing: 10) {
                        DetailRow(title: "Adapter connection (reported)", value: store.displaySnapshot.adapterAttached.value.map { $0 ? "Yes" : "No" } ?? "Unavailable", origin: store.displaySnapshot.adapterAttached.source)
                        DetailRow(title: "Supplying source", value: store.sourceText, origin: store.displaySnapshot.supplyingSource.source)
                        DetailRow(title: "Battery voltage", value: store.format(store.displaySnapshot.batteryVoltageMillivolts, unit: "mV"), origin: store.displaySnapshot.batteryVoltageMillivolts.source)
                        DetailRow(title: "Battery current", value: store.format(store.displaySnapshot.batteryCurrentMilliamps, unit: "mA"), origin: "Battery current direction is not yet verified on this Mac")
                        DetailRow(title: "Net battery power", value: store.format(store.displaySnapshot.batteryPowerWatts, unit: "W"), origin: "Positive into battery; negative out · distinct from charger delivery")
                        DetailRow(title: "Adapter rating", value: store.format(store.displaySnapshot.adapterRatedWatts, unit: "W"), origin: "Reported adapter rating, not measured input power")
                        DetailRow(title: "System thermal pressure", value: store.displaySnapshot.thermalPressure.value?.rawValue.capitalized ?? "Unavailable", origin: "System category, not battery temperature")
                    }.padding(10)
                }
                Text("A paused charge can reflect Apple’s charge limit, optimized charging, temperature, or another controller. Public telemetry does not identify the reason.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Updated \(store.displaySnapshot.stateOfChargePercent.sampledAtUTC.formatted(date: .omitted, time: .standard)) · Local data only")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    let origin: String
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline)
                Text(origin).font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Spacer(minLength: 20)
            Text(value).font(.subheadline.monospacedDigit()).textSelection(.enabled).accessibilityLabel(value.replacingOccurrences(of: "~", with: "Estimated "))
        }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine)
    }
}

struct ChargingView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Charging").font(.title2.bold())
                Text("Choose 80% for everyday use or 100% when you need a full charge.")
                    .foregroundStyle(.secondary)
                NativeLimitView(presentation: store.nativePresentation,
                    request80Enabled: store.canSetNativeLimit80,
                    request100Enabled: store.canSetNativeLimit100,
                    onOpenShortcuts: { store.openNativeShortcutSetup() },
                    onOpenBatterySettings: { store.openBatterySettings() },
                    setupPlan: store.nativeShortcutSetupPlan,
                    setupMessage: store.nativeSetupMessage,
                    onInstallShortcut: { store.installNextNativeShortcut() },
                    onRefresh: { store.refreshNativeLimit() },
                    onConfigure: { store.configureNativeLimits() },
                    onApply: { store.setNativeLimit($0) },
                    onConfirmVisible: { store.confirmNativeVisibleLimit($0) },
                    onReconcile: { store.reconcileNativeLimit($0, priorShortcutCompletedOrStopped: $1) },
                    onForgetSetup: { store.forgetNativeSetup() })
                DisclosureGroup("Other charging features") {
                    Text("Custom charge bands, forced discharge, one-time charging and temperature control are not available on this Mac yet. Apple manages charging; temperature alerts are available in Settings.")
                        .font(.callout).foregroundStyle(.secondary).padding(.vertical, 8)
                }
                DisclosureGroup("Compatibility & diagnostics") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Privileged helper: not installed · custom controls unavailable")
                        Text("\(store.platform.model) · \(store.platform.architecture) · macOS \(store.platform.operatingSystemVersion) (\(store.platform.operatingSystemBuild))")
                        Text("Firmware: \(store.platform.firmwareVersion)")
                        Button("Export capability diagnostics…") { store.exportDiagnostics() }
                    }.font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(10)
                }
            }.padding(16)
        }
        .onAppear { store.refreshNativeLimit() }
    }
}
