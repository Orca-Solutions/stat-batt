import Foundation
import Testing
import StatBattDomain
import StatBattAdapterBackend
@testable import StatBattControlDaemon

@Test func automaticAdmissionPinsExactGuardianPlatformAndClosedGates() throws {
    let record = try #require(ThermalAutomaticQualification.current)
    #expect(record.permits(platform: record.capabilities.platform, guardianDigest: record.guardianSHA256, backendGatesEnabled: true))
    #expect(!record.permits(platform: record.capabilities.platform, guardianDigest: record.guardianSHA256, backendGatesEnabled: false))
    #expect(!record.permits(platform: record.capabilities.platform, guardianDigest: String(repeating: "0", count: 64), backendGatesEnabled: true))
    var changed = record.capabilities.platform; changed.operatingSystemBuild += "changed"
    #expect(!record.permits(platform: changed, guardianDigest: record.guardianSHA256, backendGatesEnabled: true))
    #expect(!LocalThermalAdapterBackend.qualificationEnabled && !LocalThermalAdapterBackend.recoveryEnabled && !LocalThermalAdapterBackend.longPauseQualificationEnabled)
    #expect(record.maximumPauseSeconds == 120 && record.minimumReservePercent == 50)
    #expect(!record.capabilities.canObserveBatteryTemperature.isVerified)
    #expect(record.estimatedTemperature?.source == "apple.registry.AppleSmartBatteryPack.BatteryData.Temperature.centiC")
}

@Test func guardianHashChecksExactBytesAndRejectsMissingFiles() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: path) }
    try Data("hello".utf8).write(to: path)
    let digest = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    #expect(LocalThermalAdapterBackend.guardianMatches(digest, at: path))
    try Data("changed".utf8).write(to: path)
    #expect(!LocalThermalAdapterBackend.guardianMatches(digest, at: path))
    #expect(!LocalThermalAdapterBackend.guardianMatches(digest, at: path.appendingPathComponent("missing")))
}
