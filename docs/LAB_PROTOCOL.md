# Supervised hardware qualification protocol

Prepared October 2, 2026. Owner explicitly authorized the bounded native80% test and baseline restoration in this conversation, then confirmed Energiza's helper stopped and said to proceed. The test is now executed: supported Apple action set80%, Battery settings visibly confirmed80%, and the recorded100% baseline was restored and verified after reopening settings. Optimized charging remained on. Initial sandboxed CLI dispatch failed; unsandboxed helper communication and execution succeeded. See [native lab result](research/NATIVE_LIMIT_LAB.md). No privileged helper or private hardware write was used. This setting/readback proof does not qualify cutoff, temporary overrides, or unattended recovery.

## First bounded experiment: Apple native limit

Target: `Mac16,13`, macOS27.0.1/build26A434, firmware `mBoot-20457.1.29`. Use the logged-in user's supported Battery settings and Shortcuts app, with no privileged helper.

1. Inspect the current native charge limit in Battery settings and record the visible baseline. Identify any existing charge controller and resolve the conflicting-controller condition before changing a setting. Do not silently turn a controller off.
2. Inspect **Set Battery Charge Limit** in Shortcuts. Construct one fixed, visible shortcut named **StatBatt Lab — Native 80** containing only that Apple action set to80%. Do not download or execute an opaque shortcut. If the action is absent or requested target rejected, stop and record unavailable.
3. With explicit owner permission to change the native setting, execute once at80%. Record command acknowledgement separately from the visible limit setting and battery source/charging/current observation. A charging flag at current SOC below80 cannot prove an upper cutoff. A periodic native full charge is not automatically failure.
4. Immediately restore the recorded visible baseline through the same supported surface; verify the setting in Battery settings. If baseline/readback cannot be obtained, do not run the first mutation. If restore fails, stop, keep the native outcome unknown, and use visible Battery settings recovery with the owner.
5. Record elapsed time, readback, observed state, and the limits of evidence. Remove only the app-owned lab shortcut after verified restoration, or remove its sole action and label it completed if deletion has no visible recovery path. No automatic native expiry is enabled from a successful shortcut alone.

This bounded operation changes the native limit to80% and restores its observed baseline. It does not intentionally discharge the battery or establish full-charge cutoff precision, permitted intermediate targets, logout/reboot restoration, or unattended expiry. Those need subsequent separate evidence. No control is enabled until its exact target and scope are verified.

## Later privileged-backend experiment

Before requesting authorization, implement and review a provider-specific read-only key metadata diagnostic and documented reverse operation. A candidate key name or Energiza log is insufficient. The authorization packet must name the single effect, fixed code revision, exact keys/layout from inspected source, baseline/readback, owned restoration, reserve >=20%, duration, and crash/sleep stop procedure. Do not install a speculative root helper.

Sequence: capture baseline -> verify a credible restore path -> journal before one small write -> observe electrical/source behavior -> restore -> confirm -> inject one bounded failure. Charge hold retaining AC and adapter inhibition must pass independently. Root access is not capability proof. Never bypass an entitlement denial, SIP, or a system safety policy. No synthetic load or deep discharge.

Adapter inhibition additionally requires physical restoration, sleep/cancel/timeout, fresh telemetry, and a bounded independent crash recovery path before unattended use. If inhibition can survive a daemon crash below reserve, leave it unsupported. A failed/unknown restoration preserves the journal/recovery mechanism and blocks further experiments and uninstall.

## Evidence to save

Record only nonidentifying model/architecture, OS/build, firmware, source revision/toolchain, operation, allowed target, acknowledged/observed phases, restore result, latency, safety events, and scope. Exclude hardware serials, user names, home paths, authorization data, and raw dictionaries. Update TEST_PLAN compatibility matrix only for tests actually executed.

## Authorized app-path follow-up — completed on build4

The prior one-time native80% lab authorization is complete. On October 2, 2026 the owner separately authorized this app-path test: apply80% once, verify, restart without replay, and manually restore/verify the original100% setting. It is now complete, with owner-operated UI and corroborating journal/process observations: [app-flow result](research/NATIVE_APP_FLOW_RESULT.md). The originally prepared build3 was superseded by build4 for the owner's clarified direct-menu-button flow, using the same guarded Apple80% action. Candidate revision/hash and the exact scope are in that result. This consumed the one app-path request authorization; no further setting experiment follows automatically.

1. Quit the older StatBatt from its menu. Confirm no instance or shortcut request remains, then launch the identified build4. If process identity cannot be established through the automation tools, the owner operates the app and provides visible/text confirmation; do not kill an ambiguous process.
2. Reinspect the existing trusted fixed80% shortcut and confirm Battery settings visibly shows the original100% return baseline. Confirm other controllers are stopped. If any condition is unclear, do not apply.
3. Record the three truthful setup declarations in StatBatt. This step must not change the Apple limit.
4. Click **Apply 80% limit** once. Record acknowledgement separately from the observed setting. Open Battery settings, verify80%, then record **I see an 80% limit in Battery settings** in StatBatt. No cutoff or discharge inference follows from this observation.
5. After the prior shortcut has completed or been stopped, quit/reopen StatBatt and inspect the persisted status without applying again. Confirm no replay and historical confirmation language. Do not deliberately crash while a shortcut is running in this first follow-up.
6. Restore100% permanently in Battery settings (not a temporary until-tomorrow override), reopen settings and verify100%. Record the prior-shortcut finished/stopped and restored100% declarations in StatBatt. Confirm recovery is recorded and repeat Apply is not automatically dispatched.
7. On any failed/unknown outcome, stop further requests, check or stop the shortcut in Shortcuts, manually restore the observed100% baseline and preserve the recovery journal. A killed CLI does not prove that the library action stopped.

No CHIE write, helper installation, forced discharge, temporary native expiry or broader target qualification is included. [V1 acceptance](V1_ACCEPTANCE.md) lists the remaining gates.

### Preparation incident and baseline restoration

The shortcut-library accessibility button was clicked during inspection. Its later selected state exposed a Play action; the earlier click may have executed the Apple80% action. A subsequent Battery settings observation showed80%, contradicting the preparation report that no action had run. This is not app-path qualification and must not be counted as a successful StatBatt Apply test.

After the owner reported battery decline, the shortcut editor showed Run rather than a running/Stop action. The original baseline was restored through Battery settings: slider100% → **Set Limit to 100%** (permanent, not until tomorrow) → Done → reopen Charging detail → visibly100%, optimized charging still on. Settings reported Charging89%, while the command-line power report still said AC attached/not charging89%. The owner later explicitly confirmed the100% slider and app quit before the menu test; that resolved its baseline prerequisite without treating the contradictory charging flag as power-flow proof. No private adapter-inhibit write was made. Read-only process verification confirmed the older StatBatt had quit. This incident remains separate from the completed owner-assisted app flow.

## Prepared two-target app qualification — new authorization pending

Owner requested the two-button UX in decision0003. This is software authorization, not a new actual setting experiment. The separate build6 qualification candidate has a compile-time one-use100% trial; normal100% remains unqualified. The prepared shortcut **StatBatt — Apple Limit 100** has exactly one Apple setter at100%, Set Until Tomorrow off, and has not run. Existing80% trust does not cover it.

Before execution, finish software tests and fresh-context review, identify the exact candidate/hash, and obtain separate owner authorization and100% shortcut trust. Quit the old app; schema2 migration preserves80% trust and the genuine unresolved request. The owner must check/stop the prior shortcut and visibly confirm the current80% setting before recording reconciliation. No agent confirmation or CLI absence substitutes for these facts.

Proposed bounded sequence, subject to explicit authorization: from owner-visible80%, run one100% trial through StatBatt; verify the permanent100% setting in Battery settings and record the owner observation; normal quit/reopen with no dispatch/replay; then use the deliberate qualified80% button once to return to80%, verify it visibly and record the observation. The owner checks each shortcut has finished or stops it before changing the opposite setting if its execution is uncertain. An uncertain result stops the flow and retains the fence; manual Battery settings recovery remains available. No adapter write, private controller or helper installation occurs.

A successful app-path result can qualify only100% on the exact tested fingerprint. It does not prove electrical cutoff or abnormal lifecycle. Only after evidence review may source qualification add100% to production allowed limits; the trial never does so automatically. Do not reopen older schema1 builds after migration: they fail closed on the newer journal. Forward migration does not erase unresolved intent.

Prepared candidate: reviewed source dc5c8993c39986fee0c14ce564de476e74575eee;0.1.0-qualification(6); binarySHA25675c7b0d9e2fe1086337db946666d3c608dd625908c4f8404486e7fae1ee1ffcb; strict local ad-hoc signature passes.137default/138qualification software tests pass. This candidate has not been launched or executed a setter. New test authorization and100% trust remain pending.
