# Read-only macOS 27 telemetry qualification — October 2, 2026

The owner reported that coconutBattery still displays temperature and health, while StatBatt's first public-source monitor left these values unavailable. This motivated read-only investigation, separate from Energiza's charge-control failures. No hardware write, SMC control, helper installation, or private entitlement was involved.

## Source and observed layout

On `Mac16,13 / arm64 / macOS27.0.1 / 26A434 / mBoot-20457.1.29`, legacy top-level Temperature, DesignCapacity, AppleRawMaxCapacity and NominalChargeCapacity were absent. Top-level MaxCapacity/CurrentCapacity were100, representing normalized charge percentages and not mAh.

[SystemInfoKit's primary implementation](https://github.com/Kyome22/SystemInfoKit/blob/main/Sources/SystemInfoKit/Repositories/BatteryRepository.swift) uses the newer macOS27 source paths below; its [measured-value notes](https://github.com/Kyome22/SystemInfoKit/blob/main/MeasuredValues/README.md) describe device observations. Apple's [IOPMPowerSource header](https://github.com/apple-oss-distributions/xnu/blob/main/iokit/IOKit/pwr_mgt/IOPMPowerSource.h) documents physical capacity units in mAh and electrical units, but does not make every registry name a stable public contract. These are live source references, not pinned vendor revisions. StatBatt's implementation is original and adds no copied dependency.

| Field | Fixed read-only path | Interpretation |
|---|---|---|
| Full charge capacity | AppleSmartBattery.BatteryData.FullChargeCapacity | Physical mAh; positive integer; observed |
| Design capacity | AppleSmartBattery.BatteryData.DesignCapacity | Physical mAh; positive integer; observed |
| Estimated health | FullChargeCapacity / DesignCapacity ×100 | Derived ratio; may exceed100%; separate from macOS health condition |
| Pack temperature | AppleSmartBatteryPack.BatteryData.Temperature | Centi-C according to the newer source path; divide by100, retain estimated quality |

NominalChargeCapacity is different from FullChargeCapacity and is never substituted. Historical battery temperature encodings differ; no legacy Celsius/Kelvin guess or automatic profile fallback is used. Nonzero battery current polarity remains unqualified, so current/net power remain unavailable. Zero current at full charge cannot prove its sign convention.

Only the exact tuple above receives this registry conversion. Other model/build/firmware combinations remain public-monitor-only for these fields until additional qualification. Plausibility filtering is not sensor safety calibration; no temperature-control bounds or charge capability are unlocked.

## Independent comparison and limits

The first fixed-property sample reported full5582mAh/design5760mAh, ratio96.91%, and candidate pack34.50°C. A later StatBatt diagnostic reported full5581mAh/design5760mAh, ratio96.892%, and pack36.59°C. The source retains acquisition/provenance and estimated temperature quality.

Read-only coconutBattery4 accessibility inspection identified the same Mac/model and full5581mAh/design5760mAh, with displayed ratios96.9% and99.4% and temperature96.6°F (about35.89°C). Those capacity values support the selected physical source and ratio; the99.4% charging ratio is distinct from the96.9% full/design ratio. The samples were not simultaneous, and identical sensor calibration/instantaneous temperature was not proved. Do not claim an exact temperature match or that coconutBattery's proprietary implementation was inspected.

The UI labels approximate sensor/health values, separates reported capacity and OS condition, and makes provenance available in diagnostics. The history/notification flows do not enforce thermal protection. Further synchronized comparison and sensor bounds remain qualification work before using these values for control.

The separate native80% test subsequently proceeded after the owner stopped Energiza's helper. Supported Apple action/readback and manual100% restoration passed; see [native lab result](NATIVE_LIMIT_LAB.md). Reading these metrics did not itself resolve that controller conflict or establish cutoff behavior.
