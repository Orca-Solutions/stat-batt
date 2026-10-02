# Build plan and work breakdown

Plan authorized October 2, 2026. Stage0 read-only diagnostic and Stage1 software are implemented. The authorized native80% setter/readback and manual100% restoration lab passed; privileged hardware experiments have not run. Stage2 software is implemented under the approved shortcut trust exception, with live app/cutoff/lifecycle acceptance outstanding. Deliver one reviewable increment at a time; the first checkpoint decides whether full parity is technically possible on the target.

## Stage0 — compatibility proof

| Task | Owner role | Depends on | Deliverable and stopping condition |
|---|---|---|---|
| P0.1 Read-only diagnostic | Platform engineer | Exact device identification | Public telemetry and allowlisted read-only capability probe; no write-on-detection; machine/build/firmware tuple without serials |
| P0.2 Apple native action | Platform engineer | P0.1, lab permission for setting change | Inspect Set Battery Charge Limit action and accepted target set; use fixed trusted shortcut; distinguish command acknowledgement from observed policy and battery behavior |
| P0.3 Native restore proof | Platform engineer | P0.2 | Determine baseline/target readback, setting ownership, restore semantics, native periodic top-offs, app absent/reboot behavior; unsupported automatic restore disables expiring native overrides |
| P0.4 Custom gate proof | Platform/security engineer | P0.1, approved reversible write protocol | Test permitted charge gate and adapter inhibition individually, with baseline journal and restoration evidence; entitlement denial is a stop, not a bypass project |
| P0.5 Compatibility checkpoint | Coordinator/owner | P0.2–4 | State which requested features work, which are conditional/unavailable, and whether reduced scope is acceptable; do not call monitor-only replacement complete |

Safe lab sequence: record baseline -> ensure ordinary charging can be restored -> single small operation -> observe electrical/source state -> restore -> confirm restoration -> test one failure case. Keep reserve >=20%, use normal workload, avoid automated discharge to zero. Test USB-C and MagSafe independently when present. No privileged code should be installed before the experiment and recovery path are concrete.

## Stage1 — read-only product skeleton

Build a pure Swift policy/data package, typed DTO package, public telemetry adapter, fake clock/provider fixtures, native menu panel and details. Show the unsupported-control variant with real state. Add local bounded history and CSV export after the basic monitor is correct. Exit: MON requirements and UX accessibility evidence pass; mock states never imply hardware support. Proposed directory structure lives in ARCHITECTURE.md.

## Stage2 — supported native limiting

Implement trusted shortcut setup/coordinator outside the privileged service. Fixed action/target inputs, timeout and cancellation, no arbitrary downloaded shortcut execution. Integrate native mode with explicit setup, native semantics and manual confirmation when needed. Exit: native capability/ownership/restore evidence on first target; custom controls remain unavailable unless proven. This is a useful partial product, not full Energiza Pro parity.

## Stage3 — custom controls and helper

Only proven backends proceed. Implement authenticated XPC, helper registration/status UI, single serialized policy owner, durable configuration and actuation journal, two-phase apply/effective-state reporting, bounded discharge, thermal policy, sleep restoration, recovery and uninstaller. Exit: custom band, discharge cutoff, unsupported denial, fault and lifecycle tests pass on named target. Repeated adapter cycling is a separate optional increment.

## Stage4 — parity and hardening

Complete menu customization, transition alerts/sounds, optional LED capability, helper troubleshooting, preference migration, light/dark and accessibility checks, performance measurements, power-source changes and sleep tests. Compare every sourced parity row with included/deferred/unsupported implementation status. No automatic deep calibration.

## Stage5 — release candidate

Independent fresh-context review, target compatibility evidence, signing/notarization verification and clean-machine install/update/uninstall. Prepare artifact hashes, licenses/notices, release notes and recovery instructions. Owner accepts candidate and separately authorizes publication. No new spending or account provisioning assumed.

## Collaboration and file boundaries

Use platform investigator for provider/hardware evidence, native app implementer for UI/telemetry/history, service implementer for policy/XPC/lifecycle, and independent reviewer. Work in isolated files/modules and coordinate contract changes through API.md. The initial discovery team used three subagents; its output is documentation, not implemented code.

The owner authorized the monorepo migration, local commits, private Orca-Solutions/stat-batt repository, proprietary license, and a setup/landing PR. Verified owner attribution is configured locally; the working branch is codex/monorepo-landing. See [build instructions](BUILD_GUIDE.md) and [working record](../WORKING_RECORD.md) for current delivery state. Native app release and hardware acceptance remain separate gates. No duration estimate for full v1 is defensible before provider qualification; its result determines whether this is a straightforward native monitor or an ongoing unsupported-interface maintenance project.
