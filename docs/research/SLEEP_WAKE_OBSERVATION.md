# Read-only sleep/wake observation — October 3, 2026

The owner selected Sleep and woke the Mac during the second bounded observer run. The first observation window elapsed before the requested action and is not positive evidence.

The normal-user diagnostic uses IORegisterForSystemPower and immediately acknowledges sleep messages before buffering output. It creates no sleep assertion, requests no sleep, and performs no charging or adapter writes. The observer has a 120-second continuous-clock deadline, checked while runnable.

Observed events in `/private/tmp/statbatt-sleep-wake-retry.jsonl`:

| UTC | Event | Result |
|---|---|---|
| 2026-10-03 14:10:28 | systemWillSleep | IOAllowPowerChange returned 0 |
| 2026-10-03 14:10:52 | systemWillPowerOn | Delivered |
| 2026-10-03 14:10:52 | systemHasPoweredOn | Delivered |
| Immediately after wake | Fresh telemetry | Observed adapter supply; estimated temperature 30.19°C |

Continuous timestamps place will-sleep and has-powered-on callbacks about 24.29 seconds apart. This is a callback interval, not a precise measurement of time asleep. The post-wake source sample was acquired after the wake callback.

This verifies callback delivery and acknowledgment on the current Mac. It does not verify restoring an inhibited adapter before sleep, daemon crash recovery, forced-sleep timing, or physical reset. Automatic temperature control remains disabled. The next integration must request restoration before acknowledging sleep, handle failed or delayed restoration explicitly, and revoke the old control session across wake.
