# NativeLimit engineering review — October 2, 2026

Independent implementation review by a separate reviewer who did not author the increment. This is not a claim of independence across model families. Reviewed the uncommitted working-directory snapshot; this repository has no commit to identify. No implementation source was edited by this reviewer.

Scope: `Sources/StatBattNativeLimit`, `Tests/StatBattNativeLimitTests`, `NativeLimitIntegration.swift`, `NativeLimitView.swift`, the native portions of `AppStore.swift` and `StatBattApp.swift`, `Diagnostics.swift`, and `Package.swift`. Contract references read: `PROJECT_BRIEF.md`, `docs/SECURITY_OPERATIONS.md`, `docs/decisions/0002-trusted-user-native-shortcut.md`, and the native sections of `docs/API.md`. Repository `CLAUDE.md` and the local SOFTWARE_OPERATING_GUIDE v2.2 were read.

The owner-approved mutable-shortcut trust exception is accepted here. The exact Mac16,13 / arm64 / macOS27.0.1 / 26A434 / mBoot-20457.1.29 qualification concerns the 80% setter and visible lab readback, with manual restoration to100%. It does not establish electrical cutoff, lifecycle recovery, other targets, automatic restoration, helper/private controls, or full V1 acceptance.

## Findings

### NLR-01 — P1: recovery can admit a new request before the previous child has exited

`ShortcutsProcessTransport.swift:167–170`, `:180–185`, and `:207–208` call `stopProcess()` and immediately `finish()` for timeout, cancellation, and output overflow. `stopProcess()` (`:230–237`) sends SIGTERM, schedules SIGKILL for0.5 seconds later, and does not wait for a termination observation. `finish()` resumes the caller (`:248`) independently of the termination callback (`:153–156`). A process that has not handled SIGTERM can therefore still be running when the transport returns.

The coordinator then persists `outcomeUnknown` and clears its busy fence (`NativeLimitCoordinator.swift:116–121`, `:152–155`). `confirmRestored100()` accepts a visible100% confirmation as soon as that fence clears (`:137–142`), enabling another request. The prior child can still deliver its request after the user observes100%, making the reconciliation stale and permitting overlapping deliveries. `AppStore.quit()` also terminates the parent immediately; any queued force-kill disappears with the parent, while the same-account lock is released on process death. The journal correctly prevents automatic replay after restart, but its unknown state can still be cleared without establishing that the prior execution has stopped.

Keep the operation busy until the owned CLI has actually exited/reaped after bounded termination escalation. For parent-death recovery and the separately acknowledged possibility that a library action outlives its CLI, the visible reconciliation flow must disclose pending execution and require stopping/confirming completion of the prior workflow before the final100% verification. Killing the CLI must not be represented as proof that the Apple action stopped. A fixed DEBUG-only nonhardware fixture that ignores SIGTERM, with a child-disappearance assertion, would cover the direct process-lifetime gap; existing process tests assert returned status/time/buffer bounds only.

This is a static control-flow finding. No real Shortcuts execution or live crash experiment was performed.

Disposition: **resolved within the bounded software contract by repair and independently executed regression checks**. The repaired runner stores a stop reason, suspends bounded pipe readers, sends SIGKILL to its owned CLI, and waits for the Foundation termination callback before returning timeout/cancellation/overflow. The callback retains the invocation until exit is observed; completion clears that retention. The repaired coordinator requires `confirmRestored100(priorShortcutCompletedOrStopped: true)` and durably records that declaration; a false declaration leaves unknown recovery fenced. The view explains that an interrupted request may still finish, requires a fresh completed/stopped checkbox, resets it on phase changes, and asks the user to verify100% after completion/stop. Fixed DEBUG-only SIGTERM-ignoring fixtures independently passed child-disappearance assertions at each returned stopped receipt.

This closes the direct-child early-return gap and supplies the explicit manual-reconciliation declaration. It does not prove that a remote library action ends with its CLI, or that a child is automatically cleaned up if the app itself is killed. Those limitations remain disclosed; real app-death/Shortcuts lifecycle behavior was not exercised.

### NLR-02 — P2: discovery failure asserts that no setting changed during unresolved recovery

`NativeLimitIntegration.swift:54–56` unconditionally displays “No setting was changed” when discovery throws. This refresh also runs after loading a persisted requested/acknowledged/unknown operation. A listing transport error, malformed listing, or replaced shortcut UUID then combines a recovery-required phase with an unsupported assurance that the setting did not change. The pending journal and failed discovery provide no such evidence.

Preserve outcome-unknown/reconciliation wording in these states. Discovery can accurately state that the refresh itself sent no setting request, without asserting the outcome of the earlier operation. Add a presentation regression covering an unresolved journal plus discovery failure.

Disposition: **resolved by source correction, independently re-read**. Refresh now uses `state.requiresManualRecovery` to retain “The prior request still needs review in Shortcuts and Battery settings”; the non-recovery branch says only that this refresh does not apply a limit. No live GUI or presentation regression was executed by this reviewer.

Final integration copy recheck: refresh and generic failure handling preserve the storage/recovery message when `journalHealthy` is false, rather than overwriting it with discovery/controller advice. Generic unresolved failures also explicitly instruct checking or stopping the shortcut before restoration. These source-only copy changes were independently re-read after the targeted test run; the lead owns the subsequent full-suite build.

## Contract observations

- Exact model/architecture/OS/build/firmware qualification is checked before setup and dispatch. Only80% is executable;100% restoration is a manual confirmation transition.
- Production jobs have fixed executables and argument arrays, including UUID execution. There is no arbitrary command/path transport or privileged helper execution in this increment. DEBUG fixtures are closed internal cases and omitted from release source compilation.
- Setup explicitly records mutable-workflow trust, visible100% baseline, and other-controller declaration. The view asks the user to inspect the expected single Apple80% action and discloses undetectable later edits. UUID checks are identity checks, with no complete content-integrity claim.
- Durable intent is saved before transport dispatch. Missing/ambiguous/replaced identities and preflight failures reject dispatch. In-flight actor reentrancy is fenced. Journal write failures block new operations; restart of requested/acknowledged/unknown work becomes unknown without replay. The same-account advisory lock excludes cooperating app instances, without claiming machine-wide exclusion.
- Completion remains acknowledged/unverified, and an80% user confirmation remains labeled as historical user confirmation. Custom hold/discharge/helper controls remain disabled.

## Verification bounds

Executed: read-only repository searches, source/document/test reads, Git status/log inspection, and SHA-256 checks of the reviewed files. After the lead's shared build was idle and the protocol author signaled stable repair sources, the reviewer independently ran:

```sh
scripts/swift-local.sh test --filter StatBattNativeLimitTests > /private/tmp/statbatt-native-review-tests.log 2>&1
```

Exit status **0**; **24 tests passed, zero failures**. This includes injected-IO intent/restart/reentrancy/reconciliation tests, filesystem journal/lock checks, and actual closed nonhardware subprocess fixtures. Timeout/cancellation/overflow tests assert the owned PID no longer exists at the returned receipt (`kill(pid, 0)` fails with `ESRCH`), including SIGTERM-ignoring cases. Expected inaccessible user-level SwiftPM cache and deprecated native build-system warnings appeared; no build/test errors occurred. No independent full-suite or release build was run because the lead owns those integration checks. NLR-02 was rechecked by source inspection; no automated GUI presentation regression was run.

Unrun: real Shortcuts execution, live library enumeration, SMC/private provider access, helper installation, hardware writes, native UI interaction, sleep/logout/reboot/crash experiments, actual80% cutoff, app-process transport permission validation, accessibility, signing/release verification, and clean-machine recovery. No actual restoration or hardware action occurred during this review.

Original finding snapshot hashes: `ShortcutsProcessTransport.swift` = `ff2bc6adc610d6be0c9a47783c227c2cc940b206128ea8653d17ec2747806648`; `NativeLimitCoordinator.swift` = `411404218aba6dc253f2d0279d52b41756a6ac3f4eedd37cb9338a02d0475c2f`; `NativeLimitIntegration.swift` = `d9a509d7d4b0bdfb27487915bbc437bd0b60d851829c3b61936e09eba0cc0115`.

Final rechecked snapshot hashes: `ShortcutsProcessTransport.swift` = `b0d9e56accb056b3c530bcef7fb391f69c54b8072a1447faf9f9400dc0670be7`; `NativeLimitCoordinator.swift` = `a961682a6ad26562d1eba72c72f7f8c2b088a5ef8807222d006ec63e3fef9029`; `NativeContracts.swift` = `19087eb4e36b2ef8fd695a17499bebdbbb1433e764858ec21c20f621c786b093`; `NativeLimitIntegration.swift` = `afe173f0c440d382279299fee8d87b741afe8021445b8cc887372acdd22164f2`; `NativeLimitView.swift` = `3096cae93db7cba74c185d98d275a97622c049c77aeeee017ed312f7cfaaa48c`; `ProcessRunnerTests.swift` = `be5432367f1e8be581174132a913b223e71cae141810eec0422800867665414b`. Independent test log SHA-256: `802ec64e05b570462bec3f174f1c8c8a9bcd581d6a7d8394612fdbda8e184c62`.

No open material source finding remains in the rechecked bounded increment. This review does not certify hardware behavior, real Shortcuts/app-death recovery, or completion of the requested V1 replacement.
