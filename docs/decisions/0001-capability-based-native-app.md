# ADR0001 — Capability-based native app with isolated control providers

Status: accepted with owner's v1 implementation go-ahead on October 2, 2026. Date:2026-10-01.

## Context

The owner wants Energiza-style monitoring and charge/discharge cutoffs on Apple silicon macOS27. Energiza's local helper starts but reports charge-control support unavailable and separately detects adapter disconnection. Native Apple charge limiting exists in a narrower range. Undocumented interfaces vary with firmware and cannot be presumed writable because a process is root.

## Decision

Use native SwiftUI/AppKit, public telemetry first, a pure policy engine, independent capability fields, a user-level native shortcut coordinator, and a minimal authenticated XPC daemon only for proven privileged operations. Prefer Apple's supported route within its range; separate independent charge hold from deliberate adapter inhibition. No automatic fallback between those modes. Keep every hardware provider replaceable and unsupported by default until verified on a scoped target. Retain original assets/code.

## Alternatives

Fork all of Energiza: no public licensed source found. Fork Battery Toolkit or wrap batt wholesale: useful reference/candidate, but archive/licensing/runtime/private-interface constraints and hardware uncertainty remain. Monitor plus native limiter alone: useful simpler fallback but does not satisfy the full requested discharge/custom-control scope without explicit acceptance. Private PowerUI client or entitlement bypass: outside the selected supported native route; bypass excluded.

## Consequences

Straightforward native UI and isolated policy tests; more explicit mode/ownership handling. Full parity may remain impossible on some firmware. First-device capability and restoration evidence precede release claims. Open-source reuse needs exact revision and notices; project license remains an owner decision before redistribution.

## Out of scope

Intel compatibility, cloud services, autonomous deep calibration, kernel extensions and broad hardware support claims. Supporting evidence lives in REPORT.md and research/; API implementation details live in API.md.
