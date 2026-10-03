# Prepared app-path adapter candidate — October 3, 2026

This is a supervised local qualification candidate, not an automatic temperature controller. Public signing/notarization are deferred. Installation, service registration and this new hardware experiment have not yet run.

## Identity and package checks

Source checkpoint `37857bf`, with exactly six inhibition/recovery gates enabled in an isolated source copy. The packaging-only follow-up fixes a missing relocation metadata property and excludes shared ancestor directories from the package payload. Normal repository gates remain disabled. The candidate includes the final SIGPIPE fix and inherits the 200 passing default software tests; closed-default-gate tests are not claimed to pass against an enabled candidate.

Apple Development signature: fixed app `dev.statbatt.local`, daemon `dev.statbatt.control-daemon`, guardian `dev.statbatt.adapter-guardian`; Team `TWZA95CB7G`. Strict signatures verified individually on the extracted payload. Every signed source file's hash matches its extracted package counterpart. Both bundled shortcut files are preserved unchanged. The BOM contains only the StatBatt folder payload, root ownership and restricted write permissions; relocation is disabled. The postinstall creates a separate launcher without replacing the existing app. Package construction printed metadata write warnings, but extracted contents, signatures and byte comparisons passed.

Package: `apps/statbatt/dist/qualification/StatBatt-9-ONE-SHOT.pkg`

SHA-256:
- Package: `900caa2f46c3f77e5d7f6cea8eb3eccc7af99d32bf5f57eb4bbe936d043a5a05`
- App executable: `2d1c8a93e7be13f5394af2347945846201e33f4a15d6ac0db0dd147338cfa93b`
- Guardian: `44755016021bd3638607b96bbbca9cb020b1d580b9af6d2097547a260d13e721`
- Daemon: `931bf9b10ebce8863bee4c508cce5712dd81fa19e28d5ae7c8059111197e9cb6`

## Proposed authorized sequence

1. Install the verified package into `/Library/Application Support/StatBattLocal/StatBatt.app`; macOS Installer requires administrator authorization. It preserves the existing native app and shortcuts and does not register or start the service. Verify installed identities/ownership. Quit the old native app before opening the new one. Register the authenticated service as the signed-in user; any OS background approval is owner-operated.
2. Read fresh status and require exact target Mac16,13 / arm64 / macOS27.0.1 / build26A434 / mBoot-20457.1.29, normal thermal pressure, AC supply/attachment, charge >=50%, no conflicting controller and no unresolved ownership. Preliminary public check reported AC attached and80%; it is not the admission sample.
3. With separate owner authorization, press **Run one 2-second adapter test** once. Persist ownership before the guardian writes only CHIE one-byte `00 -> 08`; fixed independent guardian deadline is two seconds and cannot be renewed. Observe fresh key readback separately from physical battery supply. App/daemon loss closes the guardian owner connection; sleep/cancel/deadline stop and reap its writer before `08 -> 00`. No Apple charge-limit setting, synthetic load, sleep request or recurring policy is part of this test.
4. Require fresh zero readback plus AC supply and durable restoration acknowledgement. If unknown, preserve the service and journals, stop further experiments and use the owned restore action; do not uninstall. Do not automatically repeat an inconclusive trial. Guardian-process death itself remains an unqualified case; this experiment does not deliberately kill the guardian.

Installer is prepared at its final Install screen. The launchd daemon label `dev.statbatt.control-daemon` was absent before installation. The old native build8 app was still running. No new adapter write has been dispatched.
