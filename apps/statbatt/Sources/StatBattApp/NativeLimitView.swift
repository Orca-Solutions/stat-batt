import SwiftUI
import StatBattNativeLimit

enum NativeLimitPhase: Equatable {
    case setup, ready, applying, completed, recoveryRequired, unavailable
}

/// Presentation only. The coordinator owns trust, qualification, execution and recovery.
struct NativeLimitPresentation: Equatable {
    var phase: NativeLimitPhase = .setup
    var discoveredLimits: Set<NativeFixedLimit> = []
    var trustedLimits: Set<NativeFixedLimit> = []
    var qualifiedLimits: Set<NativeFixedLimit> = []
    var deviceQualified = false
    var conflictingControllerResolved = false
    var lastRequestedLimit: NativeFixedLimit? = nil
    var lastObservedLimit: NativeFixedLimit? = nil
    var canForgetSetup = false
    var canRunSupervised100Qualification = false
    var message: String? = nil

    func disabledReason(for limit: NativeFixedLimit, requestEnabled: Bool) -> String? {
        guard !requestEnabled else { return nil }
        if phase == .applying { return "Wait for the current request." }
        if phase == .recoveryRequired { return "Check the prior request in Charging." }
        if !deviceQualified { return "This Mac is not qualified." }
        if !conflictingControllerResolved { return "Resolve other charging controllers." }
        if !discoveredLimits.contains(limit) { return "Set up the \(limit.rawValue)% shortcut in Charging." }
        if !trustedLimits.contains(limit) { return "Record trust for the \(limit.rawValue)% shortcut in Charging." }
        if !qualifiedLimits.contains(limit) { return "The \(limit.rawValue)% action is not qualified on this Mac." }
        if phase == .unavailable { return "Charging integration is unavailable." }
        return "Checking charging controls; please wait."
    }
}

/// Both surfaces share action labels and explanations for disabled actions.
struct NativeLimitActionButtons: View {
    let presentation: NativeLimitPresentation
    let request80Enabled: Bool
    let request100Enabled: Bool
    let onApply: (NativeFixedLimit) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Set to 80%") { onApply(.eighty) }
                    .disabled(!request80Enabled)
                    .help("Runs the trusted 80% Apple shortcut once")
                Button("Set to 100%") { onApply(.hundred) }
                    .disabled(!request100Enabled)
                    .help("Runs the trusted 100% Apple shortcut once")
            }
            let reason80 = presentation.disabledReason(for: .eighty, requestEnabled: request80Enabled)
            let reason100 = presentation.disabledReason(for: .hundred, requestEnabled: request100Enabled)
            if let reason80, reason80 == reason100 {
                Text(reason80).font(.caption).foregroundStyle(.secondary)
            } else {
                if let reason80 {
                    Text("80%: \(reason80)").font(.caption).foregroundStyle(.secondary)
                }
                if let reason100 {
                    Text("100%: \(reason100)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
}

struct NativeLimitStatusView: View {
    let presentation: NativeLimitPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch presentation.phase {
            case .setup:
                Text("Complete one-time shortcut setup in Charging.")
            case .ready:
                Text("Choose a limit. Apple keeps its setting after StatBatt quits.")
            case .applying:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(presentation.lastRequestedLimit.map { "Requesting \($0.rawValue)%…" } ?? "Requesting a charge limit…")
                }
            case .completed:
                Text(presentation.lastRequestedLimit.map { "\($0.rawValue)% request completed" } ?? "Request completed")
                Text("StatBatt cannot read the current Apple limit.")
            case .recoveryRequired:
                Label("Check the prior request", systemImage: "exclamationmark.triangle")
                Text("The shortcut may still be running. Check or stop it before changing the limit.")
            case .unavailable:
                Text("Charging integration is unavailable. Monitoring continues.")
            }
            if let limit = presentation.lastObservedLimit {
                Text("Last observed by you: \(limit.rawValue)% · historical record")
            }
        }.font(.caption).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct NativeLimitView: View {
    let presentation: NativeLimitPresentation
    let request80Enabled: Bool
    let request100Enabled: Bool
    let supervised100Enabled: Bool
    let onOpenShortcuts: () -> Void
    let onOpenBatterySettings: () -> Void
    let onConfigure: (NativeFixedLimit, Bool, Bool) -> Void
    let onApply: (NativeFixedLimit) -> Void
    let onConfirmVisible: (NativeFixedLimit) -> Void
    let onReconcile: (NativeFixedLimit, Bool) -> Void
    let onSupervised100Qualification: () -> Void
    let onForgetSetup: () -> Void

    @State private var inspectedTrusted80 = false
    @State private var inspectedTrusted100 = false
    @State private var otherControllersStopped = false
    @State private var priorShortcutCompletedOrStopped = false

    var body: some View {
        GroupBox("Apple charge limit") {
            VStack(alignment: .leading, spacing: 14) {
                NativeLimitActionButtons(presentation: presentation,
                    request80Enabled: request80Enabled, request100Enabled: request100Enabled,
                    onApply: onApply)
                NativeLimitStatusView(presentation: presentation)
                if let message = presentation.message, !message.isEmpty {
                    Label(message, systemImage: "info.circle")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                }
                if presentation.phase == .recoveryRequired {
                    recoveryContent
                } else if presentation.phase != .applying {
                    if !presentation.trustedLimits.contains(.eighty) || !presentation.trustedLimits.contains(.hundred) {
                        setupContent
                    }
                    if presentation.phase == .completed && presentation.lastRequestedLimit != nil {
                        observationContent
                    } else {
                        Button("Open Battery settings") { onOpenBatterySettings() }
                            .help("Opens Battery settings without changing the limit")
                    }
                }
                Text("Apple manages charging and may occasionally charge fully. These settings have no lower threshold or automatic expiry.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if presentation.canForgetSetup && presentation.phase != .applying {
                    Button("Forget shortcut setup") {
                        inspectedTrusted80 = false
                        inspectedTrusted100 = false
                        otherControllersStopped = false
                        priorShortcutCompletedOrStopped = false
                        onForgetSetup()
                    }
                    .help("Forgets StatBatt’s shortcut trust without changing Apple’s limit")
                }
                #if STATBATT_NATIVE_100_QUALIFICATION
                if presentation.trustedLimits.contains(.hundred) && !presentation.qualifiedLimits.contains(.hundred) {
                    Divider()
                    Text("Supervised qualification · 100% remains unqualified")
                        .font(.subheadline.weight(.medium))
                    Text("This trial changes Apple's limit to 100%. Run only during the explicitly authorized, supervised qualification session. It does not enable the normal 100% button.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Run supervised 100% qualification trial") { onSupervised100Qualification() }
                        .disabled(!supervised100Enabled)
                }
                #endif
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }
        .onChange(of: presentation.phase) { _, _ in
            priorShortcutCompletedOrStopped = false
        }
        .onChange(of: presentation.discoveredLimits) { _, discovered in
            if !discovered.contains(.eighty) { inspectedTrusted80 = false }
            if !discovered.contains(.hundred) { inspectedTrusted100 = false }
        }
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            Text("One-time trusted shortcut setup").font(.subheadline.weight(.medium))
            Text("Create or inspect each named shortcut with exactly one Apple Set Battery Charge Limit action at its stated percentage. Keep Set Until Tomorrow off. You do not need to run it manually.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Button("Open Shortcuts for setup") { onOpenShortcuts() }
            Text("StatBatt cannot detect every later edit. Changing a shortcut can change what runs. Reinspect it if edited.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Toggle("Other charge-management apps are stopped.", isOn: $otherControllersStopped)
            Text("StatBatt checks known controllers, but cannot identify or stop every one.")
                .font(.caption).foregroundStyle(.secondary)
            if !presentation.trustedLimits.contains(.eighty) {
                shortcutSetup(.eighty, inspected: $inspectedTrusted80)
            }
            if !presentation.trustedLimits.contains(.hundred) {
                shortcutSetup(.hundred, inspected: $inspectedTrusted100)
            }
            Text("Recording trust does not change charging. Each target also needs qualification on this Mac.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private func shortcutSetup(_ limit: NativeFixedLimit, inspected: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(limit.expectedShortcutName).font(.subheadline.weight(.medium))
            Label(presentation.discoveredLimits.contains(limit) ? "Shortcut found" : "Waiting for the named shortcut",
                  systemImage: presentation.discoveredLimits.contains(limit) ? "checkmark.circle" : "magnifyingglass")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("I inspected the single \(limit.rawValue)% action and trust this shortcut. I will keep it unchanged.", isOn: inspected)
                .disabled(!presentation.discoveredLimits.contains(limit))
            Button("Record \(limit.rawValue)% shortcut trust") {
                onConfigure(limit, inspected.wrappedValue, otherControllersStopped)
            }.disabled(!canConfigure(limit, inspected: inspected.wrappedValue))
        }
    }

    private var observationContent: some View {
        DisclosureGroup("Optional: verify the displayed setting") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Check the charge limit shown in Battery settings, not the battery percentage. Recording an observation is optional for ordinary use and does not change the limit.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open Battery settings") { onOpenBatterySettings() }
                HStack {
                    Button("I see an 80% limit") { onConfirmVisible(.eighty) }
                    Button("I see a 100% limit") { onConfirmVisible(.hundred) }
                }
            }.padding(.top, 6)
        }
    }

    private var recoveryContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A timed-out or interrupted request may still finish. Check or stop it in Shortcuts, then check the visible limit in Battery settings.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Button("Open Shortcuts to check or stop") { onOpenShortcuts() }
            Toggle("The prior shortcut has finished, or I stopped it in Shortcuts.", isOn: $priorShortcutCompletedOrStopped)
            Button("Open Battery settings") { onOpenBatterySettings() }
            Text("Record the limit you see to resume the buttons:").font(.caption)
            HStack {
                Button("I see 80% · resume buttons") { onReconcile(.eighty, priorShortcutCompletedOrStopped) }
                Button("I see 100% · resume buttons") { onReconcile(.hundred, priorShortcutCompletedOrStopped) }
            }.disabled(!priorShortcutCompletedOrStopped)
            Text("This records your review; it does not run a shortcut or change the limit. If another value is shown, leave the request unresolved and review it in Battery settings.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func canConfigure(_ limit: NativeFixedLimit, inspected: Bool) -> Bool {
        presentation.phase != .applying && presentation.phase != .recoveryRequired && presentation.phase != .unavailable &&
            presentation.deviceQualified && presentation.conflictingControllerResolved &&
            presentation.discoveredLimits.contains(limit) && inspected && otherControllersStopped
    }
}
