# Apple native limit lab — October 2, 2026

The owner authorized one supervised80% native-limit test and restoration of the visibly recorded baseline, then confirmed Energiza's helper stopped and said to proceed. Launchd inspection found no registered Energiza helper service. No privileged helper was installed or private controller key written.

Target: Mac16,13, arm64, macOS27.0.1/build26A434, firmware mBoot-20457.1.29. Battery settings showed baseline100%, optimized charging on. Initial public telemetry showedSOC100%, not charging, reported adapter connection and adapter supplying source.

## Executed evidence

1. Created and visually inspected **StatBatt Lab — Native 80**, containing exactly one Apple **Set Battery Charge Limit** action, fixed at80%. The parameter menu advertised80/85/90/95/100%; only80 was executed.
2. Initial CLI execution inside the tool sandbox returned exit1 and a generic execution error. Battery settings remained100%. A separate read-only `shortcuts list` also failed with “Couldn’t communicate with a helper application.” Outside the sandbox, listing succeeded. This isolates a transport restriction; it does not establish failure of the native battery action.
3. Ran the inspected fixed shortcut through `/usr/bin/shortcuts` outside the sandbox. Exit0, command wall time0.340s. Battery settings then visibly showed80%. Acknowledgement and observed setting are separate evidence.
4. Immediately restored the recorded100% baseline through Battery settings. The OS displayed a lifespan notice; chose **Set Limit to100%**, rather than the temporary tomorrow option. Confirmed100%, clicked Done, reopened the charging sheet, and verified100% persisted. Optimized charging remained on.
5. Removed the sole action and renamed the empty artifact **StatBatt Lab — Completed (no actions)**. The zero-action editor and renamed library entry were inspected. Permanent deletion across iCloud devices was not performed because the dialog did not show a recovery path. The artifact is inert; existing user shortcuts were not edited.

A local redacted intent/result journal is saved in ignored `.build/native-lab-80.json`. End-to-end elapsed time was not instrumented; only command latency is recorded.

## Scope of the result

**Passed:** this exact target accepts the inspected Apple80% setter via the system CLI, visible settings readback matches, and supported manual restoration to the original100% was verified.

**Not established:** actual80% electrical cutoff, battery discharge, custom lower threshold, other advertised targets, automated restoration, temporary override expiry, sleep/logout/reboot/crash behavior, app-process transport permissions, or safe exclusion of other controllers. No telemetry was sampled while80 was active; the battery began at100% and was already not charging. No current/power polarity was inferred.

At the lab checkpoint, StatBatt had no native coordinator. The later owner-approved software increment is recorded in IMPLEMENTATION_STATUS.md; no additional setting mutation was performed by that implementation work. Production integration must distinguish acknowledged from observed outcomes, constrain the trusted action, detect missing/edited configuration, journal intent, and satisfy its recovery/conflict contracts before controls are enabled. This bounded lab passes the initial native setting proof; it does not complete CTL-01 or the full v1.


## Later setup artifact

After the owner approved the mutable-shortcut trust exception, the owned empty artifact was repurposed into **StatBatt — Apple Limit 80**, containing exactly one visually inspected Apple80% action. Read-only identifier listing found it exactly once. It was saved without running; earlier lab results remain tied to the executed lab operation, not an invented live app test.
