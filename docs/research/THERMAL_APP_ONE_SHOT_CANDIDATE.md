# Prepared app-path adapter candidate — October 3, 2026

This is a supervised local qualification candidate, not an automatic temperature controller. Public signing/notarization are deferred. The build 9 attempt was inconclusive; build 10 is now installed with improved feedback. Historical preparation details below are retained as evidence, not current pending actions.

## Identity and package checks

Source checkpoint `37857bf`, with exactly six inhibition/recovery gates enabled in an isolated source copy. The packaging-only follow-up fixes a missing relocation metadata property and excludes shared ancestor directories from the package payload. Normal repository gates remain disabled. The candidate includes the final SIGPIPE fix and inherits the 200 passing default software tests; closed-default-gate tests are not claimed to pass against an enabled candidate.

Apple Development signature: fixed app `dev.statbatt.local`, daemon `dev.statbatt.control-daemon`, guardian `dev.statbatt.adapter-guardian`; Team `TWZA95CB7G`. Strict signatures verified individually on the extracted payload. Every signed source file's hash matches its extracted package counterpart. Both bundled shortcut files are preserved unchanged. The BOM contains only the StatBatt folder payload, root ownership and restricted write permissions; relocation is disabled. The postinstall creates a separate launcher without replacing the existing app. Package construction printed metadata write warnings, but extracted contents, signatures and byte comparisons passed.

Package: `apps/statbatt/dist/qualification/StatBatt-9-ONE-SHOT.pkg`

SHA-256:
- Package: `900caa2f46c3f77e5d7f6cea8eb3eccc7af99d32bf5f57eb4bbe936d043a5a05`
- App executable: `2d1c8a93e7be13f5394af2347945846201e33f4a15d6ac0db0dd147338cfa93b`
- Guardian: `44755016021bd3638607b96bbbca9cb020b1d580b9af6d2097547a260d13e721`
- Daemon: `931bf9b10ebce8863bee4c508cce5712dd81fa19e28d5ae7c8059111197e9cb6`

## Proposed authorized sequence

1. Install the verified package into `/Library/Application Support/StatBattLocal/StatBatt.app`; macOS Installer requires administrator authorization. It preserves the existing native app and shortcuts and does not register or start the service. Verify installed identities/ownership. Quit the old native app before opening the new one. Register the authenticated service as the signed-in user; any OS background approval is owner-operated.
2. Read fresh status and require exact target Mac16,13 / arm64 / macOS27.0.1 / build26A434 / mBoot-20457.1.29, normal thermal pressure, AC supply/attachment, charge >=50%, no conflicting controller and no unresolved ownership. Preliminary public check reported AC attached and80%; it is not the admission sample.
3. With separate owner authorization, press **Run one 2-second adapter test** once. Persist ownership before the guardian writes only CHIE one-byte `00 -> 08`; fixed independent guardian deadline is two seconds and cannot be renewed. Observe fresh key readback separately from physical battery supply. App/daemon loss closes the guardian owner connection; sleep/cancel/deadline stop and reap its writer before `08 -> 00`. No Apple charge-limit setting, synthetic load, sleep request or recurring policy is part of this test.
4. Require fresh zero readback plus AC supply and durable restoration acknowledgement. If unknown, preserve the service and journals, stop further experiments and use the owned restore action; do not uninstall. Do not automatically repeat an inconclusive trial. Guardian-process death itself remains an unqualified case; this experiment does not deliberately kill the guardian.

Installer is prepared at its final Install screen. The launchd daemon label `dev.statbatt.control-daemon` was absent before installation. The old native build8 app was still running. No new adapter write has been dispatched.

Owner authorization: after the package identity/checks above were prepared, the owner explicitly replied **“Yes, install and run the two-second test.”** This authorizes the bounded installation/registration and one app-path trial described above, not repeated experiments or unattended control. Installer's Install button has been pressed; administrator authentication/completion is pending. No hardware test has yet run. A separate fixed, read-only public-power-source observer was prepared to capture the brief physical transition independently of the XPC result.

Installation completed with owner-entered administrator authorization. Installed executable hashes match all three recorded candidate hashes; bundle/guardian parents are root0755, and `/Applications` remains root0775. The separate launcher points to the protected bundle. Same-team strict installed signature validation passed. User-context SMAppService registration returned enabled; launchd identifies bundle version9 and the expected daemon/team. The old native-only PID10378 was closed; installed app PID15013 and daemon PID15014 were observed running. No additional Background Items approval was needed.

The UI automation tool timed out attaching to the new StatBatt app, although process and launchd checks confirm it launched. The owner has been asked to press the already-authorized test button once while a separate 100ms public IOPowerSources trace records source changes. Trace: `/private/tmp/statbatt-app-one-shot-source.jsonl`. No result is inferred from installation/registration alone.

## Observed outcome and feedback repair

The owner reported pressing the one-shot button; it then disappeared/was disabled, and Check status showed no visible result. Their08:52:19 screenshot showed the service's generic unavailable message and estimated27.6°C. The completed independent trace contains3000 samples from15:50:46.017Z through15:55:58.225Z, all adapter supply (SHA256 `af08de550e840b885679fecc17e33750c97ab8e991794f66dfbcc6fe58788287`). This does not prove that no key write occurred; it does mean no physical transition was observed. The trial is **inconclusive**, not accepted and not automatically repeated.

A new same-team signed read-only diagnostic client queried the existing service. Concurrent UI polling initially yielded no fresh reading. After closing the UI with an authoritative safeToExit acknowledgement, a quiescent query confirmed `adapterRestored:true`, `safeToExit:true`, no further qualification available, and estimated27.39°C. Evidence is `/private/tmp/statbatt-post-test-quiescent-status.json`. Public power status also remained AC attached at80%. No extra hardware test was sent.

Source fixes retain test outcomes independently of generic refresh messages, show manual status-check progress/timestamps, coalesce concurrent client refreshes and backend inspections, and record bounded sanitized launch/precondition/key/source/restore diagnostic events. Unregistration now requests prepareUninstall and requires safeToExit rather than using the legacy non-actuating status. All204 software tests pass. These source fixes are not yet deployed to the protected service. The old trial's exact failure cause remains unknown; startup consuming the observation budget or a precondition rejection are hypotheses only.


## Installed build 10 — current state

The protected update completed and installed executable hashes were verified against the reviewed build 10 payload. The service is registered. A subsequent read-only status confirmed `adapterRestored: true`, `safeToExit: true`, `controlAvailable: false`, and `qualificationAvailable: true`. These observations show a safe baseline; they do not accept the earlier test or authorize a repeat.

The outcome persistence, manual status feedback, coalesced reads and diagnostic improvements above are now deployed. Automatic temperature control remains unavailable. No build 10 hardware test is recorded. The build 9 all-AC trace remains the only independent app-path trial trace documented here. A newly available qualification button is not evidence that any test ran.

Local update admission validates the stopped app/service, root-owned existing installation, same-team signatures, resolved ledger and fresh read-only zero/AC samples. Installer scripts perform no restoration or registration. Guided protected bundle removal is now implemented in source, preserving recovery journals and user-owned shortcuts, but is not yet deployed or live-tested. Public notarization remains deferred.

## Build 11 prepared follow-up — not yet executed

Prepared isolated source: `/private/tmp/statbatt-v11-candidate-b9znmgcm/statbatt`; manifest and six-line gate diff are adjacent. Automatic qualification record is nil. The revised worker adds independent EOF/sleep/deadline restoration, excludes startup from the two-second lease and keeps output nonblocking. Software suite: 218 tests pass; preflight fixtures pass.

Package: `apps/statbatt/dist/qualification/StatBatt-11-ONE-SHOT-UPDATE.pkg`. Apple Development signatures and fixed-team identities verified; all 13 payload files match the signed source. Fixed install location and build11 metadata checked.

| Artifact | SHA-256 |
|---|---|
| Package | `dce35ea883ba867bc8618c1db523f05e04fcdb8d3670a6d6550107b8d7be1e1f` |
| App executable | `7d90a6512ce0072881f1b063d2dcdc3a17e0fb873cc33118ea3ce87adcef7699` |
| Daemon | `c71ed9bdac847efe2eb4581cd2cb3d3cb0007bc259e1271a8a5877de26fcaf59` |
| Guardian | `673176cd92b7374fa01b194dac8491ed1e1a05094424f2c5a3a96c466642cd62` |
| Removal helper | `e912ed8070c4e411ea678911f49c7ae2e7d57def86d39ba996aea7de6d6cfa37` |

Requested operation: one supervised fixed CHIE00→08→00 interval on the previously recorded exact Mac/OS/firmware, normal thermal state, fresh AC and zero baseline, SOC≥50%, charger attached and lid open. Independent guardian and worker restoration deadlines remain two seconds, with bounded restoration observation afterward. No artificial load, native-limit changes, sleep injection, repeat or automatic policy. Unknown outcome preserves recovery ownership and stops further experiments. The owner explicitly approved installing build11 and running this one test in the current conversation. Build11 installation is complete: installed app/daemon/guardian hashes match the table; service registration succeeded. Fresh status reports adapterRestored=true, safeToExit=true, nativeReconciliationRequired=false, qualificationAvailable=true. Public power report shows AC attached at80%; temperature estimate24.19°C. The approved test has not yet run; the owner has been asked to press once while the independent source observer records. The build9 authorization remains consumed.

### Build 11 owner-attempted request

Owner screenshot records a failed reply at11:00:55 local time. The daemon subsequently reports qualificationAvailable=true with no qualificationResult and launchd runs=1. Thus there is no recorded accepted runtime test and no daemon restart explaining lost state. Fresh read-only status confirms adapterRestored=true and safeToExit=true. Independent trace covers the reported request time and shows only adapter supply. No hardware retry was issued. The earlier statement that an available button proved no user attempt was incorrect; UI dispatch/rejection and hardware admission are distinct.

Code inspection found an app request race: automatic status reads do not mark UI busy, so a click may send a second request on the same connection while the service permits only one. The client previously collapsed every error into unknown outcome, so the exact rejection code from this attempt is unavailable. This is a concrete defect and plausible explanation, not a proven historical error code. The fix serializes connection requests, never retries mutations, checks command supersession before dispatch, and retains bounded error information. Two new software regression tests pass.

## Build 12 app-only correction — prepared

Source stage: `/private/tmp/statbatt-v12-candidate-kstxn1ht/statbatt`. Packaged signed app version12 fixes per-connection request serialization and retains sanitized rejection details. Daemon, guardian and removal helper are byte-identical to build11. Two focused regression tests pass and release app compilation succeeds. No hardware retry has occurred; new approval is pending.

Package `apps/statbatt/dist/qualification/StatBatt-12-ONE-SHOT-UPDATE.pkg` SHA256 `aa0e0514ba24a298f7552dffa3148194a0b4af4b3b74bbacc1f07a12817e2963`; app executable SHA256 `ac2484aea362627bcc1310078bce85f8ac1e427c7c6090a97fb12a092cfc5a69`. Package builder checked Apple/team signatures and shortcut integrity; expanded payload matches signed files.

Build11 independent trace completed3000samples from17:58:35.642Z to18:03:47.892Z, all adapter. Trace SHA256 `aee6b9beaf0a42d8c47058a3b0f737598c0078bd065e49186d183b39d8b4ae9a`. This covers the screenshot's18:00:55Z outcome; it does not prove no transient write shorter than sampling.
