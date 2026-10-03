import Foundation
import IOKit
import IOKit.pwr_mgt

/// Public power notifications. Recovery precedes voluntary sleep acknowledgement;
/// neither this callback nor a software guardian can veto forced power loss.
final class ThermalPowerObserver: @unchecked Sendable {
    private var connection: io_connect_t = 0
    private var notifier: io_object_t = 0
    private var port: IONotificationPortRef?
    private let runtime: ThermalRuntime
    init(runtime: ThermalRuntime) { self.runtime = runtime }
    func start() -> Bool {
        connection = IORegisterForSystemPower(Unmanaged.passUnretained(self).toOpaque(), &port,
                                               thermalPowerCallback, &notifier)
        guard connection != 0, let port else { return false }
        IONotificationPortSetDispatchQueue(port, DispatchQueue(label: "dev.statbatt.power-notifications"))
        return true
    }
    fileprivate func received(_ type: UInt32, token: Int) {
        let connection = connection
        switch type {
        // IOKit IOMessage.h iokit_common_msg constants (macros are not imported by Swift).
        case 0xe0000270, 0xe0000280:
            Task {
                await runtime.recover(forSleep: true)
                // Failure remains unresolved in the journal. Do not claim that
                // acknowledging the OS establishes successful electrical recovery.
                IOAllowPowerChange(connection, token)
            }
        case 0xe0000300, 0xe0000290:
            Task { await runtime.woke() }
        default: break
        }
    }
}
private func thermalPowerCallback(_ context: UnsafeMutableRawPointer?, _ service: io_service_t,
                                  _ type: UInt32, _ argument: UnsafeMutableRawPointer?) {
    guard let context else { return }
    Unmanaged<ThermalPowerObserver>.fromOpaque(context).takeUnretainedValue()
        .received(type, token: Int(bitPattern: argument))
}
