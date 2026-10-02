# Local Energiza failure investigation

Observed 2026-10-01, read-only. The user supplied screenshots and expressly authorized examining `/var/log/de.appgineers.energiza.helper.log`. The lead read its last100 lines; no helper, adapter, or charging setting was changed. This file summarizes relevant facts without copying the full log.

## Evidence

Two helper startup blocks dated2026-09-30 19:27 and2026-10-01 08:41 identify helper version0.5.1 and arm64. In both:

- Charge-control variants1 and2 are reported unsupported.
- Virtual adapter-disconnection variant1 reports an SMCKit SMCError with numeric value4, then unsupported.
- Virtual adapter-disconnection variant2 is reported supported.
- MagSafe LED support is reported.

After startup, Helper.swift line164 repeatedly reports that charge control is unsupported, generally at15-second intervals. The timestamp pattern is consistent with repeated polling/action attempts; it does not prove the precise calling path. The screenshot truncates the SMC error; the file confirms its complete domain and numeric value.

Independent host observations: `sw_vers` reported macOS27.0.1/build26A434; `uname -m` reported arm64; `xcodebuild -version` reported Xcode27.0/build27A266a. `sysctl` hardware queries were denied by the execution sandbox, so exact model/chip/firmware remain unknown. This is a tool restriction, not evidence that macOS blocks battery control.

## Diagnosis and limits

The helper starts and performs capability detection. The observed failure is unavailable charge-control capability, not simply a helper that failed to install/start. Reinstalling it is therefore not an evidence-based primary fix.

The split between charge gate unavailable and adapter inhibit available resembles recent reports of changed macOS27 firmware access. That is a plausible explanation, not a confirmed root cause for this device. [Upstream batt issue152](https://github.com/charlie0129/batt/issues/152) reports privileged interface denial on a different build. We have not mapped Energiza's private “variant” numbering to specific keys, and SMCKit error4 must not be relabeled `kIOReturnNotPrivileged` without the enum definition.

The adapter “supported” line establishes Energiza's detection result only. It does not establish that adapter writes succeed, restore reliably, or safely support continuous cutoff management. A signed diagnostic and reversible hardware test must establish those separately.

## Consequences for the replacement

Keep capability fields independent; let monitoring work when charge control does not. Suppress repeated unsupported-operation log spam. Offer verified Apple native limiting separately. Treat active discharge as a distinct, individually gated feature. Never advertise equivalent charge holding simply because adapter disconnection is detected.

Next evidence: exact model and firmware, nonmutating capability/read results with raw IOReturn values, native shortcut action availability, observed state after individually authorized reversible writes, and sleep/crash restoration. Do not infer success from an app's generic support list or a repository name.
