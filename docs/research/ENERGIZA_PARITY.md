# Energiza feature research and parity inventory

Research date: 2026-10-01. Scope: public vendor documentation and published screenshots; no Energiza installation, binary analysis, or hardware writes. “Confirmed” below means documented by the publisher, not independently tested. “Pro” refers to vendor labels, not a proposed paywall for Stat Batt.

## Product identity and source availability

The author is Dr. Jan Linxweiler, trading as appgineers. The EULA is a proprietary use license, reserves IP rights, and restricts redistribution and reverse engineering subject to applicable-law exceptions. No reusable Energiza app source or open-source license was found. Build independently from observable behavior; use original branding, artwork, and code. This is a sourcing recommendation, not a legal opinion. [Vendor EULA](https://appgineers.de/energiza/eula.html)

A same-name GitHub profile, `jlinx`, lists 15 public repositories, all forks; none is Energiza. Its identity as the app author is plausible but not verified by a vendor link. [Public repositories](https://github.com/jlinx?tab=repositories) Homebrew’s Energiza entry describes distribution of a binary and links cask metadata, not application source. [Homebrew](https://formulae.brew.sh/cask/energiza)

## Documented monitoring features

The free Mac App Store product is “Energiza - Battery Monitor,” version 1.0.2 dated 2023-04-15, sold by Jan Linxweiler. It describes menu-bar access to time-to-empty/full, health, completed cycles, temperature, battery power consumption, and charging power; users can choose menu-bar information. Temperature alerts are included. [App Store listing](https://apps.apple.com/us/app/energiza-battery-monitor/id1643751440?mt=12)

| ID | Required parity surface | Research status | Proposed acceptance condition |
|---|---|---|---|
| MON-01 | Battery percentage and power state | Vendor-confirmed free monitoring [product](https://appgineers.de/energiza/#anker_feature_gauge) | Show current percentage and distinguish charging, holding, battery operation, full, unknown. |
| MON-02 | Time estimates | Free App Store description | Display estimate or explicit unavailable/calculating state; never convert missing data to zero. |
| MON-03 | Health and cycle count | Free App Store description | Report provenance and unavailable values; do not label estimated lifetime as guaranteed remaining cycles. |
| MON-04 | Temperature | Free App Store description | Show selected units and sample age; use a separately validated policy for thermal control. |
| MON-05 | Power telemetry | Free App Store description | Label battery flow, adapter rating, and charging power separately where available. |
| MON-06 | Configurable menu-bar display | Free App Store description | Keep selected display stable across power-state transitions. |

Acceptance conditions are proposed project behavior, not claims about Energiza internals.

## Documented control features

Pro includes lower/upper thresholds: hold until below the lower bound, then charge to the upper bound. Manual charging, full-charge override, active discharge, automatic discharge to the upper bound, and thermal charge inhibition are advertised. Active discharge requires Apple silicon. The FAQ claims post-2010 MacBooks and macOS 10.13+, with an 80% default upper bound. Notifications are labeled free. [Vendor features and FAQ](https://appgineers.de/energiza/)

| ID | Parity capability | Proposed implementation requirement |
|---|---|---|
| CTL-01 | Enable/disable charge control | Clear distinction between policy enabled and hardware action acknowledged. |
| CTL-02 | Lower/upper charge band | Validate lower < upper; define equality, reconnect, restart, and threshold-edit behavior in the policy spec. |
| CTL-03 | Stop charging now | Show result and cancellation path; reconcile with the active automatic policy. |
| CTL-04 | Charge to configured upper bound now | One-shot override, visibly cancellable, returning to the normal policy afterward. |
| CTL-05 | Charge to full now | Temporary override with expiry and a clear status explanation. |
| CTL-06 | Discharge to a target while plugged in | Capability-gated; stop at target, reserve floor, unplug, stale telemetry, or backend failure. |
| CTL-07 | Automatically discharge excess charge | Optional, with explicit target and rationale; do not repeatedly cycle around one percentage point. |
| CTL-08 | Thermal hold | Derive limits from battery-sensor evidence; do not equate ambient-temperature advice to an internal sensor threshold. |
| CTL-09 | Sleep charging policy | Implement conservative stop-on-sleep first; offer other modes only after targeted hardware validation. |
| CTL-10 | Quit and uninstall restoration | Restore native charging, verify the result, then remove helper; account for failed restoration. |

These requirements refine the publisher’s advertised capabilities into testable project behavior. They are not measurements of Energiza.

## Published UI references

The screenshots are historical references: General shows helper 0.2.0 and Update shows December 2022. They establish controls and information architecture, not present defaults or exhaustive choices.

| Surface | Observed controls | Direct reference |
|---|---|---|
| General | News, login launch, Dock visibility; installed helper version; reinstall/remove | [General screenshot](https://appgineers.de/images/energiza_preferences_general.png) |
| Charge Control | Separate automatic-sleep prevention and sleep-stop selectors for charging; sleep prevention during discharge; auto-discharge to upper bound | [Control screenshot](https://appgineers.de/images/energiza_preferences_charge_control.png) |
| Appearance | Icon selector; separate text selectors for battery/charging/hold; temperature units | [Appearance screenshot](https://appgineers.de/images/energiza_preferences_appearance.png) |
| Alerts | Global mute; individual notifications and sounds for charging start/stop and discharge stop | [Alerts screenshot](https://appgineers.de/images/energiza_preferences_alerts.png) |
| Update | Automatic check interval, beta option, last-check status, manual check and download | [Update screenshot](https://appgineers.de/images/energiza_preferences_update.png) |

The main demo shows a battery-shaped two-handle slider, charge toggle, immediate actions, explanatory status, and settings gear. [Vendor control demo](https://appgineers.de/energiza/#anker_feature_limits)

Recommended layout: a native menu-bar popover with monitoring first, then the charge band, immediate actions, and a plain-language explanation of the current decision. Keep the familiar interaction model, while drawing original assets and using current native controls. Support keyboard editing of both threshold handles with numeric fields and VoiceOver labels. Keep permission/helper status visible without occupying the default stats view.

## Release history that affects the plan

The vendor changelog’s newest listed release is 1.3.5 (2025-11-16), adding M5 MacBook Pro and future model identifiers. Version 1.3.4 (2025-09-10) specifically added macOS 26 Tahoe; no macOS 27 entry was found. Earlier entries add clamshell discharge (1.2.0), optional continued charging during sleep (1.0.0), MagSafe LED support, thermal protection, automatic discharge, helper repair/removal, charge-control disable on quit, Sparkle updates, adapter wattage, and battery design-cycle information. [Changelog](https://appgineers.de/energiza/files/Energiza.html)

The changelog also records helper installation regressions on M3 and M4 models, a drained-battery charging bug on Intel, and modal-dialog interference with charge control. These are useful test categories rather than proof the same bugs exist on macOS 27. [Changelog](https://appgineers.de/energiza/files/Energiza.html)

## Questions still requiring evidence

- The supplied local log establishes helper startup and charge-control capability rejection; exact firmware/interface root cause and actual adapter-write behavior remain unresolved. See [local failure analysis](ENERGIZA_FAILURE.md).
- Minimum lower bound, exact slider granularity, full list of menu-bar formats and sleep modes, and defaults beyond the documented upper bound.
- Thermal thresholds, recovery hysteresis, polling cadence, charge/discharge overshoot, and what survives a process crash.
- Whether a discharge target chosen by the user must be the lower limit, upper limit, or a freely chosen percentage.
- Exact settings in current 1.3.5; published images predate it.
- Direct compatibility evidence on the user’s precise macOS 27 build and MacBook model. The generic “10.13 or later” statement is not that evidence.
- Long-term charting, export, scheduling, presets, shortcuts, remote APIs, and per-process power attribution: not established as Energiza features by this research. Keep them separate from parity scope.

## Recommended sequencing

1. Reproduce the existing failure with read-only diagnostics and classify it before designing the privileged backend.
2. Ship monitoring and a simulator-backed policy/UI first; make stale and unsupported states explicit.
3. Prove charging start/stop and restoration on a named macOS build/model before enabling automated thresholds.
4. Add cancellable overrides, active discharge, thermal holds, and lifecycle handling behind per-capability evidence.
5. Add settings parity, helper repair, signed updates, original polish, and optional MagSafe behavior after core control acceptance.

Do not make Intel support, arbitrary future model-ID sideloading, or a macOS 27 compatibility claim a launch assumption. Record support by capability and tested build/model.
