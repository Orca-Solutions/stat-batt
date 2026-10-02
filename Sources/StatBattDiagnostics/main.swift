import Foundation
import StatBattTelemetry

@main
struct DiagnosticsCommand {
    @MainActor static func main() throws {
        let reader = PublicTelemetry()
        let report = DiagnosticReport(platform: PlatformProbe.readOnly(), telemetry: reader.snapshot())
        FileHandle.standardOutput.write(try report.encoded())
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
