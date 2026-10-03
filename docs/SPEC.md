# Product and engineering specification

Version 0.1, 2026-10-01; implementation authorized 2026-10-02. Authoritative product requirements; architecture and transport details live in their own documents. Numbers below are proposed product settings, not Apple recommendations or demonstrated firmware behavior.

## Product sheet

| Item | Proposed specification |
|---|---|
| Working name | StatBatt |
| User | Apple silicon MacBook owner who wants battery visibility and explicit charging control |
| Primary target | macOS 27, first exact model/firmware to be recorded in the compatibility matrix |
| UI | Native SwiftUI with AppKit status item/popover where required |
| Processes | User app; user-level native Shortcuts coordinator when configured; optional privileged daemon |
| Data | Local preferences, bounded history, redacted diagnostics; no account or telemetry |
| Control | Capability-based native limit, independent charge hold, deliberate discharge; no silent fallback |
| Default | Monitor only until a verified backend is selected and control explicitly enabled |
| Delivery | Local prototype first; Developer ID signed/notarized distribution candidate later |
| Build gate | Hardware proof precedes a promise of full macOS 27 charging parity |

## Modes and boundaries

**Monitor:** public power-source observations and optional read-only battery/SMC metrics. No admin approval for basic monitoring. Missing advanced fields do not disable the app.

**Apple native limit:** delegate to Apple's supported limiter through a configured, inspected Shortcuts action when verified. Apple's range and semantics govern; the app must not imply custom lower hysteresis or exact upper cutoff in this mode. Apple documents 80–100% limits and occasional full charges; it documents the charge-limit action in Shortcuts. These are available product surfaces, not evidence of a direct public Swift setter. [Apple charging behavior](https://support.apple.com/en-us/102338), [Shortcuts changes](https://support.apple.com/en-gb/125148).

**Custom charge band:** resume charging at/below L and hold at/above U using an independently verified charge gate that preserves external power. This is the closest Energiza control mode. If the interface is blocked, disable the mode and explain why.

**Discharge to target:** inhibit external adapter input while plugged in, allow ordinary workload to draw battery power, then restore adapter input at/below D. This is distinct from stopping charging. Never generate CPU/GPU load to accelerate discharge.

**Adapter cycling:** optional later custom-band fallback that alternates battery/adapter power. Explicit opt-in, wider hysteresis, awake only, no claim of battery-health improvement. Full parity does not depend on silently enabling it.

## V1 requirements and acceptance

| ID | Requirement | Observable acceptance |
|---|---|---|
| MON-01 | Percentage, adapter presence, actual supplying source, charging/full/hold state | Matches public source observations; physical connection and effective source may differ during adapter inhibition |
| MON-02 | Health, full/design capacities, cycle count, battery temperature, voltage/current | Units and origins shown; unavailable represented separately from zero; health ratio identified as estimate |
| MON-03 | Battery power, charging power, adapter rating and time estimates | Net battery power never labeled total charger delivery; signed flow and estimate confidence shown |
| MON-04 | Event-driven refresh with adaptive sampling | Fresh panel and event updates; idle target 30 seconds, active policy target 5 seconds; no needless per-second background polling |
| CAP-01 | Independent capability registry | Each mode and optional metric has provenance, denial reason, exact scope, and verification status |
| CTL-01 | Native charge limit | Only advertised supported targets; delegated policy/status distinguished from app enforcement; unavailable action fails clearly |
| CTL-02 | Custom lower/upper thresholds | Inclusive boundary hysteresis; no oscillation within band; unavailable charge gate disables this control |
| CTL-03 | Discharge cutoff | D >=20%; stop at cutoff/timeout/unplug/sleep/stale sample/critical reserve; observed adapter restoration required |
| CTL-04 | Immediate charge to target/full and stop | Bounded override with completion/expiry/cancel; thermal and platform restrictions still apply |
| CTL-05 | Temperature pause/resume | Only verified charge-gate backend; high T pauses, lower T resumes; temperature missing/stale yields fault; no adapter-cut thermal fallback |
| CTL-06 | Sleep/wake | Restore any adapter inhibition before sleep; re-probe on wake; expose native/platform-specific sleep behavior without awake-loop promises |
| CTL-07 | Quit/reboot | UI quit leaves explicitly enabled persistent band policy running; explicit Disable returns app-owned controls; crash/restart recovery precedes policy reapply |
| SAFE-01 | Cleanup and uninstall | Hardware restoration verified before daemon removal; failed restore leaves recovery path and visible degraded state |
| SEC-01 | Authenticated typed commands | Unknown client or malformed request cannot mutate; root helper exposes no shell/key-write API; signed peer checks in production |
| UX-01 | Menu panel, details, settings | Keyboard and VoiceOver usable; state explained in words, not color alone |
| UX-02 | Notifications | Opt-in charging/discharging/temperature/failure transitions, debounce, user-controlled thresholds, no periodic error spam |
| DATA-01 | Local bounded history/export | 7-day rolling 1-minute summaries proposed, optional off; gaps on sleep; CSV export and clear history |
| OPS-01 | Diagnostics/install/update | Export redacted versions/capabilities/errors; approve helper through OS; app/helper version mismatch disables mutation |

MON-02/03 advanced metrics are conditional individually. CTL-02/03/05 require actual backend verification; unsupported is an honest result but still a gap against the owner's full requested feature set. Record any accepted reduction explicitly rather than declaring unconditional completion.

## Policy definitions and proposed defaults

Custom band: L=70%, U=80%, 10 <= L < U <=100, minimum 2 percentage-point gap. Optional adapter cycling additionally requires L >=reserve20% and a gap >=5 points. Below/equal L request charging permitted; above/equal U request charge inhibited. Inside the band retain the last accepted direction; cold start inside the band permits baseline/system policy until U rather than inheriting a stale hardware latch. At the first activation, explain that setting an upper target below the present charge does not itself discharge.

Discharge: D=70% proposed one-shot target, 20 <= D < current percentage, reserve floor20%. Maximum duration2 hours default,24 hours hard maximum. At reserve boundary, restore adapter immediately. User must cancel before sleep or the daemon restores it automatically. Discharge completion does not mean the battery will never subsequently recharge; explain which persistent mode resumes.

Overrides: custom charge-to-full or charge-to-target expires after2 hours by default and within24 hours maximum. Reboot cancels one-shot discharge; expired overrides never restart. Explicit UI Quit cancels active discharge and verifies restoration; persistent custom band may continue after the UI closes. Native temporary overrides are unavailable until expiry/return-setting restoration is verified; a successful shortcut alone is insufficient. No promise to overcome Apple native periodic full-charge behavior or thermal/safety policy. Native and custom controller ownership are mutually exclusive.

Temperature: proposed pause40°C/resume37°C, units configurable, positive hysteresis required. Values are product defaults pending battery-sensor validation, not limits derived from Apple's ambient-temperature guidance. An active thermal policy with missing/stale temperature disables custom charging control and releases owned adapter inhibition. Hardware protections remain authoritative.

Staleness: active-policy battery sample older than15 seconds is unusable. After a wake or known suspend gap, samples collected before that event are unusable regardless of wall-clock timestamp. No time estimate at zero/unstable current. Acquisition and effective-state confirmation are separate: a successful write or shortcut exit code does not establish that charging changed.

Fault ordering: unsupported/unauthorized/conflict -> restoration attempt; battery reserve/unplug/sleep/stale input -> release adapter; thermal hold -> charge inhibition only if supported; manual override -> persistent policy. A fault never sets an optional measurement to zero or retries a denied private interface in a tight loop.

## Feature parity stages

The sourced inventory is [ENERGIZA_PARITY.md](research/ENERGIZA_PARITY.md). V1 includes the core visible monitor, custom thresholds where possible, one-shot actions, thermal gating where possible, notifications, menu presentation preferences, helper lifecycle, and diagnostics. Optional later parity: automatic discharge of excess charge to the upper limit, MagSafe LED control, selectable sleep prevention with visible reason, advanced menu animations/themes, broader model testing, and localization. Repeated adapter cycling remains explicitly experimental until tested and accepted. Scheduling and automatic calibration are new ideas, not assumed Energiza parity, and remain out of V1.

## Performance and privacy budgets

Provisional acceptance targets to measure in release builds: idle aggregate CPU <=0.5% over10 minutes, app RSS <=100MB/helper <=30MB, policy evaluation <10ms, no unexpected network requests. Values are engineering budgets, not measured results. Use coalesced notifications and bounded logs; no wake timers or sleep assertions by default. No serial number, battery serial, usernames, home paths, or adapter identifiers in exported diagnostics. Advanced troubleshooting sharing is user initiated.

## Dependencies and open questions

P0: exact model/firmware; permitted native targets and reliable state observation; independently writable charge gate versus adapter inhibit; sleep and crash restoration timing. P1: history usefulness/retention, menu display preference, ownership across Fast User Switching, signing entitlement availability. The initial UI proposal is [UX.md](UX.md); evidence and stopping conditions are [BUILD_PLAN.md](BUILD_PLAN.md) and [TEST_PLAN.md](TEST_PLAN.md).

## Native UX clarification — October2

Owner requested one-click Set to80% / Set to100% after separate one-time trusted setup. Ordinary acknowledged requests no longer require manual100% return before another deliberate request. Genuine unknown execution, qualification, trust, controller and storage gates remain. No current getter is claimed. See [decision0003](decisions/0003-two-target-native-limit.md); original full-v1 acceptance is unchanged.
