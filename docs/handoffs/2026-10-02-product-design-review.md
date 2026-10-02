# Product design consultation — October 2, 2026

Status: source review complete; rendered and interactive UX verification unrun. This is a same-model-team product design consultation, not an external professional review or UX acceptance sign-off.

## Scope and evidence

Reviewed [PROJECT_BRIEF](../../PROJECT_BRIEF.md), [SPEC](../SPEC.md), [UX](../UX.md), [IMPLEMENTATION_STATUS](../IMPLEMENTATION_STATUS.md), the operating guide and working record, and the current `Sources/StatBattApp` views/store. The agreed native menu-bar monitor and Battery / Charging / History / Settings organization remain appropriate for v1. No mode, hardware capability, or product scope change was recommended.

The coordinator reported a successful integrated test run and release build. The design consultant did not run those checks independently. No rendered screenshot was received and no live interaction was exercised: the coordinator's native app lookup by bundle path timed out after 300 seconds, and the packaged app was not discoverable through the available desktop inventory. Build success does not establish layout, keyboard usability, or VoiceOver behavior.

## Recommendations incorporated and source rechecked

| Priority | Finding and user consequence | Current disposition |
|---|---|---|
| Material | “macOS controls charging” assigned a reason that public telemetry cannot establish, including when another controller may be present. | Main status and charging-stopped notification now state that the reason is unavailable. Details retain the explanation of possible causes. |
| Material | The combined “Details, history & settings” action always opened Battery, making the action promise inaccurate. | Separate Details, History, and Settings actions select the matching dashboard tab. |
| Material | Fixed 70% / 80% labels could appear to describe an enabled policy. | Custom-band values are explicitly marked “Proposed defaults · inactive”; the enable control remains disabled. |
| Routine | Compact monitoring omitted the time estimate already available in the detail view. | The panel includes the estimate with its charging/full or remaining-time label. Missing estimates remain explicit. |
| Routine | Celsius-only history and notification thresholds contradicted a selected Fahrenheit preference. | Chart values/axis and the threshold label/editor follow the selected unit; stored thresholds retain Celsius semantics. |
| Routine | Icon-only Refresh controls depended on hover help for their meaning. | Panel and dashboard Refresh buttons have explicit accessibility labels. |
| Routine | Settings lacked the conventional direct keyboard entry point. | A Settings command selects its tab and binds Command-comma. Actual key behavior remains unverified. |
| Routine | Noncharging batteries from 25% through 100% shared a visually full symbol. | The noncharging symbol follows quarter-charge levels. Charging retains the bolt symbol. |
| Routine | Native setup copy foregrounded internal qualification terminology. | Its short explanation now says StatBatt cannot change the Apple limit yet and points to Battery settings while setup and safe return to the previous setting await verification. |

These changes preserve the accepted experience direction. Source inspection confirms the described wiring and wording; it does not confirm their actual rendered appearance or operation.

## Remaining bounded work

1. **Acceptance evidence:** open the packaged app and inspect the menu panel plus all four tabs at default and minimum window sizes. Confirm readable wrapping, scroll access, clear disabled actions, native focus order, Command-comma, direct tab navigation, light/dark contrast, and VoiceOver names/values. This work remains unrun and prevents a UX-01 sign-off.
2. **Menu polish:** use compact missing values with units for alternate menu metrics and announce the chosen metric's availability through the status item's accessibility label. The coordinator owns this follow-up; it was not present in the source snapshot rechecked for this report.
3. **Availability language:** some secondary text still uses implementation terms such as “qualified provider,” “charge gate,” and “registry sensor encoding.” Prefer a plain explanation first (for example, “Battery temperature is unavailable on this Mac”), with detailed provenance accessible in the details/diagnostics context. This is routine copy refinement, not a reason to imply support or hide missing metrics.
4. **Threshold clarity:** retain “Resume at” and “Hold at” meanings alongside the inactive default percentages; a bare `70% → 80%` is less explicit than the approved flow's wording.

The first runnable monitor and unavailable-control flows still need actual UI verification. Verified native-limit, active-discharge, and restoration-failure screens are future acceptance work: their runtime states and hardware outcomes are not implemented or exercised by this consultation. Disabled actions and availability explanations must remain until exact-device verification supports each independent capability.

No helper installation, hardware write, shortcut execution, notification permission request, or external publication was performed by the design consultant. No implementation file was edited during this initial consultation; the later explicitly assigned native-flow view implementation is recorded below.

## Follow-up — read-only advanced metrics

Status: the new source integration was rechecked; StatBatt visual and interactive QA remain unrun. The consultant operated no shared UI surface in this follow-up and changed only this review document.

Reviewed the updated views/store plus `RegistryTelemetry.swift`. The exact model/build/firmware check limits registry enrichment to the recorded test device. Full charge capacity and design capacity are presented as reported mAh values. Health is calculated from their ratio, marked with `~`, labeled “Estimated health,” and explained as an estimate rather than an OS health diagnosis. “macOS condition” remains a separate row. Registry temperature has estimated quality, and live Celsius/Fahrenheit formatting retains `~`. These distinctions are appropriate in source; physical sensor accuracy was not independently qualified by this design review.

The coordinator reported an earlier read-only coconutBattery observation of full/design capacity 5581/5760 mAh and 96.6 °F, followed later by StatBatt's 36.59 °C sensor observation. The capacity pair provides reported cross-app comparison evidence. The temperature samples were not simultaneous and do not establish an accuracy tolerance or qualify thermal charge protection. No coconutBattery screenshot was inspected by this consultant.

Previously open menu and threshold refinements are now present in source: unavailable menu metrics use compact values with units, the menu accessibility label names the selected measurement, inactive defaults preserve “Resume charging” and “Hold charging” meanings, and history's missing-measurement copy uses plain language. These source dispositions supersede the earlier corresponding follow-up entries.

| Priority | Remaining recommendation | Verification bound |
|---|---|---|
| Material clarity | Explain that `~` means estimated in compact Temperature/Health help text, and explicitly say “estimated” in accessibility descriptions. A glyph alone may be unclear visually and its spoken interpretation is unverified. | Live formatting is source-confirmed; no compact-stat tooltip explaining the approximation was present in this recheck. |
| Material clarity | Preserve the estimated-temperature distinction in History with a plain note that sensor readings may be estimated. Avoid making a historical chart appear more certain than the live value. | The chart currently uses the generic “Temperature” heading and stored numeric summaries; no quality explanation was present. |
| Routine copy | Replace “public sensor readings” in notification settings with “battery temperature readings.” Retain the sentence explaining that alerts do not control charging. | New readings come from read-only registry enrichment; notification copy still referred specifically to public sensors. |
| Routine layout | Check full/design capacity wrapping at the minimum 640-point window width. Prefer integer mAh for these integer-valued reported capacities; if needed, use two trailing-aligned labeled values, “Full” and “Design,” instead of a long slash-separated value. | The source uses a shared horizontal row with multiline provenance and a value such as `5581.0 mAh / 5760.0 mAh`. This is a layout risk, not a rendered clipping defect. No screenshot was available. |

The Charging page and menu continue to show monitoring mode, disabled custom/one-shot controls, and device-verification prerequisites. An available temperature or capacity does not enable a charge gate, native limit, discharge operation, or temperature protection. No hidden control claim was found in the rechecked source. Actual tooltips, spoken accessibility output, capacity-row fit, and the full UX acceptance matrix remain unverified until the packaged app can be exercised.

## Follow-up — bounded native-setting lab result

Status: consultation on current source and coordinator-reported test evidence only. No UI action, shortcut execution, or hardware mutation was performed by this consultant. Visual and interactive StatBatt QA remain unrun.

The coordinator's corrected evidence distinguishes sandbox transport failure from the supported native operation. The initial CLI request returned exit status 1 with a generic error inside the sandbox, and Battery settings still showed the 100% baseline. A read-only shortcut listing also failed at helper IPC inside that sandbox and succeeded outside it. The initial error therefore provides evidence about the restricted execution path; it must not be presented as a failed Apple action or device incompatibility result.

The authorized **StatBatt Lab — Native 80** shortcut, inspected to contain the single Apple **Set Battery Charge Limit** action at 80%, subsequently ran outside the sandbox with exit status 0 in 0.340 seconds. The coordinator reported that Battery settings visibly showed 80%. The supported Battery settings slider was then returned to 100%, its “Set Limit to 100” confirmation accepted, and Done selected; reopening showed 100% with optimized charging enabled. This establishes a bounded 80% setting request and observed baseline restoration on the recorded device. It does not establish an observed charging cutoff, automatic application/restoration by StatBatt, intermediate target support, lifecycle behavior, or a completed native integration.

At the preceding source recheck, StatBatt already stated that it could not change the Apple limit yet. `AppStore.openShortcuts()` only opened the Shortcuts app; it did not apply a limit, confirm a setting, or restore a previous value. The native card's “Setup and device verification needed” status and equally prominent “Open Shortcuts” action nevertheless created two material clarity issues. The recommendations still stand after the corrected lab evidence:

| Issue | Recommendation |
|---|---|
| Generic setup wording fails to distinguish the successful lab setting change from absent StatBatt integration and can suggest that setup alone will enable control. | Use “Native integration not verified” as the status and “StatBatt can’t apply an Apple charge limit yet. Monitoring continues.” as the main explanation. Keep the bounded successful lab result and the sandbox transport limitation in compatibility details or diagnostics. |
| Opening Shortcuts from the primary charging card suggests an ordinary manual workaround, although StatBatt has no integrated native operation. | Keep “Open Battery settings” as the ordinary available action, with help explaining that it opens macOS settings and does not apply a limit. Remove the primary “Open Shortcuts” action; any laboratory shortcut reference belongs with test evidence rather than the normal charging flow. |

Suggested compatibility detail: “Supervised test: Apple’s 80% setting was observed, then the 100% baseline was restored and verified in Battery settings. Charging cutoff and StatBatt integration are not verified.” Identify this as a dated test on the recorded device, not the current limit. A secondary technical note may identify the sandbox helper-IPC limitation. Public battery telemetry does not read back the native setting, so the dashboard must not show a permanent live “100% limit” derived from this one observation. An “applied by StatBatt” status or broad “fully supported” claim would overstate this bounded lab evidence. No additional mutation or automatic retry is authorized by this consultation.

These recommendations refine accuracy within the agreed capability-based experience; they do not replace the native integration requirement with recurring manual shortcut use or declare monitor-only completion. A future verified native route must expose the actual supported operation and its confirmed result through StatBatt. The present candidate remains a monitor with unavailable charging integration.

The same source recheck also confirms that the earlier advanced-metric recommendations now have explicit compact-stat help and spoken “Estimated” values, a history measurement-quality note, battery-temperature notification wording, and separate integer-mAh Full charge capacity / Design capacity rows. These supersede the prior source-level follow-up items. Their rendered fit and spoken operation still have not been exercised.

## Follow-up — startup discoverability

Status: bounded UX judgment from the approved flow and current source, with no UI operation or implementation edit by the consultant. The coordinator reported that the accessory process runs but opens no initial window, and the available desktop automation cannot select the custom windowless app. This identifies an inspectability limitation and a first-use discoverability risk; it is not a failed visual review of a rendered window.

The approved launch flow says “Launch into monitor mode; display available metrics without administrator prompt.” It does not require zero initial windows. A one-time dashboard on the first interactive launch is consistent with the native menu-bar utility direction and makes monitoring and capability limitations discoverable without introducing a setup wizard or enabling controls.

Recommended least intrusive behavior:

- Show the Battery dashboard once on the first interactive launch, with normal monitor state and existing tabs. Persist a small UI-only “initial dashboard shown” flag after the dashboard is presented.
- Explain briefly that closing the dashboard leaves StatBatt available in the menu bar. Closing this window should keep monitoring active; Quit remains a separate action.
- Keep subsequent launches, including launch at login, quiet in the menu bar. Avoid unconditional every-launch presentation as the product default because it would repeatedly interrupt the user and can surface at login.
- Preserve Details, History, Settings, and Command-comma as explicit entry points. An explicit manual reopen of the app should make its dashboard discoverable if technically supported.
- For repeatable local inspection, an explicit `--show-dashboard` review launch path may request a window independently of the first-use flag. This must only reveal the existing UI and must not run a shortcut, alter charging, request permissions, or erase preferences.

Simply putting the Window scene before MenuBarExtra may help presentation, but scene order alone does not express the recommended first-use/subsequent-launch policy. The coordinator owns the implementation and verification choice. An every-launch window is a tolerable temporary local-review workaround if explicitly documented, not the recommended default experience.

The newly rechecked native charging card now says “Native integration not verified,” clearly states that StatBatt cannot apply a limit yet, and offers only “Open Battery settings” with help explaining that the action does not apply a limit. The earlier native-card copy/action recommendations are therefore source-dispositioned. First-use presentation, subsequent quiet launch, close/reopen behavior, and actual rendered/accessible interaction remain unverified.

## Follow-up — owner-approved trusted native shortcut flow

Status: the coordinator explicitly assigned implementation of `Sources/StatBattApp/NativeLimitView.swift` to this agent after reporting the owner's authorization, “yes statbatt may trust the shortcut.” The coordinator owns AppStore, application integration, the actor/protocol, qualification, discovery, and execution. The view was implemented and `xcrun swiftc -parse Sources/StatBattApp/NativeLimitView.swift` passed. Integrated build/test results and actual rendered/interactive verification are not claimed by this agent.

The new view receives a neutral `NativeLimitPresentation` and callbacks, and performs no shortcut execution, hardware access, helper registration, controller termination, or setting readback. It distinguishes setup, ready, applying, acknowledged-but-unconfirmed, user-confirmed, restoration-required, and unavailable states. Only the independently qualified fixed 80% target is offered; no broader target range, lower hysteresis, exact cutoff, or automatic expiry is implied.

The setup flow is intentionally one-time configuration. It explains how to create **StatBatt — Apple Limit 80** with exactly one Apple Set Battery Charge Limit action at 80%, shows discovery status without exposing UUID internals, and explicitly says that the shortcut need not be run manually. Three separate declarations are required before recording setup:

- The user inspected the single 80% action, trusts the shortcut, and will keep it unchanged.
- Battery settings visibly shows the 100% return baseline.
- Other charge-management apps are stopped.

The view also requires the coordinator's known-controller check to be clear and the shortcut to be discovered. Copy explains that StatBatt cannot detect later shortcut edits or identify every controller, and does not stop other apps automatically. The trusted-shortcut limitation is a meaningful user choice and remains visible after configuration. Recording setup sends the three declarations to the coordinator and does not apply a limit.

The separate **Apply 80% limit** action is enabled only in the ready state with a discovered shortcut, exact-device qualification, and a clear known-controller check. While applying, setup, a second apply, and Forget are not offered. A completed request shows “Request completed · setting unconfirmed,” directs the user to Battery settings, and offers **I see an 80% limit in Battery settings**. Its later state says “80% setting confirmed by you,” distinguishing user-observed setting evidence from physical charging-cutoff proof.

Unknown/recovery and confirmed states expose the manual 100% return route through Battery settings and the explicit **I restored 100% in Battery settings** declaration. Recovery text says to return to the baseline before another request. The confirmed state explains that macOS retains its setting after StatBatt quits and that StatBatt does not automatically return it. Forget is controlled by the coordinator's eligibility and cannot be shown during an apply; its help explains that forgetting configuration does not change Apple's setting.

The API is `NativeLimitView(presentation:onOpenShortcuts:onOpenBatterySettings:onConfigure:onApply:onConfirm80:onConfirmRestored100:onForgetSetup:)`, with `onConfigure` accepting `(inspectedTrusted80, baseline100Confirmed, otherControllersStopped)` as three Booleans. The coordinator must independently enforce these declarations, its journal/recovery states, live known-controller checks, and qualification at admission; disabled presentation is not a security boundary. This implementation advances the agreed native integration flow under the explicit trust authorization. It does not establish that the integrated app can execute, confirm, restore, or recover a native request until the coordinator integration and real flow are exercised.

## Follow-up — supplied Charging screenshot and Settings copy

Status: a static visual review of an older live app instance is now complete. This supersedes the earlier blanket statement that no StatBatt screenshot had been received. The current trusted-shortcut setup, Apply/confirmation/recovery flow, Settings rendering, and live accessibility remain visually and interactively unverified.

The owner supplied **Screenshot 2026-10-02 at 08.26.29.png**, which the consultant inspected with `view_image` without operating the desktop. The image shows the Charging tab of the earlier static native card: “Native integration not verified,” “StatBatt can’t apply an Apple charge limit yet,” a single Open Battery settings action, and the planned-integration note. These match the preceding static-card source disposition. Current `ChargingView` instead instantiates `NativeLimitView`, whose setup includes the discovered trusted shortcut, three declarations, and Record trusted setup; none of those current native-flow controls appears in this screenshot.

The coordinator separately reported that the packaged binary contains “One-time trusted shortcut setup” and “Record trusted setup,” was built at 08:05, and the live process had started at 07:27. The mismatch is therefore consistent with an older running instance. This consultant did not inspect that binary, restart the app, or validate the refreshed process. The screenshot must not be used as evidence that current native setup is missing from the packaged candidate, nor as acceptance evidence for the current flow.

At the supplied size, the visible native and custom-band cards have readable hierarchy and wrapping. The custom band clearly says “Unavailable,” “Proposed defaults · inactive,” Resume at 70%, and Hold at 80%, with a visibly disabled enable toggle. These shared labels remain in current source and do not imply active custom control. The Discharge card is partially visible at the bottom of the scroll viewport; this is not evidence of a clipping defect without a scroll interaction. No material visual issue applicable to the current build was established from this older screenshot.

The narrow follow-up source review of `PreferencesView` confirms that Control & recovery now distinguishes monitoring Quit from a persistent Apple setting, instructs the user to check shortcut completion or stop it before returning to 100% manually, and states that custom controls are unavailable, no privileged helper is installed, and other controllers continue independently. This resolves the stale “owns no charging settings” explanation after native integration. About StatBatt reads both version and build from `Bundle.main`; the coordinator reported build 2 in the packaged Info.plist. The actual About row and current bundle identity were not visually verified by this consultant. No material source-copy issue was found in that narrow addition.

The current native view also now distinguishes the last recorded owner confirmation from a live setting getter. Restoration requires the separate declaration that the earlier shortcut finished or was stopped in Shortcuts; `onConfirmRestored100` receives that Boolean. Timeout/interruption copy warns that a shortcut may still finish and does not promise that terminating the CLI cancels the underlying workflow. These are source dispositions, not exercised recovery evidence.

Only this handoff was edited for the screenshot/Settings follow-up. No source, shared desktop, shortcut, charging setting, or other hardware action was operated by the consultant.

## Follow-up — current restarted-build screenshots

Status: static visual QA of the current Charging setup at the supplied size and light appearance is complete. The owner supplied **Screenshot 2026-10-02 at 08.35.21.png** and **Screenshot 2026-10-02 at 08.35.27.png** from the restarted build. Both were inspected read-only using `view_image` at original resolution. This supersedes the prior limitation that only the older static native card had been seen; it does not establish interactive or full UX acceptance.

The current screenshot shows the expected one-time trusted-shortcut setup, the exact **StatBatt — Apple Limit 80** name and found status, the instruction to inspect rather than recreate the existing shortcut, and the edit-detection limitation. All three declarations are unchecked and **Record trusted setup** is visibly disabled. Its explanation explicitly says that recording setup does not apply the 80% limit. The distinction between discovery, user declarations, and an eventual charging request is clear in this rendered state.

The custom-band and discharge cards remain visibly unavailable. Custom defaults are marked inactive, Resume/Hold labels are readable, and their controls are disabled. The lower screenshot clearly shows the absent privileged helper and recorded platform: Mac16,13, arm64, macOS 27.0.1/build 26A434, firmware mBoot-20457.1.29. The visible instructions, labels, and available setup actions have no material clipping, overlap, or contradictory active-control claim at this supplied size/appearance. No material UI/UX defect was found, and no further redesign or additional testing was requested on the basis of these pixels.

This evidence covers the current unchecked setup presentation and unavailable custom/discharge presentation only. The consultant did not click declarations, record trust, execute Apply, confirm an 80% setting, perform restoration/recovery, test keyboard or VoiceOver, inspect another appearance or minimum window size, or verify Settings/About rendering. These screenshots do not establish any hardware outcome. Only this handoff was edited; no source or shared desktop action was performed.
