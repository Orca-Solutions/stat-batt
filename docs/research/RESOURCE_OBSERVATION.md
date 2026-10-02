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

No code change or speculative optimization followed from this evidence. Raw sample frames and resource rows remain local in temporary artifacts; they are not exported or committed. A controlled-idle rerun requires the owner to close Details/menu while leaving the identified app running, with no simultaneous stack sample. It is pending, not a completed budget check. [Acceptance](../V1_ACCEPTANCE.md) remains open.
