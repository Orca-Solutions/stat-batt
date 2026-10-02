# Owner-assisted native menu flow — October 2, 2026

**Passed on the named development target:** trusted setup → one menu-panel Apple80% request → owner-visible settings verification and app confirmation → normal quit/reopen with the original request preserved → owner-verified permanent100% return recorded in the app. This qualifies the bounded user workflow, not electrical cutoff or full-v1 charging parity.

## Candidate and method

- Target: Mac16,13 / arm64 / macOS27.0.1 / build26A434 / firmware mBoot-20457.1.29.
- Candidate:0.1.0(4), reviewed source `782c021fcbadc6af25d89ac1b77e5e5227130f71`; documentation checkpoint `67dce165c2322de7c8f1bafff4dd37679e5017a2`.
- Binary SHA256: `f6ccb0354d699c72d711532310467daa49f80254142a80e4406da8577424cae3`. Strict local ad-hoc signature verification passed before the flow.
- Owner separately authorized one app-path80% request, visible verification, normal restart without replay and manual100% baseline restoration. No private controller write or helper installation was authorized or performed.
- StatBatt native UI automation remained unreliable. The owner operated the real menu/Charging/Apple settings controls and reported observations. The agent checked candidate identity and read the allowlisted journal fields/process state; it did not fabricate setup or confirmation declarations.

## Observed sequence

| Step | Owner observation/action | Corroborating local evidence |
|---|---|---|
| Baseline | Confirmed StatBatt quit and Charge Limit slider100% | Old app absent; exact build4 bundle identified, then running |
| Setup | Recorded trusted/unchanged inspected shortcut, visible100% baseline and stopped-controller declarations; reported Apply enabled | Owner-only600 journal in700 directory, phase `ready` |
| Apply | One **Apply80% limit** from menu; reported slider80% and confirmed in StatBatt | Phase `manuallyConfirmed80`; request/confirmation timestamps below |
| Normal restart | Quit and reopened the exact candidate; reported saved80% confirmation still shown; did not Apply again | New app PID; same operation digest, request timestamp and confirmation timestamp; no outstanding shortcut CLI observed |
| Return | Followed finished/stopped shortcut check, permanent **Set Limit to100%**, Done/reopen100% verification and app restoration declaration; reported done | Phase `restoredUserConfirmed100`; prior-shortcut and restoration confirmation saved; original operation unchanged |

Journal timestamps (UTC): request `2026-10-02T22:28:02.270Z`; owner80% confirmation `2026-10-02T22:28:13.811Z`; finished/stopped and100% restoration confirmation `2026-10-02T22:32:23.080Z`. These are recorded app phases, not measured shortcut execution latency or a physical power trace.

The restart comparison supports no replay in this observed normal quit/reopen: the saved operation and timestamps were unchanged and the owner did not request another apply. It is not continuous subprocess tracing or a crash/sleep/reboot test. Return to100% was performed through Apple's settings by the owner, not an automatic StatBatt restoration.

Protocol chronology limit: the separate prior-shortcut-finished/stopped declaration was recorded during restoration, not before restart. After app confirmation, a read-only pre-quit process check found the original app process and no outstanding shortcut CLI. That absence is not an independent observation of library completion; no pre-restart library-finished declaration was reported. Do not infer that earlier declaration from the later restoration record. The preparation packet's earlier timestamp denotes preparation, not completed-flow capture.

## Boundaries

Only80% setting and manual100% return are qualified on this exact tuple. The mutable shortcut trust exception remains; identity binding cannot detect every future action/parameter edit. Confirmation records remain historical owner observations, not a native getter.

Actual electrical cutoff, charging-current behavior, deliberate discharge, custom lower hysteresis, temporary native override/expiry, unattended restoration, failure/crash/sleep/logout/reboot behavior, other targets and other model/firmware combinations remain untested. No SMC adapter-inhibit or charge-hold backend was enabled. Broader keyboard/VoiceOver, appearance/scaling, notification permission/delivery and distribution acceptance are separate.

The earlier shortcut-library preparation incident and its100% restoration are recorded in [LAB_PROTOCOL](../LAB_PROTOCOL.md). That incident did not establish this app-path result; the owner-confirmed100% baseline preceded the separately observed menu flow above. The original setter-only lab is [NATIVE_LIMIT_LAB](NATIVE_LIMIT_LAB.md). [V1 acceptance](../V1_ACCEPTANCE.md) retains the remaining requirements.

## Later state observation

Read-only inspection during a subsequent build5 resource comparison found a separate native intent dated2026-10-02T23:05:07.957Z, phase outcomeUnknown. It predates build5 preparation. Startup preserves pending intent/timestamps as an unknown result without replay; source inspection does not identify who invoked the newer request or prove execution/current setting. After the resource run, the freshly opened Apple Charging sheet visibly showed80%, with no agent setting change. Owner reconciliation is pending. The100% return above is an observation at22:32, not a guarantee of the current limit; this later record does not erase the earlier bounded flow evidence.
