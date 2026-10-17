import Foundation
import StatBattDomain

/// Reviewed exact-target convenience-control admission. This records software
/// deadlines and observed recovery, never a physical guarantee under kernel stalls.
struct ThermalAutomaticQualification: Sendable {
    let capabilities: CapabilitySnapshot
    let estimatedTemperature: EstimatedTemperatureAdmission?
    let maximumPauseSeconds: Double
    let minimumReservePercent: Double
    let guardianSHA256: String
    static let current: Self? = reviewedBuild13

    func permits(platform: PlatformFingerprint, guardianDigest: String, backendGatesEnabled: Bool) -> Bool {
        backendGatesEnabled && platform == capabilities.platform && guardianDigest == guardianSHA256 &&
        capabilities.supportsBoundedAdapterInhibition && maximumPauseSeconds == 120 && minimumReservePercent == 50
    }

    // Source reviewed admission; default backend write gates remain disabled.
    static let reviewedBuild13: Self = {
        let platform = PlatformFingerprint(model: "Mac16,13", architecture: "arm64",
            operatingSystemVersion: "27.0.1", operatingSystemBuild: "26A434",
            firmwareVersion: "mBoot-20457.1.29", providerVersion: "public-telemetry-0.1.0")
        let evidence = [
            EvidenceReference(identifier: "build13-normal120", provenance: "Supervised 120-second trace and independent zero/AC restoration", reference: "docs/research/THERMAL_LONG_PAUSE_RESULT.json"),
            EvidenceReference(identifier: "build13-guardian-loss", provenance: "Guardian terminated after inhibition; worker restored before cleanup", reference: "docs/research/THERMAL_BUILD13_GUARDIAN_LOSS_RESULT.json"),
            EvidenceReference(identifier: "build13-sleep", provenance: "WILL_SLEEP and ACK_RESTORED; separate owner-confirmed wake and fresh service inspection", reference: "docs/research/THERMAL_BUILD13_SLEEP_RESULT.json")
        ]
        let verified = Capability(status: .verified, scope: .awakeOnly,
            reasonCode: "120s software lease plus settling budget; kernel stalls remain outside the guarantee",
            evidence: evidence, verifiedAtUTC: ISO8601DateFormatter().date(from: "2026-10-03T19:36:38Z"),
            restorationVerified: true, crashRecoveryBoundSeconds: 125)
        var capabilities = CapabilitySnapshot(platform: platform)
        capabilities.canInhibitAdapter = verified
        capabilities.canReadControlState = verified
        capabilities.canRestoreOwnedControl = verified
        // No observed-sensor capability is asserted. Bounds are a conservative
        // convenience-policy operating envelope, not a calibration certificate.
        let estimated = EstimatedTemperatureAdmission(platform: platform,
            source: "apple.registry.AppleSmartBatteryPack.BatteryData.Temperature.centiC",
            bounds: .init(lower: 0, upper: 60))
        return Self(capabilities: capabilities, estimatedTemperature: estimated,
            maximumPauseSeconds: 120, minimumReservePercent: 50,
            guardianSHA256: "747f18061e2c30f504b824b0d1c5730df2613930b16d080bdd5aef3ff5d32470")
    }()
}
