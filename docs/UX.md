# Experience proposal

Direction authorized with v1 implementation on 2026-10-02; original proposal dated 2026-10-01. Preserve Energiza's familiar menu-bar utility pattern and close feature organization with original visual assets and wording. Vendor screenshots and documented behavior are evidence; no live Energiza UI session was exercised. Exact parity inventory: [research/ENERGIZA_PARITY.md](research/ENERGIZA_PARITY.md).

## Primary panel

```text
StatBatt                         78% • On adapter
Battery power +7.8 W             Est. 24 min to target

State: Charging toward 80%
Control: Custom band — verified on this Mac

Resume charging at [70%]   Stop charging at [80%]
[ Control enabled ]

[Charge to full once] [Discharge to…] [Disable control]

Temperature 32°C    Health ~94%    Cycles 182
[Battery details]  [History]  [Settings…]
```

Values are synthetic examples. Show a compact battery symbol and selectable percentage, temperature, watts, or time in the menu bar. Prefer short text state, detailed reason on expansion. A configurable macOS-like icon is useful; no borrowed logos or proprietary assets.

## Capability-specific variants

Native mode replaces the two-threshold band with **Apple charge limit [supported target]** and notes that macOS may periodically charge fully. Present a setup step for the inspected shortcut and a link to System Settings. Distinguish “request sent,” “setting confirmed,” and “behavior observed.” Do not show custom resume thresholds or temperature charge cutoff as active in native-only mode.

When charge holding is blocked: “Custom charge hold is unavailable on this Mac. Battery monitoring continues.” Keep detail stats accessible. If adapter inhibition is separately verified, Discharge to… can remain available. Show its explanation: “Your Mac will use battery power while the adapter stays plugged in. External power resumes at the target or when this session ends.” Show a clear cancel button and remaining expiry.

An unverified feature has a disabled control and a specific prerequisite. Never replace charge hold with adapter cycling without opt-in. Optional adapter cycling uses the label “Cycle battery while plugged in,” names the awake-only limit, and states it increases battery use.

## Flows

1. Launch into monitor mode; display available metrics without administrator prompt.
2. Open Charging setup; show this Mac's capability report and recommended native route.
3. Native route: inspect/configure trusted shortcut, select target, apply, confirm observation. No privileged helper required for this route.
4. Custom/discharge route: explain daemon purpose, request OS registration/approval, test connection and versions, display capabilities, then enable selected policy.
5. Edit a band; apply as one atomic change. Invalid pair remains in the form with explanation, not partially sent to the daemon.
6. Start an override; display persistent base policy and temporary state separately. On completion/expiry restore the appropriate accepted policy.
7. Disable control: show restoration progress and completion. On failed restore, show recovery instructions instead of claiming disabled safely.
8. Quit offers “Close panel app, keep enabled control running” for verified persistent charge-band control and “Disable control and quit.” Any active adapter-discharge or adapter-cycling session is cancelled and restored before either quit completes; failed restoration shows recovery instead. Native limits remain Apple's visible setting unless explicitly changed. Do not silently delete an enabled service.
9. Uninstall: restore owned controls -> confirm -> unregister service -> remove app. History removal is separately selectable.

## Details and settings

Details groups battery state, health/capacity, electrical readings, adapter, and support diagnostics. History plots percentage, temperature, and net battery watts, with source/charging transitions and sleep gaps. State each value's unit and missing reason.

Settings groups General (launch on login, menu content), Charging (mode/band/default override duration/sleep limitations), Temperature, Notifications, Data, and Helper/Diagnostics. Notifications reflect transitions, not every poll. A recurring unsupported error becomes one persistent banner with an actionable diagnostic link.

## Accessibility and review

Native keyboard navigation and focus, VoiceOver labels for threshold controls and status, accessible contrast in light/dark appearance, localized percent/temperature formatting, and no color-only state. The first runnable mock must cover monitor, native limit, custom control unsupported, active discharge, and restore failure. Owner acceptance of those flows satisfies meaningful UX direction before broad UI implementation.


## Two-button native flow

The owner requested **Set to 80%** and **Set to 100%** directly in the menu, with the same actions in Charging. One-time setup inspects each fixed one-action shortcut separately, discloses undetectable later edits and records its own trust plus other-controller declaration. Setup never applies a limit. Existing80% setup migrates without100% trust.

Normal completed requests show **80% request completed** (or100%) and **StatBatt cannot read the current limit.** Both qualified buttons remain available for deliberate clicks, without a mandatory review or manual return. Optional owner observations stay historical. Startup preserves receipts without replay. Busy requests disable both buttons and never queue.

Genuine uncertainty shows **Check the prior request**. The owner checks or stops it in Shortcuts and records finished/stopped plus the visible80% or100% setting before resuming. A visible value alone cannot prove completion. No forced100% return is required. Missing/replaced/untrusted/unqualified targets stay disabled;100% requires its separate actual app proof. A compile-flag qualification action is clearly supervised and excluded from production capabilities.

[Decision0003](decisions/0003-two-target-native-limit.md) supersedes the prior manual baseline/return loop. Original custom-control acceptance stays open. No lower threshold, native expiry, current-limit getter or precise electrical cutoff is promised.
