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


## Implemented native80% flow

One-time setup presents the existing expected shortcut or its creation instructions, discloses that later content edits cannot all be detected, and records inspection/trust, visible100% baseline, and other controllers stopped. Recording setup does not apply a limit. Qualified ready state offers **Apply80% limit** within StatBatt. Completed requests stay unconfirmed until visible Battery settings confirmation. Persisted confirmations identify their user source and are not a current getter.

Interrupted/unknown requests block Apply and keep recovery visible. The owner first checks/stops the prior shortcut, then restores100% in Battery settings and confirms both. Returning to100% is manual, and the app never describes a killed CLI as a stopped remote action. No lower threshold or expiring native override is offered. This flow follows the owner-approved trust exception and product design consultation.
