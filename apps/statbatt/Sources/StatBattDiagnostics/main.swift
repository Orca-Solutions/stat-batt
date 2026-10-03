import Foundation
import Darwin
import StatBattTelemetry

@main
struct DiagnosticsCommand {
    @MainActor static func main() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.isEmpty || arguments == ["--temperature-sample"] else {
            FileHandle.standardError.write(Data("Usage: statbatt-diagnostics [--temperature-sample]\n".utf8))
            exit(64)
        }
        let reader = PublicTelemetry()
        let platform = PlatformProbe.readOnly()
        if arguments.isEmpty {
            let report = DiagnosticReport(platform: platform, telemetry: reader.snapshot())
            FileHandle.standardOutput.write(try report.encoded())
            FileHandle.standardOutput.write(Data("\n".utf8))
            return
        }
        guard getuid() != 0 && geteuid() != 0 else { exit(64) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        func emit<T: Encodable>(_ value: T) throws {
            FileHandle.standardOutput.write(try encoder.encode(value)); FileHandle.standardOutput.write(Data("\n".utf8))
        }
        try emit(platform)
        var samples: [TemperatureSample] = []
        for index in 0..<60 {
            if index > 0 { try await Task.sleep(for: .seconds(1)) }
            let sample = TemperatureSampler.sample(reader: reader, platform: platform)
            samples.append(sample); try emit(sample)
        }
        try emit(TemperatureSamplingSummary(samples: samples))
    }
}
