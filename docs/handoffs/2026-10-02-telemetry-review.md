# Independent registry telemetry review — October 2, 2026

Reviewed the uncommitted registry enhancement in `Sources/StatBattTelemetry/RegistryTelemetry.swift`, its tests, and integration in `PublicTelemetry.swift`, `Diagnostics.swift`, `AppStore.swift`, and the battery overview. The reviewer did not author or edit sources. This report concerns read-only telemetry, not charging control or sensor safety qualification.

## Findings

**TR-01 — old registry values survive a failed enrichment read.** The initial decoder returned or copied the input snapshot before updating only valid measurements. Reusing an earlier enriched snapshot with missing capacity data and malformed pack temperature therefore retained its prior health and temperature values. A pure temporary reproduction printed `missingReadRetainedHealth=true malformedReadRetainedTemperature=true`. An unknown profile or absent battery could similarly return prior registry metrics, including through the reader wrapper's early guard. Current live integration creates a new public snapshot each time, so this was a latent public decoder failure-mode gap rather than an observed live monitor failure.

**Resolved after independent repair recheck.** The decoder now clears only its owned registry metrics before qualification/read guards, preserves independent public-provider fallback values, and rejects explicitly stale/invalid/unavailable battery-presence quality. The reader wrapper invokes this invalidation without reading the registry on unknown profiles or unusable presence. Seven added regression tests cover reused snapshots, partial/missing/malformed reads, profile downgrade, the wrapper guard, stale presence and independent public temperature fallback. Current live integration still acquires a new public base snapshot for each read; this repair does not claim that an arbitrarily old observed-quality caller snapshot establishes fresh acquisition time.

No open blocking or material finding remains within this bounded read-only telemetry change.

Other reviewed behavior: the five-component model/architecture/OS-version/build/firmware profile is exact; unknown profiles receive no new registry conversion; booleans, strings, nonfinite values, fractional encodings and invalid ranges are rejected. Capacity decoding does not substitute normalized percentages or NominalChargeCapacity. Health uses the two measurements from the same read and can exceed 100%. Numeric bounds keep calculation finite. Only fixed measurement keys survive the reader boundary; raw registry dictionaries, identities and opaque buffers do not enter diagnostics. Signed current/net power remain unavailable. No thermal bounds, native action or charging capability are enabled.

## Source and evidence assessment

The independently inspected [SystemInfoKit macOS 27 implementation](https://github.com/Kyome22/SystemInfoKit/blob/main/Sources/SystemInfoKit/Repositories/BatteryRepository.swift) reads nested full/design capacities and converts pack temperature by dividing by 100. Its [measurement notes](https://github.com/Kyome22/SystemInfoKit/blob/main/MeasuredValues/README.md) explain changes in registry layout and the distinction between capacity ratios and macOS's displayed health. These are primary implementation/measurement references from that project, not Apple's stable registry specification.

Apple's [IOPMPowerSource header](https://github.com/apple-oss-distributions/xnu/blob/main/iokit/IOKit/pwr_mgt/IOPMPowerSource.h) documents historical physical capacity in mAh and electrical units. It does not itself establish the macOS 27 nested FullChargeCapacity path or pack centi-C encoding. Local capacity agreement with coconutBattery supports the selected mAh interpretation; nonsimultaneous temperatures do not prove exact sensor calibration. Keeping temperature estimated, health derived, and their UI displays approximate is appropriate.

The lead's reported latest diagnostic values were 5581 mAh full / 5760 mAh design, 96.892% derived health and 36.59°C estimated pack temperature. The separately observed coconutBattery capacity values agree; its earlier 96.6°F temperature is approximately 35.89°C. The reviewer did not obtain an additional live hardware sample or proprietary implementation evidence.

## Independent checks

Initial command:

```sh
scripts/swift-local.sh test --filter RegistryTelemetryTests > /tmp/statbatt-registry-review-tests.log 2>&1
```

Exit status **0**; **9 registry XCTest tests passed with zero failures**. A temporary program linked those debug modules and reproduced TR-01 using synthetic data. No source edits, hardware writes, SMC operations, helper installation, native action execution or messages to external parties occurred.

After the repair, the reviewer independently re-read the changed source and tests, then ran:

```sh
scripts/swift-local.sh test --filter StatBattTelemetryTests > /tmp/statbatt-telemetry-final-review-tests.log 2>&1
```

Final exit status **0**. **16 registry XCTest tests plus 8 public telemetry Swift Testing tests passed with zero failures: 24 total.** Build completed successfully. This was a targeted telemetry suite, not a claim that the reviewer reran the entire app suite for this enhancement.

The review remains of an uncommitted working-directory snapshot; Git reports no commits on `implementation/v1`. SHA-256 of the per-file manifest for the six source/test files named in this report's opening scope is `0dbb99435ae7c1a490b99beabbb624dcf17860bb41cb31e9bf310015aad04f2d`. Final local test-log SHA-256 is `28e602381052add6f9b920d69ac41236587fe4733612a7c8a0163b4e52f204ea`.

Unrun: synchronized temperature comparison, sensor calibration, thermal-control qualification, current polarity validation, UI render/accessibility inspection and hardware/native control tests. The authorized native 80% experiment remains on standby because Energiza's helper is running; this review does not change that authorization or stopping condition.
