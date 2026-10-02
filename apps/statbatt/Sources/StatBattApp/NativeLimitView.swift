import SwiftUI

enum NativeLimitPhase: Equatable {
    case setup
    case ready
    case applying
    case awaitingConfirmation
    case confirmed
    case recoveryRequired
    case unavailable
}

/// Presentation only. The coordinator owns discovery, authorization, execution,
/// journaling, and state transitions; this view never runs a shortcut.
struct NativeLimitPresentation: Equatable {
    var phase: NativeLimitPhase = .setup
    var shortcutName = "StatBatt — Apple Limit 80"
    var shortcutDiscovered = false
    var deviceQualified = false
    var conflictingControllerResolved = false
    var message: String? = nil
    var canForgetSetup = false
}

struct NativeLimitView: View {
    let presentation: NativeLimitPresentation
    let requestEnabled: Bool
    let onOpenShortcuts: () -> Void
    let onOpenBatterySettings: () -> Void
    let onConfigure: (Bool, Bool, Bool) -> Void
    let onApply: () -> Void
    let onConfirm80: () -> Void
    let onConfirmRestored100: (Bool) -> Void
    let onForgetSetup: () -> Void

    @State private var inspectedTrusted80 = false
    @State private var baseline100Confirmed = false
    @State private var otherControllersStopped = false
    @State private var priorShortcutCompletedOrStopped = false

    var body: some View {
        GroupBox("Apple charge limit · 80%") {
            VStack(alignment: .leading, spacing: 12) {
                phaseContent
                if let message = presentation.message, !message.isEmpty {
                    Label(message, systemImage: "info.circle")
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(message)
                }
                if !presentation.deviceQualified {
                    Text("Applying an 80% limit is unavailable until this Mac is verified. Setup does not change charging.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !presentation.conflictingControllerResolved {
                    Label("Resolve other charging controllers before recording setup or applying a limit.", systemImage: "exclamationmark.circle")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("Apple manages charging and may occasionally charge fully. This mode has no lower threshold or automatic expiry.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if presentation.canForgetSetup && presentation.phase != .applying {
                    Button("Forget shortcut setup") {
                        inspectedTrusted80 = false
                        baseline100Confirmed = false
                        otherControllersStopped = false
                        priorShortcutCompletedOrStopped = false
                        onForgetSetup()
                    }
                    .help("Forgets StatBatt’s shortcut configuration; does not change the Apple charge limit")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
        }
        .onChange(of: presentation.phase) { _, phase in
            priorShortcutCompletedOrStopped = false
            if phase == .setup {
                inspectedTrusted80 = false
                baseline100Confirmed = false
                otherControllersStopped = false
            }
        }
        .onChange(of: presentation.shortcutDiscovered) { _, discovered in
            if !discovered { inspectedTrusted80 = false }
        }
    }

    @ViewBuilder private var phaseContent: some View {
        switch presentation.phase {
        case .setup:
            setupContent
        case .ready:
            Label(canApply ? "Ready to request an 80% limit" : "Trusted shortcut setup recorded", systemImage: "checkmark.circle")
            Text("Your trusted shortcut is configured. Applying requests an 80% limit; returning to 100% is manual.")
            trustWarning
            Button("Apply 80% limit") { onApply() }
                .disabled(!canApply)
            Text("After the request, confirm the setting in Battery settings. A completed shortcut alone does not confirm the limit.")
                .font(.caption).foregroundStyle(.secondary)
        case .applying:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Requesting an 80% limit…")
            }
            Text("The setting has not been confirmed. Please wait before starting another request.")
                .font(.callout).foregroundStyle(.secondary)
        case .awaitingConfirmation:
            Label("Request completed · setting unconfirmed", systemImage: "questionmark.circle")
            Text("Open Battery settings and check the displayed charge limit. Battery percentage does not confirm the setting.")
            Button("Open Battery settings") { onOpenBatterySettings() }
            Button("I see an 80% limit in Battery settings") { onConfirm80() }
            restorationContent
        case .confirmed:
            Label("80% setting confirmed by you", systemImage: "checkmark.circle")
            Text("This records your last confirmation. StatBatt cannot read the current limit.")
                .font(.caption).foregroundStyle(.secondary)
            Text("macOS keeps this setting after StatBatt quits. StatBatt does not enforce an exact charging cutoff or return the limit automatically.")
            trustWarning
            restorationContent
        case .recoveryRequired:
            Label("Review and restore the Apple limit", systemImage: "exclamationmark.triangle")
            Text("A timed-out or interrupted request may still finish. Check or stop it in Shortcuts before restoring 100%.")
            Text("The outcome needs review. Before another request, open Battery settings, return the limit to your 100% baseline, and verify it is displayed.")
            restorationButtons
            Text("Confirming restoration only records what you saw; it does not change the setting.")
                .font(.caption).foregroundStyle(.secondary)
        case .unavailable:
            Label("Native integration unavailable", systemImage: "lock")
            Text("StatBatt cannot apply a native limit in the current state. Monitoring continues.")
            Button("Open Battery settings") { onOpenBatterySettings() }
                .help("Opens macOS Battery settings; does not apply a charge limit")
        }
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("One-time trusted shortcut setup", systemImage: "slider.horizontal.3")
            Text(presentation.shortcutDiscovered
                 ? "The shortcut “\(presentation.shortcutName)” was found. Open it in Shortcuts and inspect that it contains exactly one Apple Set Battery Charge Limit action set to 80%. You do not need to run it manually."
                 : "In Shortcuts, create “\(presentation.shortcutName)” with exactly one Apple Set Battery Charge Limit action set to 80%. You do not need to run it manually.")
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Shortcuts for setup") { onOpenShortcuts() }
            Label(presentation.shortcutDiscovered ? "Shortcut found" : "Waiting for the named shortcut", systemImage: presentation.shortcutDiscovered ? "checkmark.circle" : "magnifyingglass")
                .font(.callout).foregroundStyle(.secondary)
            trustWarning
            Toggle("I inspected the single 80% action and trust this shortcut. I will keep it unchanged.", isOn: $inspectedTrusted80)
                .disabled(!presentation.shortcutDiscovered)
            Button("Open Battery settings") { onOpenBatterySettings() }
                .help("Opens macOS Battery settings; does not apply a charge limit")
            Toggle("Battery settings visibly shows my return baseline of 100%.", isOn: $baseline100Confirmed)
            Toggle("Other charge-management apps are stopped.", isOn: $otherControllersStopped)
            Text("StatBatt checks known charging controllers but cannot identify every one. Stop other charge-management apps yourself; StatBatt does not stop them automatically.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Record trusted setup") {
                onConfigure(inspectedTrusted80, baseline100Confirmed, otherControllersStopped)
            }
            .disabled(!canConfigure)
            Text("Recording setup saves these confirmations. It does not apply the 80% limit.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var trustWarning: some View {
        Text("StatBatt cannot detect edits to this shortcut. Changing its actions could change what runs. Reinspect it before applying if it has been edited.")
            .font(.callout).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var restorationContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Before returning to 100%, check that the shortcut has finished or stop it in Shortcuts. Then change the limit in Battery settings and confirm the displayed value below.")
                .font(.callout).foregroundStyle(.secondary)
            restorationButtons
        }
    }

    private var restorationButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Open Shortcuts to check or stop") { onOpenShortcuts() }
                .help("Opens Shortcuts; StatBatt does not stop the shortcut for you")
            Toggle("The shortcut has finished, or I stopped it in Shortcuts.", isOn: $priorShortcutCompletedOrStopped)
            Button("Open Battery settings to restore") { onOpenBatterySettings() }
            Button("I restored 100% in Battery settings") { onConfirmRestored100(priorShortcutCompletedOrStopped) }
                .disabled(!priorShortcutCompletedOrStopped)
        }
    }

    private var canConfigure: Bool {
        presentation.phase == .setup && presentation.shortcutDiscovered &&
            presentation.deviceQualified && presentation.conflictingControllerResolved && inspectedTrusted80 && baseline100Confirmed && otherControllersStopped
    }

    private var canApply: Bool {
        requestEnabled
    }
}
