import StatBattDomain
import StatBattAdapterBackend

/// Host acquisition freshness only. Estimated temperature remains estimated;
/// its sensor conversion age and physical calibration are not established here.
enum LongPauseSafety {
    static func rejection(_ sample: BatterySnapshot, now: UInt64, requireBattery: Bool) -> AdapterFailure? {
        guard sample.batteryPresent.quality == .observed, sample.batteryPresent.value == true,
              sample.batteryPresent.isFresh(at: now, maximumAgeSeconds: 2) else { return .batteryMissingOrStale }
        guard [.observed, .derived].contains(sample.stateOfChargePercent.quality),
              let reserve = sample.stateOfChargePercent.value, reserve.isFinite, (50...100).contains(reserve),
              sample.stateOfChargePercent.isFresh(at: now, maximumAgeSeconds: 2) else { return .reserveMissingOrStale }
        guard sample.thermalPressure.quality == .observed, sample.thermalPressure.value == .nominal,
              sample.thermalPressure.isFresh(at: now, maximumAgeSeconds: 2) else { return .thermalNotNominalOrStale }
        guard sample.supplyingSource.quality == .observed,
              sample.supplyingSource.isFresh(at: now, maximumAgeSeconds: 2),
              sample.supplyingSource.value == .battery || (!requireBattery && sample.supplyingSource.value == .adapter) else {
            return .powerSourceUnavailableOrUnexpected
        }
        // Decoder representation bounds, not a claim that every temperature in
        // this range is safe or suitable as a product-policy threshold.
        guard [.observed, .estimated].contains(sample.batteryTemperatureCelsius.quality),
              let temperature = sample.batteryTemperatureCelsius.value, temperature.isFinite,
              (-20...100).contains(temperature), sample.batteryTemperatureCelsius.isFresh(at: now, maximumAgeSeconds: 2) else {
            return .temperatureMissingInvalidOrStale
        }
        return nil
    }
}
