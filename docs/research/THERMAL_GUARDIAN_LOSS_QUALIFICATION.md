# Prepared guardian-loss qualification — October 3, 2026

Status: executed with separate owner approval; guardian-loss recovery passed for the fixed two-second installed candidate. The preparation packet below is retained as historical evidence; see executed result at the end. Public signing is deferred; no new app signing is required for this lab.

Target remains Mac16,13 / arm64 / macOS27.0.1 /26A434 /mBoot-20457.1.29. Fixed installed guardian SHA256 `673176cd92b7374fa01b194dac8491ed1e1a05094424f2c5a3a96c466642cd62`; exact Apple/Team/identifier requirement checked. Source manifest `/private/tmp/statbatt-v11-candidate-b9znmgcm/CANDIDATE_MANIFEST.json` SHA256 `2152e7e4707b08bde19ebb105b5d9c99d33978f78e986fba0270b16d1f9c2931`; four relevant source files checked against it.

The only new inhibition is one fixed CHIE00→08 operation. The existing worker enforces its nonrenewable two-second lease, normal thermal state and≥50% reserve admission. Keep charger attached and lid open. App and daemon must be stopped/unregistered and other charging controllers absent. A fresh00+AC baseline and durable root-private intent precede the trial.

After successful08 readback and battery-supply evidence no older than250ms, the supervisor kills only its own guardian child once. It never kills the independent worker. That worker must restore00 on owner EOF or its own deadline. Fresh exclusive ownership/writer leases and00+AC inspection establish independent restoration. This proof is saved before a separate fixed00 cleanup through the installed guardian closes the saved intent. If independent restoration is not observed, one guarded00 fallback is allowed only after writer exclusion; that outcome cannot qualify independent recovery. Unknown writers/restoration stop the experiment and retain evidence. No repeated08, artificial load, native-limit change, sleep injection or automatic temperature policy.

Repository script `apps/statbatt/scripts/guardian-loss-trial.py` remains disabled; SHA256 `718cf53ff0dd9459b8c89dd5a33a265a5f46aa539febc73f19adaa85cd8c5193`. Ten mocked tests pass, including stale/future packets, once-only kill, exclusive lease refusal, fallback classification, durable cleanup and exception cleanup.

Isolated prepared directory `/private/tmp/statbatt-guardian-loss-ready-jnwfybz7`; only its ENABLED constant changes. Trial SHA256 `9f4c6ea35874b6a224069b765837bcc2ee0fbf38b1a26f7d0e021ed46bbcd6b6`; one-use wrapper SHA256 `244e2bba89fb780da0b1805b1d4d11ab925c445f42d72debb3cf18de9dc0d76b`. The wrapper claims the trial before authentication, then uses isolated system Python to read, hash-check and execute those exact bytes in memory as administrator. It has not run. No authorization is inferred from a password prompt alone.

Limit: this tests guardian-process loss on one exact build. It does not establish long pauses, simultaneous worker/guardian loss, forced power loss, or shared kernel/firmware recovery. A two-second restoration request is not a hardware-enforced guarantee of physical restoration time.

## Executed result — October 3, 2026

Owner explicitly approved one guardian-loss test. The first launcher exited before hardware access because the codesign inline requirement lacked its `=` prefix. Read-only verification with corrected syntax passed; ten mocked tests passed. The corrected launcher used the same installed guardian and hardware sequence.

Owner-provided terminal output confirms `qualified: true`: fresh08+battery preceded guardian termination (exit-9); independent00+adapter restoration was observed 271.2ms after the kill request, before any cleanup write. No fallback was used. Separate00 cleanup and final inspection passed, battery80%. This latency is an observed sample bound, not a firmware guarantee. Evidence is saved in THERMAL_GUARDIAN_LOSS_RESULT.json; root-private original stage is `/private/tmp/statbatt-guardian-loss-wbd_zbr3`. Automatic admission remains disabled; long-duration and remaining lifecycle qualification are outstanding.
