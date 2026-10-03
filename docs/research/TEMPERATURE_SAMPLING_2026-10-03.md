# Read-only temperature comparison, 2026-10-03

The normal-user `statbatt-diagnostics --temperature-sample` command reads only fixed battery properties for 60 samples at approximately one-second intervals. It emits a platform record, samples, and a summary. It accepts no keys, output paths, or duration arguments and performs no control operation. Acquisition timestamps describe host reads, not the sensor's internal conversion time.

## Evidence

Run output: `/private/tmp/statbatt-temperature-sample.jsonl` (temporary local evidence). Process started 05:02:26.843Z and exited successfully. First sample was 05:02:27Z; last was 05:03:28Z. Platform: Mac16,13, arm64, macOS 27.0.1 (26A434), mBoot-20457.1.29.

- All 60 raw samples were valid; all app readings retained `estimated` quality.
- `AppleSmartBatteryPack/BatteryData/Temperature` initially reported 3639, interpreted as 36.39°C. The first observed change was 3609 (36.09°C) at 05:03:25Z.
- The public IOPS temperature field was absent in all 60 samples. There is no independent public temperature reading to compare on this machine.
- Parent agent restarted coconutBattery using its normal quit/reopen UI. The fresh display showed 97.5°F (36.3889°C). Immediately following that UI observation, a separate StatBatt diagnostic at 05:03:24.789Z reported 36.39°C. Agreement is within 0.01°C at displayed precision. The earlier coconutBattery display of 95.2°F did not update until reopening, so it is excluded from corroboration.
- coconutBattery's 76.3% was its 4244/5563 mAh ratio; the public macOS percentage was 80%. That distinction does not establish temperature staleness.

## Interpretation and remaining gap

This supports the candidate centi-Celsius interpretation on this exact platform and cross-application agreement at one bracketed observation. It is not physical calibration, proof that the applications use independent sensors, or a bound on sensor age. One observed change cannot establish a conversion cadence. Repeated values likewise do not establish either freshness or staleness. No heating, load generation, or charging change was used to obtain this evidence.

The minimal next qualification is another normal-use trace with timestamp-bracketed refreshed comparison readings spanning several naturally occurring changes. A controlled-temperature claim would still require a credible sensor-age policy or independently characterized update behavior; changing `estimated` to `observed` merely to admit the control reducer would overstate this evidence. This diagnostic leaves the production decoder and thermal admission policy unchanged.

The candidate conversion is independently present in [SystemInfoKit's battery repository](https://github.com/Kyome22/SystemInfoKit/blob/main/Sources/SystemInfoKit/Repositories/BatteryRepository.swift). Apple's [IOPSKeys header](https://github.com/apple-oss-distributions/IOKitUser/blob/main/ps.subproj/IOPSKeys.h) documents degrees Celsius for its public temperature field, but does not specify the private nested registry property's units or timing.

## Software validation

The diagnostics product built successfully. Three sampling tests cover invalid/raw conversion values, repeated-value cadence limitations, and gaps that must not be bridged as normal sampling. Parent's full suite passed with these included: 69 XCTest plus 105 Swift Testing tests. No hardware writes, service registration, or signing changes were performed for this diagnostic.
