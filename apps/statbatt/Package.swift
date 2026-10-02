// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StatBatt",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "StatBatt", targets: ["StatBattApp"]),
        .executable(name: "statbatt-diagnostics", targets: ["StatBattDiagnostics"]),
        .executable(name: "statbatt-hardware-probe", targets: ["StatBattHardwareProbeCommand"]),
        .library(name: "StatBattDomain", targets: ["StatBattDomain"]),
        .library(name: "StatBattNativeLimit", targets: ["StatBattNativeLimit"]),
        .library(name: "StatBattControlProtocol", targets: ["StatBattControlProtocol"])
    ],
    targets: [
        .target(name: "StatBattDomain"),
        .target(name: "StatBattControlProtocol", dependencies: ["StatBattDomain"]),
        .target(name: "StatBattTelemetry", dependencies: ["StatBattDomain"], linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "CStatBattSMCReadOnly", linkerSettings: [.linkedFramework("IOKit")]),
        .target(name: "StatBattHardwareProbe", dependencies: ["CStatBattSMCReadOnly", "StatBattDomain"]),
        .executableTarget(name: "StatBattHardwareProbeCommand", dependencies: ["StatBattHardwareProbe", "StatBattTelemetry"]),
        .target(name: "StatBattNativeLimit", dependencies: ["StatBattDomain"]),
        .systemLibrary(name: "CSQLite"),
        .target(name: "StatBattPersistence", dependencies: ["StatBattDomain", "CSQLite"]),
        .executableTarget(name: "StatBattApp", dependencies: ["StatBattDomain", "StatBattTelemetry", "StatBattPersistence", "StatBattControlProtocol", "StatBattNativeLimit"]),
        .executableTarget(name: "StatBattDiagnostics", dependencies: ["StatBattDomain", "StatBattTelemetry"]),
        .testTarget(name: "StatBattDomainTests", dependencies: ["StatBattDomain"]),
        .testTarget(name: "StatBattNativeLimitTests", dependencies: ["StatBattNativeLimit", "StatBattDomain"]),
        .testTarget(name: "StatBattControlProtocolTests", dependencies: ["StatBattControlProtocol", "StatBattDomain"]),
        .testTarget(name: "StatBattPersistenceTests", dependencies: ["StatBattPersistence", "StatBattDomain"]),
        .testTarget(name: "StatBattTelemetryTests", dependencies: ["StatBattTelemetry", "StatBattDomain"]),
        .testTarget(name: "StatBattHardwareProbeTests", dependencies: ["StatBattHardwareProbe", "StatBattDomain"])
    ]
)
