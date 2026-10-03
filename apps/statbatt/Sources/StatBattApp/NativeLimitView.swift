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
    let onOpenShortcuts: () -> Void
    let onOpenBatterySettings: () -> Void
    let onConfigure: () -> Void
    let onApply: (NativeFixedLimit) -> Void
    let onConfirmVisible: (NativeFixedLimit) -> Void
    let onReconcile: (NativeFixedLimit, Bool) -> Void
    let onForgetSetup: () -> Void

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
                    DisclosureGroup("Shortcut settings") {
                        Button("Forget shortcut setup") {
                            priorShortcutCompletedOrStopped = false
                            onForgetSetup()
                        }
                        .help("Forgets StatBatt’s shortcut trust without changing Apple’s limit")
                        Text("Uses your trusted Apple shortcuts. If you edit their actions, what runs can change.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }
        .onChange(of: presentation.phase) { _, _ in
            priorShortcutCompletedOrStopped = false
        }
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("Connect Apple Shortcuts once").font(.subheadline.weight(.medium))
            Text("Each shortcut should contain one Set Battery Charge Limit action at the named percentage, with Set Until Tomorrow off.")
                .font(.callout)
            ForEach(NativeFixedLimit.allCases, id: \.self) { limit in
                Label(limit.expectedShortcutName,
                      systemImage: presentation.discoveredLimits.contains(limit) ? "checkmark.circle" : "circle.dashed")
            }
            Button("Open Shortcuts") { onOpenShortcuts() }
            Text("Enabling confirms you trust these two shortcuts and have stopped other charging apps. Edits to a shortcut can change what runs; StatBatt cannot detect every edit.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Enable charge buttons") { onConfigure() }
                .disabled(!canConfigure)
            Text("This saves setup without changing your charge limit.")
                .font(.caption).foregroundStyle(.secondary)
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

    private var canConfigure: Bool {
        presentation.phase != .applying && presentation.phase != .recoveryRequired && presentation.phase != .unavailable &&
            presentation.deviceQualified && presentation.conflictingControllerResolved &&
            Set(NativeFixedLimit.allCases).isSubset(of: presentation.discoveredLimits)
    }
}
