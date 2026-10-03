import SwiftUI

struct ThermalControlView: View {
    @ObservedObject var model: ThermalUIModel
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
    }
}
