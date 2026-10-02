# Independent engineering review — October 2, 2026

Fresh-context review by a separate same-model-family reviewer that did not author implementation sources. Reviewed the uncommitted `implementation/v1` working-directory snapshot: `Package.swift`, `Sources`, `Tests`, `scripts`, and `Resources`, against `CLAUDE.md`, `PROJECT_BRIEF.md`, `docs/SPEC.md`, `docs/API.md`, `docs/ARCHITECTURE.md`, and `docs/BUILD_PLAN.md`. There is no commit to identify: Git reports that the branch has no commits; the owner's configured commit email remains a placeholder. No source edits were made by this reviewer.

Delivered scope is Stage0 read-only diagnostics, Stage1 live monitoring, and pure future control/policy contracts. No helper, native action executor, or hardware mutator is installed. Hardware and restoration gates remain intentionally blocked pending lab authorization. Their absence is an acceptance limitation, not a newly introduced implementation bug.

## Finding dispositions

| ID | Severity | Finding and evidence | Final disposition |
| --- | --- | --- | --- |
| RV-01 | Material | Original `HistoryView.swift` called a full-history segment scan for every chart point, causing quadratic work on the main thread at the 10,080-row retention limit. | Resolved. `Sources/StatBattApp/HistoryView.swift:43` now traverses chronologically per metric with a moving gap cursor, and splits missing-metric intervals. Source repair independently re-read. Full-retention rendered performance is still unmeasured. |
| RV-02 | Material, future contract | Original admission accepted arbitrary normalized bytes; existing tests encoded the complete command context, including the ephemeral session token. A temporary pure reproduction rejected the same command after reconnect as `idempotencyConflict`. | Resolved. `Sources/StatBattControlProtocol/CommandAdmission.swift:34` derives canonical identity from typed `OwnerCommand`, preserves expected lineage/revision and actual intent, and excludes only the session token. Authentication remains before replay. Reconnect and restored-checkpoint regression tests independently passed. |
| RV-03 | Reliability | Original `PublicBatteryDecoder.estimateMinutes` accepted a finite extreme value then overflowed multiplication. A temporary pure reproduction returned nonfinite seconds; the UI integer conversion could trap. | Resolved. `Sources/StatBattTelemetry/PublicTelemetry.swift:73` bounds estimates, and `Sources/StatBattApp/AppStore.swift` guards finite/range conversion before display. Extreme estimate regression independently passed. |
| RV-04 | Editorial | Discovery-era state descriptions contradicted the implemented source snapshot. | README/architecture/build-plan status statements have been updated. `WORKING_RECORD.md` still described no source/no Git at the time of this final read; lead owns its final integration update. |

No open blocking or material source finding remains within the delivered monitor/contract scope after the final repair review. Final UI source review covered direct menu navigation, Settings keyboard command, explicit inactive threshold defaults, battery icons, unavailable charging reasons, temperature conversions in preferences/history, and disabled hardware controls. No new actionable source defect was found in these changes.

## Independent verification

Command run from the repository root:

```sh
scripts/swift-local.sh test > /tmp/statbatt-review-tests.log 2>&1
```

Exit status: **0**. **34 XCTest tests passed with zero failures, plus 28 Swift Testing tests passed: 62 total.** Build completed successfully. Expected environment warnings reported inaccessible user-level SwiftPM caches and deprecation of the script's native build-system option; no compilation/test errors occurred.

Snapshot identity: SHA-256 `3a3a8361c037f17b065be26a8ea74b92303f9e43ca4126c97af523cd1d8023ba` of the sorted per-file SHA-256 manifest for `Package.swift`, `Sources`, `Tests`, `scripts`, and `Resources`. Local test-log SHA-256: `58dd19af5a198f750332de35cbfdcf9f82f2cd6880b03fe6f893fc631c4cb7d9`.

Before repairs, two temporary programs under `/private/tmp` linked existing debug modules and independently reproduced RV-02 and RV-03. They performed no actuation. Final repaired source and regression cases were then re-read, and the full independent suite above passed.

Unrun: live desktop interaction, rendered UI layout, keyboard/VoiceOver operation, release performance budgets, native action/readback/restoration, helper authentication/installation, hardware writes, sleep/crash/reboot recovery, signing/notarization, and clean-machine installation/update/uninstall. Root reported the attempted desktop `getApp` inspection timed out; this review does not convert that attempt into passing UI evidence. No hardware writes, shortcut execution, helper installation, or external messages were performed during review.

The strongest remaining concern is product acceptance evidence. Native/custom control and restoration have not been verified on the exact device; this increment cannot establish completion of the requested V1 replacement. Physical capacity/current polarity and registry temperature qualification also remain conditional. Full-retention chart rendering and release CPU/memory budgets still require measurement.
