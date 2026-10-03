import SwiftUI

struct ThermalControlView: View {
    @ObservedObject var model: ThermalUIModel
    @State private var confirmingNativeReconciliation = false
    var body: some View {
        GroupBox("Temperature control") {
            VStack(alignment: .leading, spacing: 10) {
                Label(model.phaseLabel, systemImage: model.active ? "thermometer.medium" : "thermometer")
                    .font(.headline)
                Text(model.statusMessage).font(.callout).fixedSize(horizontal: false, vertical: true)
                Text("Disconnects adapter input while hot, so your Mac uses battery power even while plugged in. This is optional convenience control, not a replacement for Apple’s thermal protection.")
                    .font(.caption).foregroundStyle(.secondary)
                if let temperature = model.temperature {
                    Text(String(format: "%@%.1f °C · battery temperature", model.estimatedTemperature ? "Estimated " : "", temperature))
                        .font(.caption).monospacedDigit()
                }
                HStack {
                    Stepper("Disconnect: \(Int(model.disconnectAt)) °C", value: $model.disconnectAt, in: 35...50, step: 1)
                    Stepper("Reconnect: \(Int(model.reconnectAt)) °C", value: $model.reconnectAt, in: 25...(model.disconnectAt - 3), step: 1)
                }.disabled(model.active || model.busy)
                Text("Battery reserve: 30% · Current qualification limit: 2 seconds per pause. Sessions never restart automatically.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    if model.active || model.recoveryPending {
                        Button("Stop & restore adapter") { model.stopFromUI() }.disabled(model.busy)
                    } else {
                        Button("Enable temperature control") { model.startFromUI() }.disabled(!model.canStart)
                    }
                    if model.needsServiceSetup {
                        Button(model.awaitingApproval ? "Open Background Items settings…" : "Set up background service…") { model.setupService() }
                            .disabled(model.busy)
                    }
                    Button("Check status") { model.refreshFromUI() }.disabled(model.busy)
                }
                if model.status?.qualificationAvailable == true {
                    Button("Run one 2-second adapter test") { model.qualifyFromUI() }
                        .disabled(model.busy || model.nativeBlocked || model.recoveryPending)
                    Text("One brief interval on battery power, followed by adapter restoration. This does not enable automatic temperature control.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if model.status?.nativeReconciliationRequired == true {
                    Text("A previous Apple shortcut request lost its connection. Finish or stop that shortcut before clearing its safety block.")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                    Button("Resolve previous Apple request…") { confirmingNativeReconciliation = true }
                        .disabled(model.busy)
                }
                if let result = model.lastQualificationResult {
                    Text("Last adapter test: \(result)").font(.callout).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let checked = model.statusCheckMessage {
                    Text(checked).font(.caption).foregroundStyle(.secondary)
                }
                if model.awaitingApproval {
                    Text("Allow StatBatt in macOS Background Items, then return here. Installing the service does not enable temperature control.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }
        .task { model.beginMonitoring() }
        .alert("Confirm the previous shortcut has stopped", isPresented: $confirmingNativeReconciliation) {
            Button("Cancel", role: .cancel) { }
            Button("I confirm it has finished or stopped") { model.reconcileNativeFromUI() }
        } message: {
            Text("Check Shortcuts and ensure the previous Apple charge-limit shortcut has finished or been stopped. This clears only the abandoned request block; it does not run a shortcut, change Apple's limit, or enable temperature control.")
        }
    }
}
