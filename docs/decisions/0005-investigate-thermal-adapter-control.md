# 0005 — Investigate opt-in temperature control using adapter disconnection

Owner direction accepted October 2, 2026; hardware qualification pending.

After initially accepting native-only v1 and discussing temperature limitations, the owner explicitly requested investigation and then stated a preference for temperature control through adapter disconnection. This reopens that optional feature. It does not establish that Energiza used this exact mechanism or that StatBatt can safely ship it yet.

Desired behavior: an explicitly enabled policy disconnects adapter input at the upper temperature threshold and restores it below a lower threshold. While disconnected, the Mac uses battery power even though the cable remains attached. Battery reserve, stale/missing temperature or source data, sleep, timeout, disable/quit and crash recovery must override the temperature policy and restore adapter input. Restoration must be verified. No claim that switching to battery necessarily cools the pack or improves battery life is justified by interface availability alone.

This is a deliberate exception to the original rule against adapter-based thermal control, subject to observed effect/restoration and lifecycle evidence. It must be labeled distinctly from pausing charging while retaining wall power. It remains off and absent from public capability claims until qualified. The working native 80%/100% controls and bundled installer continue independently.

Investigation starts with a separate normal-user restore-only lab: read CHIE, require the exact expected metadata and an already-zero baseline, optionally write only zero once, then read back. This cannot disconnect input. A successful same-value write does not establish restoration from an actual inhibited state. Actual disconnection needs a later reviewed tool with an independent restore path and a separately concrete execution decision.

The other lead—arbitrary native limits via root preferences—was investigated read-only, but the owner prefers adapter control. No such preference changes were made. Private normal-range readback worked and may improve status reporting later; it is not part of the current app.

The owner subsequently authorized continued v1 work without per-step confirmation except when necessary. This covers routine implementation, software validation and concrete lab preparation. Administrator authentication and unresolved physical-recovery decisions remain explicit user boundaries. The administrator-enabled-state test passed; its evidence does not by itself authorize claiming operational temperature control.
