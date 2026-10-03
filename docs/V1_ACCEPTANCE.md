# V1 candidate acceptance — October 3, 2026

The native charging baseline follows [decision 0004](decisions/0004-native-charging-v1.md): working Apple 80% / 100% buttons plus monitoring. The owner subsequently requested optional temperature control by disconnecting adapter input in [decision 0005](decisions/0005-investigate-thermal-adapter-control.md). That feature is under separate investigation and is not a shipped capability. Native installer acceptance proceeds independently; the overall temperature request remains open until qualification succeeds or a concrete blocker is reported.

| Area | Implemented evidence | Remaining validation |
|---|---|---|
| Native 80% / 100% | Both fixed Apple shortcuts independently observed in Battery settings; owner tested both build 7 app buttons successfully; persisted trust and intent/recovery/no-replay tests | New installer onboarding on a clean user account; abnormal sleep/reboot observation; no precise physical cutoff claim |
| Shortcut setup | Signed inspected workflows bundled; both Apple import previews opened and showed the correct single action; app offers only missing targets, then explicit trust; existing setup preserved. Apple’s Add Shortcut approval is unavoidable per user | End-to-end clean install/import/trust on another account/device |
| Monitoring | Public telemetry and target-specific enrichment; invalid/stale/pre-wake normalization tests | Broader sensor/device comparisons and physical source configurations |
| History/export | Seven-day minute summaries, sleep gaps, invalid/missing data handling, CSV and clear | Long-duration real retention/sleep checks |
| Notifications | Opt-in battery/source/temperature/failure alerts and tested debounce | Owner OS permission and real delivery smoke test |
| UX | Native keyboard-accessible controls, text state, unavailable controls removed from primary workflow | Full VoiceOver, both appearances and scaling sweep; CUA cannot bind this app reliably |
| Resource use | Build 5 closed-window 10-minute sample: 0.1583% CPU, 79.23 MB peak RSS | Installer candidate has not repeated the long-duration resource measurement |
| Distribution | Repeatable local app/package build; bundled integrity checks; public pipeline fails closed without signing configuration; read-only image acceptance script | Apple Development identity exists for local builds. Public Developer ID signing/notarization is explicitly deferred by the owner. Clean-account install/update/remove remains unexecuted |
| Optional adapter-temperature control | Scoped cut/restore, owner-loss and sleep lab evidence; local UI/XPC/recovery integration and fixed two-second Swift guardian candidate implemented; normal package write gates closed | Build 11 implements worker recovery, estimated-sensor convenience admission, recurring session/lease plumbing and protected update/removal; exact-build hardware/lifecycle and longer-pause qualification remain outstanding |

The application is a local v1 candidate. A local ad-hoc signature or package does not mean public release readiness. Exact charging qualification remains Mac16,13 / arm64 / macOS 27.0.1 / 26A434 / mBoot-20457.1.29. No privileged helper is installed or needed for the native baseline. Any helper or guardian required by optional temperature control must pass its own security and recovery acceptance before shipping.


## Non-invasive installer acceptance

`apps/statbatt/scripts/verify-package.sh /absolute/path/to/image.dmg` verifies the
disk image, mounts it read-only, checks the app signature, Info.plist, both pinned
shortcut exports, third-party notices and Applications link, then detaches it.
It never launches StatBatt, imports a workflow, or changes existing trust. This
validates package contents, not a first-run user experience.

Automated setup-plan tests cover no shortcuts, one installed shortcut, both
installed, unknown/ambiguous lookup, missing bundled assets, unsupported platform,
controller conflict, recovery and in-flight operations. Actual Apple import
previews were inspected for both artifacts and cancelled before Add Shortcut.
These checks preserve the owner's working library and saved trust.

Full first-run acceptance needs a separate macOS user account on the qualified
Mac (or another independently qualified machine). Copy the packaged app, open it,
add each bundled shortcut through Apple's approval, return and enable controls,
then verify both targets in Battery settings. Cancel/resume and relaunch-mid-setup
should also be exercised. Creating a user account or deleting the owner's existing
workflows/trust just to manufacture a clean install is not part of this validation.

Package inspection completed for `StatBatt-1.0.0-8-LOCAL-PREVIEW.dmg`: image
checksum valid; read-only mounted app signature and Info.plist valid; both pinned
shortcuts and third-party notices present; Applications link correct; no adapter
lab executable included. The volume was detached after inspection. Companion
SHA-256 verification passed. Public packaging without credentials was checked
and rejected before building. These results do not close the clean-account or
public-notarization rows above.

## Local background integration follow-up

See [local integration and remaining gates](research/THERMAL_LOCAL_INTEGRATION.md). Build 9 is a local development integration candidate, not an accepted automatic temperature controller. Its protected first-install package preserves the existing native app and shortcuts. A separate source-gated one-shot candidate may test one two-second adapter interval; passing that test cannot enable automatic policy. Public notarization is deferred and is not the reason temperature control remains unavailable.

## Build 11 follow-up

Build 10 is installed and restored, but is not complete v1 temperature control. Build 11 is prepared with 218 passing software tests and installer admission fixtures. Automatic admission remains disabled pending exact-build electrical and lifecycle qualification. Public signing/notarization are deferred by owner direction, not blockers to this local test. See [integration checkpoint](research/THERMAL_LOCAL_INTEGRATION.md) and [fixed candidate](research/THERMAL_APP_ONE_SHOT_CANDIDATE.md).

Build12 follow-up: the owner-operated two-second app-path test returned fresh battery-supply observation and verified restoration, corroborated by the retained UI result and authenticated service status. The independent user-level trace stayed on AC; this limitation is retained. Automatic temperature control remains unavailable pending exact-guardian crash/sleep and longer-pause qualification.


Guardian-loss follow-up: the exact installed Swift guardian was terminated after
fresh08+battery evidence. Its independent worker restored00+adapter before any
supervisor cleanup, without fallback; separate journal cleanup and final inspection
passed. See [recorded qualification](research/THERMAL_GUARDIAN_LOSS_QUALIFICATION.md).
This closes guardian-process loss for the tested two-second mode only. It does not
qualify a longer pause, simultaneous worker loss, or the full automatic session.

Remaining temperature work has two broad areas, not a guaranteed two test cycles:
(1) implement and qualify a useful bounded pause duration, including independent
restoration and telemetry/reserve stop rules; (2) qualify the integrated automatic
session through sleep/wake, disable/quit, owner/service loss, and native-control
handoff. Some failure branches can be tested offline; installed hardware evidence
must cover the exact candidate and actual branch. No synthetic heat or stress load
is required. Public signing/notarization remains deferred.
