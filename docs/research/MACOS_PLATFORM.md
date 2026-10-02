# macOS battery platform feasibility

Research date: October 1, 2026. This is a foundation for implementation, not a compatibility certification. No software was installed, no SMC writes were performed, and charging was not changed during this investigation.

## Findings and evidence levels

- **Verified source:** a statement directly present in an Apple document or inspected source code. This verifies the document/code, not that hardware will behave as expected.
- **Claim:** an upstream maintainer or contributor reports behavior; not independently reproduced here.
- **Inference:** a design conclusion drawn from that evidence.
- **Hardware-unverified:** the proposed behavior has not been exercised on the target Mac/build/firmware.

**Recommendation:** build a native monitoring app and prove the available charge-control backend before promising Energiza parity. Apple provides a supported 80–100% charge-limit feature and a Shortcuts action. Independent upper/lower thresholds and forced discharge remain dependent on undocumented hardware control. An adapter-cutoff fallback may work on newer firmware, but changes how the Mac consumes battery power.

## Evidence on the user's current machine

The coordinator's read-only checks found macOS **27.0.1, build 26A434**, on **arm64**. This confirms the host OS and architecture only. The exact model, firmware, and control behavior are not verified by those commands.

The coordinator inspected the authorized local Energiza helper log. Its two recent launches report unsupported charge-control variants, support for virtual adapter disconnection variant 2, and repeated unsupported-operation errors. An `SMCKit.SMCError` enum value is not sufficient to identify an Apple kernel error. The log suggests separate charge and adapter capabilities; it does not prove that either write operation works, or that the failure is caused by the entitlement change described below. See [local failure investigation](ENERGIZA_FAILURE.md).

## Supported monitoring surface

Use public `IOKit.ps` APIs: `IOPSCopyPowerSourcesInfo`, `IOPSCopyPowerSourcesList`, `IOPSGetPowerSourceDescription`, and `IOPSNotificationCreateRunLoopSource`. Apple documents nullable descriptions and missing dictionary keys, so missing values must remain unknown. Do not convert missing telemetry to zero. [Apple API documentation](https://developer.apple.com/documentation/iokit/1523867-iopsgetpowersourcedescription)

Apple's published `IOPSKeys.h` defines capacity, power-source state, charging state, ETA, health, voltage/current/temperature, and adapter watts. Capacity fields can be percentages or provider-specific units; reported max capacity is often 100, so it is not automatically physical full-charge capacity in mAh. ETA `-1` means calculating, and charge/discharge ETAs have state-dependent validity. Optional design/nominal capacity keys may be absent. Adapter rated watts are not measured instantaneous power. [Apple source header](https://github.com/apple-oss-distributions/IOKitUser/blob/main/ps.subproj/IOPSKeys.h)

**Design inference:** event-driven snapshots with a modest fallback refresh are preferable to a tight polling loop. Keep basic monitoring outside the privileged helper. Select the internal battery rather than accidentally treating a UPS as the laptop battery.

Detailed statistics such as cycle count, physical full-charge capacity, manufacture date, cell voltages, and raw SOC may require `AppleSmartBattery` IORegistry properties or SMC telemetry. Public IORegistry access does not make each property name/unit a stable Apple contract. Validate these fields independently on each supported family. Some temperature and current properties use different encodings or sign conventions from public IOPS keys; never apply one source's conversion to another. Store field provenance, observed units, freshness, and availability. Health ratios require compatible units and a nonzero denominator; show an estimate distinct from Apple's health status.

## Native macOS charge limit and Shortcuts

**Verified Apple behavior:** Charge Limit requires Apple silicon and macOS Tahoe 26.4 or later. Apple exposes settings from 80% to 100%; charging ends near the selected value, resumes after a drop greater than 5%, and occasionally reaches 100% for SOC estimation. The built-in action therefore does not promise a mathematically exact ceiling or independent resume threshold. [Apple charge-limit documentation](https://support.apple.com/en-gb/102338)

**Verified supported integration surface:** Apple lists **Set Battery Charge Limit** as a macOS 26.4 Shortcuts action. Its documented CLI can run an installed shortcut with file input/output; it reports success/error through exit status, and interactive shortcuts may wait for user input. [Apple Shortcuts release notes](https://support.apple.com/en-gb/125148), [Apple Shortcuts CLI guide](https://support.apple.com/en-nz/guide/shortcuts-mac/-apd455c82f02/mac)

**Proposed NativeShortcutBackend — hardware-unverified:** provide a small, inspectable shortcut that invokes that Apple action, run it in the logged-in user's context with direct process arguments and a timeout, and observe the requested/native state where a supported getter is available. Prove exact values, import permissions, unattended execution, logout behavior, readback, and restore semantics on 27.0.1. Successful process exit is an accepted command, not proof that battery current changed. Do not run arbitrary user-named shortcuts from a root daemon. Do not assume a public Swift setter or native limit getter exists: neither was established in this research.

This is the preferred first feasibility spike for an upper limit of at least 80%. The app's own App Intents would expose app actions to Shortcuts; they do not themselves grant privileged charge control.

## Undocumented control paths

| Candidate backend | Mechanism evidenced in source | Semantic limits | Qualification status |
| --- | --- | --- | --- |
| Native Shortcut | Apple's built-in action | Native upper range; Apple chooses resume timing and may do full charges | Official action exists; app integration untested |
| Legacy SMC charge switch | `CH0B`/`CH0C` or `CHTE` on Apple silicon | App enforces hysteresis while running; adapter can stay active | Source implementation exists; inaccessible on some newer firmware |
| Firmware SMC range | `bfF0`, `bfD0`, `bfE0` | Firmware enforces lower/upper range; firmware may discharge above target | Source implementation exists; recent gating reported |
| SMC adapter switch | `CHIE` or older adapter keys | Mac runs on battery while cut off; more cycling; awake control loop | Recent upstream author test exists; target untested |
| Private PowerUI | `PowerUISmartChargeClient` in private framework | Native supported limits; unknown long-term ABI/permission stability | Actual code inspected; unsuitable as a public API assumption |
| Monitor only | Public IOPS with optional registry telemetry | No charge/discharge control | Required graceful fallback |

The inspected `batt` charge implementation chooses firmware or legacy mechanisms by usable keys, not the OS number; it includes length/type checks, validates the range, and avoids rewriting an already correct firmware limit. Different SMC paths have different encodings. The source is evidence for an adapter design, not permission to write guessed values. [Charge backend source](https://github.com/charlie0129/batt/blob/master/pkg/smc/charging.go), [Apple silicon key declarations](https://github.com/charlie0129/batt/blob/master/pkg/smc/consts_arm64.go)

**Claim:** `batt` issue 152 reports macOS 27 beta 8 (`26A5425a`), firmware `20457.1.29`: legacy charge keys become zero-size; firmware charge keys and smart-battery registry writes fail with `kIOReturnNotPrivileged` even as root. Its attribution to `com.apple.private.iokit.soc-limit` is a contributor's investigation, not a documented third-party entitlement grant. A readable key or root access must not be represented as proof of writable control. [Issue 152](https://github.com/charlie0129/batt/issues/152)

**Verified source + claim:** merged `batt` PR 154 introduces an opt-in adapter loop, cutting wall power above the upper threshold and restoring it below the lower one. Its author reports tests on an M5 MacBook Air with firmware `20457.1.29`. The author explicitly distinguishes awake enforcement from a firmware ceiling. This is promising evidence for a fallback, but has not been verified here on macOS 27.0.1. [PR 154](https://github.com/charlie0129/batt/pull/154), [frozen merge commit aa9b6ffc3e8f8f465333387a3a3664037db31f8e](https://github.com/charlie0129/batt/commit/aa9b6ffc3e8f8f465333387a3a3664037db31f8e)

**Verified source:** `batt` dynamically loads `/System/Library/PrivateFrameworks/PowerUI.framework`, obtains `PowerUISmartChargeClient`, and invokes native-limit selectors dynamically. Its source comment records observed method encodings on macOS 27.0 build `26A428`. This is a private framework integration, even though the resulting setting is an official Apple feature. Keep it experimental unless explicitly selected after the supported Shortcuts approach has been evaluated. [PowerUI implementation](https://github.com/charlie0129/batt/blob/master/pkg/powerui/powerui.m)

Intel SMC charge control uses different keys in older tools; Apple silicon findings cannot be generalized to Intel. Target the user's Apple silicon system first; Intel support needs its own OS support check, transport, fixtures, and hardware qualification. USB-C versus MagSafe likewise changes LED availability independently of charging capability.

## Sleep, wake, shutdown, and competing owners

Apple distinguishes idle sleep from forced sleep. Notifications and assertions do not reliably prevent lid-close, user-requested, low-battery, or thermal forced sleep. Power callbacks require prompt acknowledgement. [Apple QA1340](https://developer.apple.com/library/archive/qa/qa1340/_index.html)

**Requirements inferred from the platform:** every backend declares `awakeOnly`, `firmwareManaged`, or `nativeManaged` enforcement. On wake, refresh physical battery/source state, re-probe capabilities when needed, then reconcile once. Avoid concurrent policy transitions and sleep callbacks; serialize through the policy owner. Do not present a software discharge floor as a guaranteed shutdown cutoff, and do not promise control while the Mac is powered off. Reboot, login, helper crash, update, uninstall, and physical unplug are distinct lifecycle transitions requiring verification.

Adapter cutoff can disrupt closed-lid external-display use. A request to prevent idle sleep cannot be marketed as guaranteed clamshell preservation. Default to rejecting adapter-cutoff actions when closed-lid safety is unknown and provide a clear reason. Experimental forced discharge must have a reserve, timeout, fresh telemetry, immediate restore action, and recovery independent of the GUI.

Preserve a single policy owner. Native mode should cooperate with Apple's settings. Direct SMC mode requires resolving conflicts with native Charge Limit, Optimized Battery Charging, Energiza, AlDente, BatFi, or another daemon before control activation. Never silently turn them off or continuously fight another owner. Capture only settings we can read and restore reliably; if a setting cannot be restored programmatically, state that before enabling the mode and provide the manual recovery path.

For privileged hardware control, use a signed, narrowly scoped daemon with authenticated XPC and `SMAppService` installation, status, and removal. Apple supports registration of bundled helpers through this API from macOS 13. This does not confer an Apple-private entitlement. [Apple SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)

## Proof-of-feasibility gate before building the full UI

1. **Read-only baseline:** record model family, OS/build, firmware, architecture, power connection kind, and public field availability without serials or full registry dumps. Confirm the current Energiza failure with a redacted excerpt. Read only a known-key capability allowlist; no probing via writes.
2. **Native action spike:** inspect the built-in Shortcuts action on the target, create the inspectable shortcut, test a valid native setting and restore its prior value in a supervised test. Validate its permissions, completion/readback, and whether the operation continues independently of our GUI. Hardware mutations happen only during that explicit implementation test, not this research.
3. **Backend spike if parity needs more:** on the target exact model/build/firmware, use a signed helper to attempt only a documented-in-our-adapter allowlist of operations, with rollback prepared. Validate key metadata first, report actual kernel results, and stop on unexpected layout or permission failure. Do not bypass SIP, Gatekeeper, or entitlement enforcement.
4. **Physical proof:** for charge pause, compare charging flag plus signed current and power-source state under modest load over an observation interval. For adapter cut, prove battery supply and restoration. Test a comfortably high cutoff and recovery, not a deep discharge. Key write readback alone is insufficient.
5. **Lifecycle matrix:** idle and forced sleep; lid-open versus closed-lid display; overnight sleep; reboot; logout; app quit; helper crash/restart; update/uninstall; USB-C and MagSafe; a weak adapter; competing native settings; stale telemetry; threshold and thermal events. Record expected versus observed behavior, including native full-charge exceptions.
6. **Go/no-go:** release direct-control parity only for passing model/build/firmware combinations. If SMC charge control fails, ship native upper limit and monitoring; adapter cycling is a separately described opt-in capability. If all control paths fail, monitor-only mode remains useful and truthful.

Passing on this Mac does not establish support for every macOS 27 Mac. Firmware can change independently of the running OS. Requalification follows firmware/OS updates, and the runtime capability response must keep unavailable actions disabled with specific reasons.

## Research limits

Source pages are live branch snapshots unless a frozen commit is linked. GitHub raw retrieval failed for the macOS 27 Battery Toolkit fork's control files, so its compatibility assertions were not code-validated. No hardware probe, signed helper, Shortcuts mutation, crash test, overnight test, or native-setting restore test ran in this research. Those are launch blockers for charge-control claims, not blockers to designing the monitoring app.
