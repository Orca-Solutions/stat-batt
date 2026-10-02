# Build4 resource observation — October 2, 2026

Candidate0.1.0(4), binary SHA256 `f6ccb0354d699c72d711532310467daa49f80254142a80e4406da8577424cae3`. Read-only observation followed the completed owner-assisted80%/manual100% flow; no setting was changed during measurement.

## Ordinary session result

| Measurement | Observed |
|---|---|
| Elapsed |600.048 seconds |
| Mean app CPU |0.7933% of one logical core, from cumulative process CPU delta / elapsed |
| Peak RSS |104.0469 MiB |
| Final RSS |102.1719 MiB |
| Maximum observed Internet sockets |0 in approximately5-second lsof snapshots |

UI idle/closed state was not instrumented or confirmed. A separate3-second stack sample ran during this interval and can perturb CPU accounting. These figures exceed the proposed0.5% idle CPU/100MB RSS targets in this observed session, but do not certify a controlled-idle pass or failure. Zero socket snapshots cannot exclude short-lived connections or attribute work/networking in other processes. No claim of continuous network tracing is made.

## Bounded triage

Source inspection found coalesced250ms event refresh plus a30-second fallback with3-second tolerance, suspended during sleep. Each accepted sample rereads/publishes bounded history, and chart rendering rebuilds timelines; these are repeated work but their material cost was not established. A3-second stack sample showed event/worker waits and no attributed history/telemetry/chart hot path. Its45.4M physical footprint/45.9M peak is a different metric and does not replace RSS.

No code change or speculative optimization followed from this evidence. Raw sample frames and resource rows remain local in temporary artifacts; they are not exported or committed.

## Owner-confirmed closed-window observation

The owner confirmed Details and the menu panel closed while the same build4 app remained running. A separate600.043-second observation then ran without agent UI interaction, stack sampling, rebuilding or charging changes. Ordinary Mac use was allowed; host sleep and unrelated system workload were not independently instrumented.

| Measurement | Observed |
|---|---|
| Mean app CPU |1.4716% of one logical core |
| Peak RSS |60.9375MiB =63.8976MB |
| Final RSS |37.9375MiB |
| Maximum observed Internet sockets |0 in approximately5-second snapshots; no observation errors |

Closed-window memory is below the100MB app target. CPU exceeds the0.5% target in this run; performance acceptance remains open. No helper was running, so no helper budget result is claimed. Socket snapshots still cannot exclude brief connections.

A source/cadence audit found two completed readings per minute, consistent with the30-second fallback, and no feedback loop, autonomous animation or recurring native subprocess launch. Periodic telemetry, history work and retained-view reevaluation remain attribution candidates, not established causes. [Acceptance](../V1_ACCEPTANCE.md) remains open.

## Longer attribution and bounded experiment

A subsequent70-second,1ms stack diagnostic observed telemetry/history paths, closed-dashboard body evaluation, menu/window-host updates and an AppKit status-item replication → appearance → SwiftUI status-button update chain. No HistoryTimeline or Charts path appeared. Inclusive sample counts overlap and include waits; they do not establish CPU shares or a dominant source defect. Instrumented CPU was1.89seconds/70.0033seconds (2.6999%), separate from the clean measurement.

Architecture consultation recommended one narrow comparison: extract the existing menu Label into an Equatable view with immutable text, symbol and accessibility-description strings. This can avoid unchanged app-driven label-body work while preserving updates to any changed string. It may not affect appearance-driven framework button updates. No telemetry interval, history or charging behavior changes.

Experimental build0.1.0(5) compiled successfully and passed strict local ad-hoc signature verification. Binary SHA256 `f92357afeaa2f3f0c52477903b1672502b560235f66a4dbde712a5117c54be02`; separate ignored bundle `apps/statbatt/dist/label-experiment/StatBatt.app` leaves build4 intact. This is not a demonstrated CPU repair or qualified replacement for build4. Visual/accessibility parity and a separate uninstrumented600-second closed-window run are pending. No new native setting request is needed or authorized by the comparison.
