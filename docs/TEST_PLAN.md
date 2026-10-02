# Verification and compatibility plan

Established 2026-10-01. Software tests, the read-only probe, and one authorized native80% setter/readback with100% restoration ran October2; app-path, cutoff and lifecycle checks below remain future checks. See IMPLEMENTATION_STATUS.md and WORKING_RECORD.md for executed evidence. Hardware proof is distinct from compilation, policy simulation, source inspection, and repository claims.

## Requirement-to-evidence map

| Requirement | Method | Required evidence |
|---|---|---|
| MON-01/04 | Fixture tests plus public-source comparison | Adapter physically connected vs effective source; absent internal battery; event coalescing; wake invalidation |
| MON-02/03 | Unit normalization and device sampling | Unknown/zero/invalid/signed values; temperature units; health denominator; net battery watts vs negotiated adapter rating; estimate unavailable |
| CAP-01 | Provider contract tests and target probe | Keys absent/zero-size/denied/malformed vs successful; support provenance and scoped verification |
| CTL-01 | Native-action integration | Qualified target, timeout/cancellation/denial/missing or replaced UUID, approved mutable-content limitation, acknowledged vs user-confirmed state, durable unknown recovery and explicit manual100% restoration |
| CTL-02 | Fake clock + actual target | L/U inclusive edges, inside-band behavior, chatter/noise, pending write/confirmation, direction after startup |
| CTL-03/04 | Fake clock + reversible target run | Target reached, cancel, duration expiry, below-reserve rejection, unplug, wall-clock change, reboot cancellation |
| CTL-05 | Controlled sensor fixtures | Pause/resume hysteresis, unavailable/stale sensor, override does not bypass thermal protection |
| CTL-06/07 | Actual lifecycle lab | Lid close, idle/manual sleep, wake, UI exit, daemon termination/restart, reboot, helper approval revoked |
| SAFE-01 | Failure injection | Crash before/after journal/write/verification, denied restore, external state drift, uninstall only after verified restore |
| SEC-01 | Signed negative client and fuzz tests | Wrong Team ID/bundle/signature, stale revisions, idempotency replay, malformed payload, excessive event demand, no shell/key endpoint |
| UX-01/02 | Native flow and accessibility review | Keyboard/VoiceOver, both appearances, display scaling, disabled capability rationale, notification deny/mute/debounce |
| DATA-01/OPS-01 | Export/migration/package tests | Retention bounds, sleep gaps, CSV units/UTC, corrupted preferences, no identifiers, install/update/uninstall success and failure |

## Policy sequences

Use deterministic fake telemetry/clock/provider; assert both logical state and emitted operation intent, not just enum values. Important sequences:

1. 69->70->75->80->79->71->70 on70/80 custom band, including noisy observations at boundaries.
2. Cold start inside band and recovery from daemon crash with inhibition journal.
3. Override begins, policy changes concurrently, override expires: correct accepted base revision resumes.
4. Discharge starts at85 toward70, samples become stale or drop to reserve20: restore adapter and stop operation.
5. Sleep notification races with discharge request; serialization prevents re-inhibition after release.
6. External controller changes state; our cleanup never blindly writes a stale baseline over a new owner.
7. Write reports success but readback/physical observation does not change: fault, bounded retry then restore, never “working.”
8. Native action succeeds but current limit unobservable: acknowledged/unverified, no invented effective-state result.
9. Enabled custom policy -> begin native fence -> app crashes before shortcut result -> restart refuses custom enable -> native restoration/reconciliation -> fence clears but custom stays disabled. A second UID without fresh admin authorization cannot clear the owner's fence; fresh-admin restoration reconciliation may clear it but cannot enable new control. Native-only installation reconciles its journal when a helper is enrolled.

Property checks: active adapter inhibition implies verified capability, fresh battery data, valid target, nonexpired session, awake state, and explicit user intent; unauthorized requests cause zero hardware operations; revisions increase monotonically; restoration is safe to repeat; temperature policy never triggers adapter cycling.

## Compatibility registry

| Model/chip | OS/build | Firmware | Native limit | Charge hold retaining AC | Adapter inhibit/discharge | Sleep/recovery | Status |
|---|---|---|---|---|---|---|---|
| Mac16,13 / arm64 |27.0.1/26A434|mBoot-20457.1.29|80% setter/readback passed;100% baseline restored; cutoff untested|Energiza detects unsupported; our backend untested|Energiza detects variant2; writes untested|Untested|Native lab Oct2: bounded setting proof only; app integration and lifecycle unqualified |

Add separate rows for every tested Mac/firmware/OS tuple. Repository reports on other models belong in research, not this local verification registry. USB-C, MagSafe, powered display/dock, low-power adapter, and battery-only are separate test configurations. A passing M5 Air cannot establish M1–M5 coverage. Intel is out of V1.

## Lab stop conditions

Stop on permission denial, unknown key datatype/size, failed restoration, conflicting controller, stale/invalid telemetry, reserve threshold, or unexpected power-source behavior. Do not defeat Apple safety protections, grant private entitlements, disable SIP, or force deeper discharge. Disconnecting/reconnecting a charger is not assumed a universal recovery guarantee; document observed recovery for the actual backend.

For persistent SMC changes, SIGKILL cleanup cannot be guaranteed by a handler; verify launchd restart/journal restoration and bound the residual risk. If safe recovery through suspend/power loss cannot be established, do not ship that backend as supported.

## Release evidence

Archive source revision, toolchain, signing identity/team IDs (no secrets), compatibility rows, test commands/results, failed checks/dispositions, licenses, artifact checksums, install/remove trace and performance sample. Developer ID/notarization is not a hardware support test. A documentation audit is not an implementation test.

## Implemented native increment evidence

The native suite uses injected nonhardware transports and closed subprocess fixtures. It verifies target/trust/baseline/conflict admission, UUID replacement/ambiguity, durable pre-dispatch intent, no replay across restart, journal failure gating, single-account lock and file permission/symlink checks. Timeout, cancellation and overflow receipts require observed child termination; SIGTERM-ignoring fixtures assert the owned child is absent at receipt. Recovery requires an explicit finished/stopped declaration before recording100%. This does not prove the Shortcuts library action stopped or establish effective cutoff/lifecycle behavior. See handoffs/2026-10-02-native-limit-review.md for independent recheck.
