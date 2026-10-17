# V1 completion increment — independent review disposition

Date: October 2, 2026. Code reviewed: `c4596ddd4046005f2147fd24df4298ea7f4214bd` against `01178b9`, including repairs atop `b664fbe`. Fresh-context reviewer did not author the increment; same model family, not a different-model review.

## Findings

| ID | Severity | Defect | Disposition |
|---|---|---|---|
| V1R-01 | Material | Probe continued after permission denial | Both metadata/read denial paths stop, preserve the attempted row and close the client/service. Source recheck and actual denied-CH0J report confirm bounded cleanup. |
| V1R-02 | Material | Sleep discarded queued recovery warning but retained its dedup ID | Sleep retains pending failure and dedup while clearing sampled crossings. Mute/settings/new boot reset pending intent. Cooldown/sleep/wake/no-spam/mute regressions pass. |
| V1R-03 | Material | Minute summary timestamps implied a state change across short sleep | Shared HistoryTimeline treats buckets as half-open intervals, fences both sides of mixed summaries and labels overlap uncertainty. Seven regressions pass, including real SQLite short-sleep aggregation and exact boundaries. |

Final review found no remaining blocking or material finding within this increment. That is not full-v1 hardware or release acceptance.

## Evidence and scope

Root ran130 tests (69 XCTest +61 Swift Testing), release packaging and strict local signature verification. Reviewer inspected source, diffs and root-produced logs, performed a mechanical defect reproduction and independent ABI layout calculation; no reviewer build, hardware run or edit was performed. Exact pinned MIT header/license provenance was verified. The normal app does not link the standalone probe.

The nonactuating target report found rejected CHTE/CH0C metadata, readable CHIE baseline00, and denied CH0J followed by successful closure. No write command, arbitrary key/value endpoint or capability promotion exists in the diagnostic. The report does not prove actuation, restoration or discharge.

Native live app/keyboard/VoiceOver, charging cutoff/lifecycle/recovery, custom controls, performance and production distribution remain unverified. [V1 acceptance](../V1_ACCEPTANCE.md) and [probe qualification](../research/SMC_READ_ONLY_QUALIFICATION.md) preserve these gates. No feature reduction or new hardware test was approved by the software review.
