# Restore-before-sleep implementation

The read-only callback experiment established delivery of will-sleep and wake messages. It did not establish hardware restoration during sleep preparation.

`ThermalSleepRecovery` now sequences an injected recovery backend with the durable ownership ledger. It immediately revokes thermal authorization, coalesces duplicate requests for the same operation, checks ownership, and requires the writer to be stopped and reaped before restoration. A storage failure cannot suppress emergency restoration of a known owned operation. A wrong operation cannot authorize a restore.

Verification requires current-boot key-zero and adapter-source observations after the restore attempt, followed by a durable recovery record. Caller cancellation does not cancel the recovery task. Wake and delayed completion cannot reauthorize charging control; a fresh explicit session is required. Backend I/O must itself be bounded; racing a timeout against an unreaped writer is expressly prohibited.

This component is not yet connected to the status daemon or hardware. It does not acknowledge OS sleep, veto forced sleep, or guarantee restoration through kernel, I/O, or firmware failure.

## Separate qualification candidate

The source-only sleep lab registers public power callbacks before the existing two-second adapter experiment is armed. Its fixed input protocol permits one explicit system-sleep request. On will-sleep, the supervisor closes the guardian's owner pipe to request restoration. A successful trial requires positive inhibition evidence, guardian restoration after writer reaping, and an explicit restored acknowledgment from the sleep observer. A watchdog-only restoration is inconclusive for this path.

The observer has a bounded acknowledgment wait. Failure, lost ownership, or timeout acknowledges with an unknown outcome; that can permit sleep with restoration unproved. The two-second guardian is software protection, not a firmware expiration. A real execution therefore needs a concrete reviewed candidate and the owner's deliberate sleep-test invocation. Default source gates remain disabled. No live sleep-with-inhibition test has been run for this candidate.

## Prepared candidate

The isolated candidate is `/private/tmp/statbatt-sleep-lab-fei1fu4q/run-sleep-test.sh`. Its one-use normal-user wrapper obtains administrator authentication, refreshes the baseline, starts a separate read-only sleep/wake observer, invokes the fixed root trial, and captures a read-only follow-up. The Mac is deliberately asked to sleep; the owner wakes it after approximately ten seconds. No automatic retry occurs. The normal app was closed after verifying its old completed native request; no charge-limit setting was changed.

Pinned SHA-256 values:

- Adapter lab: `8c1f824b7ebff1301fd5aae634caae2bece9a4e4144253654117cf390329e529`
- Sleep lab: `8fa638c40e753d44b03c67b2e740746c8bf5c6b6900b29d3dd55b930fff21d66`
- Guardian supervisor: `033348248189a57597cd2a67ad604352ab23b6fb1e77418ec325d69d94901b39`
- Sleep supervisor: `8c1dc21bccc8211df8687be8df8a24f8078c061b6f568cbfbc42f5fb7d4d15a6`

Only temporary copies enable the required gates. Both release products built successfully. Integrated Swift suite:186 passing tests(69 XCTest+117 Swift Testing); guardian/sleep Python tests:12 passing. Added regressions reject unowned operations, delayed stale observations, and false sleep success without a positive08 acknowledgment. Execution is pending the owner's deliberate invocation and authentication.

## Executed result

The owner ran the one-use command and reported awake. At2026-10-03T14:27:40Z the worker acknowledged00→08; will-sleep closed guardian ownership0.077774208seconds after its gate. The guardian killed/reaped the writer(exit-9), restored08→00, and verified fresh adapter-source telemetry, with exit0 and no journal errors. The sleep observer emitted `ACK_RESTORED` only after that result. The qualification summary was true.

The independent read-only observer recorded will-sleep14:27:40Z, will-power-on14:27:59Z and has-powered-on14:28:00Z. Post-wake telemetry reported observed adapter supply and estimated27.59°C. A separate14:28:36Z read-only inspection confirmedCHIE00, adapter supply,80% battery and nominal thermal pressure.

Scope: this verifies the explicit-sleep acknowledgment ordering after a real control-key transition. Restoration was so prompt that this run did not observe battery-source transition; actual electrical disconnection was observed in prior trials. It does not establish lid/forced-sleep behavior, crash of the guardian, or unattended production-daemon recovery. Automatic temperature control remains disabled and unintegrated.

Evidence is preserved at `/private/tmp/statbatt-sleep-trial-853ksm9e`. Captured result `/private/tmp/statbatt-sleep-recovery-result.txt` SHA256 `2bc9cb1a473dd5253ff42345bac9002cd2886688adc1aebfe39851833089c59c`. Wake events are in `/private/tmp/statbatt-controlled-sleep-events.jsonl`. Both temporary supervisors were disabled and the temporary write/sleep executables made non-executable after verification. Repository gates remain disabled.
