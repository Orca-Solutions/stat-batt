import Foundation
import Testing
import StatBattDomain
@testable import StatBattHardwareProbe

private func platform(model: String = "Mac16,13", firmware: String = "mBoot-20457.1.29") -> PlatformFingerprint {
    PlatformFingerprint(model: model, architecture: "arm64", operatingSystemVersion: "27.0.1",
        operatingSystemBuild: "26A434", firmwareVersion: firmware, providerVersion: "synthetic-fixture")
}

@Test @MainActor func unknownTargetNeverOpensConnection() {
    let result = HardwareProbe.readOnly(platform: platform(model: "SyntheticMac"))
    #expect(result.targetMatches == false)
    #expect(result.connection == nil)
    #expect(result.observations.isEmpty)
    #expect(HardwareProbeReport.targetMatches(platform(firmware: "different")) == false)
}

@Test func denialAndPlaceholderNeverExportValue() {
    let denied = KeyObservation(key: .chargeEnable, metadataIOReturn: 0xe00002c1,
        dataSize: 4, dataTypeCode: 0x75693332, dataAttributes: 0xD4,
        readIOReturn: 0, readResponseLength: 80, readSMCResult: 0, value: [0, 0, 0, 0])
    #expect(denied.finding == .accessDenied); #expect(denied.baselineHex == nil)
    let placeholder = KeyObservation(key: .chargeEnable, dataSize: 0, dataTypeCode: 0, dataAttributes: 0)
    #expect(placeholder.finding == .zeroSizePlaceholder); #expect(placeholder.baselineHex == nil)
}

@Test func incompatibleOrTruncatedLayoutNeverExportsValue() {
    let layout = KeyObservation(key: .adapterInhibit, dataSize: 2, dataTypeCode: 0x6865785f,
        dataAttributes: 0xD4, readIOReturn: 0, readResponseLength: 80, readSMCResult: 0, value: [0, 8])
    #expect(layout.finding == .unexpectedLayout); #expect(layout.baselineHex == nil)
    let truncated = KeyObservation(key: .adapterInhibit, metadataResponseLength: 79,
        dataSize: 1, dataTypeCode: 0x6865785f, dataAttributes: 0xD4)
    #expect(truncated.finding == .malformedResponse)
    let shortValue = KeyObservation(key: .chargeEnable, dataSize: 4, dataTypeCode: 0x75693332,
        dataAttributes: 0xD4, readIOReturn: 0, readResponseLength: 80, readSMCResult: 0, value: [0])
    #expect(shortValue.finding == .readFailed); #expect(shortValue.baselineHex == nil)
}

@Test func firmwareKeysRemainMetadataOnlyEvenWithSyntheticReadSuccess() {
    let row = KeyObservation(key: .firmwareUpper, dataSize: 1, dataTypeCode: 0x75693820,
        dataAttributes: 0xD4, readIOReturn: 0, readResponseLength: 80, readSMCResult: 0, value: [80])
    #expect(row.finding == .metadataOnly); #expect(row.baselineHex == nil)
}

@Test func candidateDoesNotBecomeVerifiedControl() throws {
    let row = KeyObservation(key: .adapterInhibit, dataSize: 1, dataTypeCode: 0x6865785f,
        dataAttributes: 0xD4, readIOReturn: 0, readResponseLength: 80, readSMCResult: 0, value: [8])
    #expect(row.finding == .readableCandidate); #expect(row.baselineHex == "08")
    let report = HardwareProbeReport(platform: platform(), connection: nil, observations: [row])
    let output = String(decoding: try report.encoded(), as: UTF8.self)
    #expect(!output.contains("serial")); #expect(!output.contains("capabilities"))
    #expect(output.contains("Unqualified controls remain disabled"))
}
