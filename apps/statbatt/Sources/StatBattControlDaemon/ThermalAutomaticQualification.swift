import StatBattDomain

/// Source-reviewed evidence is required before automatic admission. A successful
/// one-shot request never creates this record. Keep nil until the exact guardian,
/// lifecycle recovery and duration have passed supervised qualification.
struct ThermalAutomaticQualification: Sendable {
    let capabilities: CapabilitySnapshot
    let estimatedTemperature: EstimatedTemperatureAdmission?
    let maximumPauseSeconds: Double
    static let current: Self? = nil
}
