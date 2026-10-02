# Direct menu action and lock lifecycle review

Product owner reaffirmed finishing StatBatt for menu-icon → Apply80% convenience. Product design consultant found MENU-01: the panel only linked to Charging. The repaired panel exposes the existing guarded action directly after trusted setup, with shared request eligibility and inline status/recovery. Detailed setup, visible verification and manual100% return remain available in Charging.

Fresh-context same-family reviewer inspected menu commit `ce68c962fd501eee5c7c7137ef74776fa4eb7855` against `055ed5223ffd788b44e269a5cbdebb96ccc07557`, then lock repair `782c021fcbadc6af25d89ac1b77e5e5227130f71` against the menu commit and the combined change against055ed52. No blocking/material findings remained in this increment. Pending, historical confirmation and recovery states expose review without reapplying. Sleep, preflight, concurrency, journal-before-execution and no-replay boundaries are preserved.

The initial integrated run exposed a lock-lifetime failure. A deterministic fixture duplicated the unique lock-file descriptor, retained it after owner release, and failed before repair with anotherInstance. Acquired ownership now explicitly unlocks before closing; failed contenders cannot unlock another owner. The fixture closes only its new duplicate, proves immediate reacquisition with that duplicate alive, and retains third-instance exclusion. The exact transient child responsible for the initial full-suite failure remains unproven.

Evidence reviewed:

- Before-fix regression: `/private/tmp/statbatt-lock-regression-before.log`, expected failure.
- After-fix boundary suite: `/private/tmp/statbatt-lock-regression-after.log`,8 passed.
- Final integrated suite: `/private/tmp/statbatt-menu4-final-tests.log`,131 passed (69 XCTest+62 Swift Testing), zero failures.
- Final package: `/private/tmp/statbatt-menu4-final-build.log`, release build passed.
- Reviewer independently ran read-only strict signature verification (passed), read build4 metadata, and confirmed binary SHA256 `f6ccb0354d699c72d711532310467daa49f80254142a80e4406da8577424cae3`.

Reviewer did not independently execute tests/build, UI or hardware. This is source/log review plus read-only artifact verification. It does not qualify the live app-path, actual power cutoff, full-v1 custom controls, accessibility/performance or distribution. [Acceptance](../V1_ACCEPTANCE.md) and [lab protocol](../LAB_PROTOCOL.md) retain those gates and the corrected preparation incident.
