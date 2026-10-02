import Foundation
import Darwin
import StatBattHardwareProbe
import StatBattTelemetry

@main
struct HardwareProbeCommand {
    @MainActor static func main() throws {
        guard CommandLine.arguments.count == 1 else {
            FileHandle.standardError.write(Data("This read-only probe accepts no arguments, keys, commands, or values.\n".utf8))
            exit(64)
        }
        let report = HardwareProbe.readOnly(platform: PlatformProbe.readOnly())
        FileHandle.standardOutput.write(try report.encoded())
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
