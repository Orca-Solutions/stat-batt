# Implementation checkpoint — October 2, 2026

> Monorepo paths: app sources and commands now live in `apps/statbatt/`; historical verification commands below describe their original location. See [current app instructions](../apps/statbatt/README.md).

Owner authorized the agreed v1 implementation and team in the current Codex conversation. This supersedes discovery-only status in the October 1 documents. The implementation remains in progress; hardware lab authorization, helper installation, and release authority were not implied by that approval.

## What runs

A native SwiftUI menu bar app and detail window with Battery, Charging, History, and Settings tabs. Live monitoring uses IOPowerSources, a 30-second fallback sampler, coalesced change notifications, current thermal-state observation, and workspace sleep/wake notifications. Read-only registry enrichment uses reported ExternalConnected/CycleCount plus an exact-target nested capacity/pack-temperature profile (see research/MACOS27_TELEMETRY.md). The diagnostic identifies model/build/firmware without serials.

Local SQLite records seven days of one-minute means, latest charging/source observations, and explicit sleep gaps. Missing values export as empty CSV cells. Preferences are validated and atomically saved; malformed/newer versions are surfaced without silently discarding the original. Login item registration and notification permission are opt-in OS flows; production signing validation remains pending.

The deterministic domain reducer covers inclusive hysteresis, fresh telemetry, wake barriers, continuous-clock deadlines, reserve protection, thermal hysteresis, native fencing, and restoration-before-hold plans. These are operation intents, not hardware execution. The protocol module supplies bounded strict request DTOs and in-memory session/replay/CAS/fence contract harnesses. It runs no listener and no privileged service.

## Acceptance map

| IDs | Implemented evidence | Remaining acceptance |
|---|---|---|
| MON-01 | Public percentage, state, source; separately reported connection flag; decoder tests and live diagnostic | Physical charger transitions/source comparisons and connection-flag semantics during adapter inhibition |
| MON-02/03 | Units/origins, cycles, observed physical FCC/design and derived health on exact target, estimated pack temperature, public voltage/adapter/ETA decoding | Synchronized sensor comparison/bounds, raw SOC, signed current/power; adapter rating when reported |
| MON-04 | 30s idle fallback, event coalescing, refresh on request, sleep/wake invalidation | Measured CPU/RSS, prolonged sampling/hot-plug; active5s watchdog awaits daemon |
| CAP-01 | Independent unsupported/unknown controls with reasons; exact fingerprint | Scoped control evidence and denial/restore lab results |
| CTL-01 | Trusted mutable-workflow setup, UUID binding, fixed80% normal-user runner, intent journal/lock, explicit acknowledged/observed/manual-restored states; lab80% setting/readback and100% restoration | Live app path, cutoff and lifecycle; other targets and automatic restoration unavailable. Owner-approved trust exception in decision0002 |
| CTL-02–07 | Pure validation/reducer safety tests; controls visibly disabled | Qualified provider, serialized persistent daemon, hardware/lifecycle matrix |
| SAFE-01 | Native pre-dispatch journal, restart fencing and explicit manual recovery; no installed helper | Real native crash/library-action lifecycle; durable privileged restoration and two-phase helper uninstall |
| SEC-01 | Typed bounded strict requests; connection-bound sessions and synthetic replay/CAS/fence tests | Production signed XPC listener, OS admin right, durable idempotency and journals, negative signed-client tests |
| UX-01 | Native panel, details, mode rationale, settings; accessible labels and text states; owner-supplied current native setup screenshot | VoiceOver/keyboard, both appearances, scaling and all future control states |
| UX-02 | Opt-in charging/low-battery/temperature alerts with cooldown; thresholds configurable | OS permission/notification delivery, failure alerts after a real service exists |
| DATA-01 | SQLite bounds, summaries, CSV, clear, sleep gaps; storage tests | Prolonged real sleep/retention and migration qualification |
| OPS-01 | Redacted local diagnostics; ad-hoc local app packaging | Helper lifecycle, protocol mismatch handling, signed updates/notarization |

No firmware/OS inference unlocks a control. Unknown temperature remains unavailable, and public capacity percentages are never used as physical mAh. No repeated adapter cycling, fake live fixtures, load-based discharge, shell/key endpoint, network account, analytics, private entitlement, or CI change was added.

## Target observation

The October 2 read-only diagnostic observed `Mac16,13`, arm64, macOS27.0.1/build26A434, `mBoot-20457.1.29`. Internal battery presence, percentage, charging flag, attachment, supplying source, cycle count, and system thermal category were reported. This identifies a test target; it does not qualify native/custom charging or sensor conversions.

## Software verification

Latest integrated suite:102 tests passed (50 XCTest+52 Swift Testing), zero failures. Build2 release bundle/ad-hoc signature checks pass after the Settings copy/metadata follow-up. Independent engineering, telemetry, native and product-design consultations are saved in handoffs/. Owner-supplied screenshots establish rendering of the current native setup state and matching target fingerprint; interaction/accessibility, other appearances/scaling and release resource budgets remain unverified. The earlier authorized native80% setting/readback test passed after the owner stopped Energiza’s helper; the original100% setting was restored and reverified. See research/NATIVE_LIMIT_LAB.md. Later native integration evidence is below.

## Next gate

Follow [LAB_PROTOCOL.md](LAB_PROTOCOL.md). Native setting changes and privileged control experiments need explicit authorization and observed recovery. Unsupported backends remain an unaccepted gap against full v1. A full helper will only be implemented for a backend that passes its proof/recovery gate; no unused privileged daemon is installed speculatively.


## Native integration trust and launch follow-up

Supported Apple interfaces run a library shortcut but the bounded investigation found no documented complete content inspection or immutable execution binding. Identity/action count alone cannot detect replacement of one action or edits to its parameters. The owner subsequently approved trusting the configured mutable workflow; decision0002 records that exception. See research/NATIVE_SHORTCUT_TRUST.md and the native integration increment below.

Product design recommended a one-time Battery dashboard on the first interactive launch; later/login launches stay quiet and closing the window leaves menu-bar monitoring active. This is implemented with SwiftUI's macOS15 scene-launch API and a UI-only shown flag, saved after presentation. Deployment minimum is now15; qualification remains on the macOS27 target only. The app process was observed running normally and its shown flag was recorded. Desktop control then closed its native pipe, so no screenshot, keyboard or VoiceOver pass is claimed. Post-change release build, signature verification and all78 software tests pass.


## Native integration increment after owner approval

Owner approved trusting the shortcut after disclosure of undetectable edits. StatBattNativeLimit now owns exact-target80% setup/admission, a bound UUID, fixed `/usr/bin/shortcuts` jobs, an owner-only bounded atomic/fsync journal and same-account lock, pre-dispatch intent, no replay after unknown outcomes, and explicit user-confirmed observation/restoration. The app wires one-time setup, deliberate Apply80%, verification and manual recovery through the product-designed native card. Runtime diagnostics include native state without library identities. Other users/controllers are outside the advisory lock's scope.

The known Energiza helper/GUI check and the user's other-controller declaration block conflicting setup/dispatch. Missing/replaced/ambiguous shortcut identity and journal faults disable requests. Only the accepted mutable workflow is trusted; full content inspection is unavailable. A completed CLI remains unverified, while timeouts/failures/restarts require manual review. Recovery also requires the owner to confirm that the prior shortcut finished or was stopped before recording100% restoration. Shortcuts may outlive its CLI; stopping that command is not proof that the action stopped.

The empty lab artifact was repurposed into **StatBatt — Apple Limit 80**, inspected with exactly one Apple80% action, saved, and found exactly once by read-only UUID listing. It was not executed during this increment, and app setup confirmations were not fabricated. End-to-end app Apply is still unrun.

The first integrated suite before final review repairs passed99 tests (50 XCTest+49 Swift Testing), including21 new native tests and real nonhardware fixed subprocess fixtures. Independent review caught an early-return-before-CLI-exit race and misleading discovery copy; final repairs and recheck are recorded in WORKING_RECORD and the native review handoff. No hardware control test was repeated. Full v1 remains in progress.

Final native increment verification: `scripts/swift-local.sh test` passed102 tests (50 XCTest+52 Swift Testing), zero failures; `scripts/build-app.sh` and `codesign --verify --deep --strict dist/StatBatt.app` passed. Independent native recheck passed24 tests and resolved both material findings. Final UI tooling showed an old process ID inconsistent with a live read-only process check, then its native pipe closed. The rebuilt bundle is available, but no fresh live setup/Apply or accessibility pass is claimed.

Build2 follow-up: added a Bundle-derived Settings version row (0.1.0(2)) and corrected Settings quit/manual restoration copy; release build/signature passed and product design source-rechecked both changes. Owner quit was verified by no process matches; Finder launched a new candidate process at08:29:54. Desktop binding still timed out, so no updated visual or interactive pass is claimed. The supplied08:26 screenshot is of the earlier static-card build.

## Current setup screenshot evidence

Owner supplied08:35:21 and08:35:27 screenshots after the verified build2 restart. The new Charging screen renders the trusted setup, reports the expected shortcut found, shows all three declarations unchecked and Record trusted setup disabled, and keeps custom/discharge controls visibly unavailable. The separate compatibility image matches the qualified model/architecture/OS/build/firmware and says no privileged helper is installed. This establishes current setup rendering and displayed discovery status; it does not establish setup persistence, actual Apply/verification/restoration, current Battery settings limit or accessibility behavior. Local screenshot copies remain ignored in .build; product design's static review is in the handoff.

Product design rechecked both current08:35 screenshots at original resolution and found no material visual issue at that size/light appearance. The08:36 owner diagnostic reports nativeState=notConfigured (expected while the setup declarations are unchecked), estimated temperature27.09°C and derived health96.94%; current/power/voltage/OS condition remain unavailable. Native Apply/recovery and custom controls remain outside current acceptance evidence.
