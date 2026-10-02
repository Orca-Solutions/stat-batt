# V1 completion candidate — October 2, 2026

Owner requested a team to finish the original v1. The isolated app branch is `codex/app-v1-completion`; current local candidate is 0.1.0 (4), adding the direct menu Apply button the owner requested. Product design, platform investigation, software hardening and a fresh-context reviewer consulted. Same model family; no different-model review is claimed.

## Candidate evidence

- Monitoring presentation rejects invalid, future, pre-wake and expired readings. Its 60-second display budget accommodates the 30-second idle sampler; the existing 15-second active-control rule remains separate.
- Charging/source, threshold and native-failure notifications retain bounded pending events through cooldown. Sleep preserves undelivered recovery warnings while clearing sampled crossings; mute/settings/new boot reset alerts appropriately.
- History offers readable metric summaries and recorded source/charging observations. Minute summaries overlapping a gap are labeled and isolated; no transition or line is inferred across them. Missing measurement buckets also break interpolation.
- Native confirmations are labeled historical user observations. Missing custom one-shot and temperature-control surfaces explicitly state their unmet prerequisites and stay disabled.
- A standalone, closed read-only hardware diagnostic reports source/layout/denial facts. [Target results](research/SMC_READ_ONLY_QUALIFICATION.md) prove no mutating backend.
- Integrated software regression suite, release packaging, signature and final independent recheck are recorded in [implementation status](IMPLEMENTATION_STATUS.md) and [working record](../WORKING_RECORD.md).
- The direct ready-state menu action and inherited-lock-lifetime repair have [independent review evidence](handoffs/2026-10-02-menu-convenience-review.md):131 tests, build4 packaging/signature, and no remaining material finding within that increment.
- The [owner-assisted menu flow](research/NATIVE_APP_FLOW_RESULT.md) passed one80% request, visible user confirmation, preserved request/history across normal quit/reopen with no replay observed, and permanently restored100% recorded in the app. This is bounded app-path qualification on the exact tuple.

## Acceptance still open

| Area | Remaining evidence or decision |
|---|---|
| Native limit | Bounded owner-assisted menu flow passed; electrical cutoff/current, independent pre-restart library completion, abnormal crash/sleep/reboot and broader targets remain unverified |
| Custom charge hold | No working inspected backend retaining external power; full acceptance gap |
| Discharge and thermal control | CHIE read access is insufficient; write/owned restoration/reserve/sleep/crash safety unverified; no experiment ready |
| Monitoring and UX | Physical source transitions, synchronized sensors, keyboard/VoiceOver, both appearances/scaling, real notification permission/delivery and prolonged retention/sleep |
| Performance | Release-candidate ten-minute CPU/RSS measurement and no-network observation; no single sample claimed as a budget pass |
| Distribution | No valid local code-signing identity found. Developer ID/notarization and clean-machine install/update/remove are unrun; no spending or release authorized |

The current candidate is useful, tested local software. It is not full v1 acceptance, a verified Energiza replacement, or a public app release. The owner has not accepted dropping custom controls. Keep those criteria open unless explicitly changed.

Native desktop binding still fails for StatBatt, and earlier Activity Monitor identity disagreed with the process check. Therefore the completed flow uses owner-operated UI observations plus verified candidate/process and journal evidence, not an automated GUI pass. Setup, visible80%, saved historical confirmation after reopening and permanent100% return were reported by the owner and corroborated where the journal can do so. No confirmation was fabricated. The finished/stopped declaration was recorded during restoration; independent pre-restart library completion was not reported.

The owner asked for a scope recommendation. The team's recommendation is to keep full-v1 criteria open and treat monitoring plus native80% control as a preview milestone. This recommendation does not change the accepted scope.

The follow-up preparation encountered an apparent shortcut-library execution during inspection; subsequent native settings showed80%. Permanent100% restoration was performed and reopened, then the owner confirmed the100% baseline before the menu test. This incident is recorded in LAB_PROTOCOL and remains separate from the later successful owner-assisted app path.
