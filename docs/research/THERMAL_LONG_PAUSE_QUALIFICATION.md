# Build13 bounded long-pause qualification

Prepared October3,2026. Not installed or executed; specific hardware authorization is pending. Public signing/notarization remains deferred. Automatic admission remainsnil in both normal source and candidate.

## Candidate and intended scope

The existing two-second path remains fixed. A separate closed120-second mode (`--cycle-120`) has nonrenewable worker and guardian deadlines. It restores on owner loss, sleep, unexpected key, missing/stale host telemetry, battery reserve below50%, or nonnominal thermal pressure. Temperature is still an estimate; host acquisition freshness does not establish sensor conversion age or calibration. No synthetic heat/load is used.

Source staging: `/private/tmp/statbatt-v13-candidate-kwvpji9h/statbatt`. Source manifest SHA256 `8c32cef393885936d1adf3222f179bc7542db68274fc24164b985e24c9be9b0d`. Eight explicit qualification/recovery gates are enabled only in the isolated candidate; the normal repository gates remain closed. Candidate gate diff and manifest are beside the package under `apps/statbatt/dist/qualification`.

- Package: `StatBatt-13-LONG-PAUSE-UPDATE.pkg`, SHA256 `708c8ff017434ca14f3020850308508acf1eaaa4706c5ea5975efa377dc8bb78`.
- App executable: `c1aff286d7ecaa6ee95aa4a164770162e360f92d483ffb47985e341f77689b07`.
- Guardian: `747f18061e2c30f504b824b0d1c5730df2613930b16d080bdd5aef3ff5d32470`.
- Daemon: `1ee3b8c67c750277ece5d26ad35481b083d6311d153511758764018e8a4c8fce`.
- Removal helper unchanged from installed candidate: `e912ed8070c4e411ea678911f49c7ae2e7d57def86d39ba996aea7de6d6cfa37`.

Apple Development-signed code, fixed identifiers/Team verified during packaging. Installer package itself is unsigned and local only. Build13 does not register or start a temperature session. The UI receives admitted duration/reserve from the service rather than hardcoding2seconds/30%; absent admission prevents automatic start. Runtime's normal one-shot call explicitly selects2seconds even if a future reviewed automatic record selects120.

## Proposed one-use experiment

After explicit owner approval, verify restored state, stop the app and unregister the service, then install the fixed package. Keep all charging controllers stopped and the lid open with the same charger connected. Root launcher verifies immutable installation, signature, exact guardian hash and source provenance, and fresh00+adapter baseline. The worker requires≥50% battery and nominal thermal pressure before the single CHIE00→08 write.

Collect a bounded timestamped trace throughout the fixed120-second interval. EOF/failed observation requests restoration; there is no retry and no deadline renewal. Require battery source after the initial settling interval, a sustained trace, worker restoration and final exclusive00+adapter inspection with closed journal. A guarded00 fallback is allowed only after exclusive writer exclusion and never qualifies the trial. Save root-private evidence and a user-readable summary so a disappearing terminal window does not obscure the result.

This qualifies only the observed bounded interval on Mac16,13/arm64/macOS27.0.1/build26A434/firmwaremBoot-20457.1.29. Parent and worker deadlines are near-equal: normal completion may report ownerEOF rather than worker deadline. It is not proof of independent deadline recovery, sleep recovery for the new mode, sensor accuracy, physical power-loss recovery, or an automatic policy session. Kernel/I/O stalls can exceed the software restoration deadline.

## Offline validation

Full Swift suite:227 tests passed (69XCTest +158SwiftTesting), `/private/tmp/statbatt-long-pause-suite.log`. Installer restored-record/native-fence admission fixtures and both bundled signed shortcut integrity checks passed. Guardian-loss script regression includes corrected inline codesign requirements and11 mocked tests. Long-pause launcher/trace acceptance is reviewed and tested separately before enabling any isolated launcher. No offline test actuates the installed guardian.

## Prepared launcher (not executed)

Directory: `/private/tmp/statbatt-long-pause-ready-6nt9y49h`. Exact pinned dependencies are hash-checked before evaluation; only the isolated trial setsENABLED true. Launcher claims once before administrator authentication and saves stdout to `result.txt`. Nine offline launcher/trace tests pass.

```json
{
  "trial.py": "e7aa972869f97e1246755fdac26841400285c4bbdc2e2c472f69f35c7af50abe",
  "guardian-loss-trial.py": "01425149d12ecdbc140085611a8227c0556893221e332b98df4db1c1de26b9b2",
  "run-once.command": "1d06956223600afe8dd5c46e97a33d9c516e783e6ffb9dbaec5981896a857559",
  "long-pause-evidence.py": "e745ed31ffa56ce0f75424319ea0cdb9ae4ebc811ddb457b7838c4c88b93f41c"
}
```
