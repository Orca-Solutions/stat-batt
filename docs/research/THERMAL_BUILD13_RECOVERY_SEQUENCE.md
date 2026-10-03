# Prepared build13 recovery sequence

Not executed; explicit owner authorization pending. Uses installed build13 guardian SHA256747f18061e2c30f504b824b0d1c5730df2613930b16d080bdd5aef3ff5d32470. No app reinstall or automatic policy. Same exact Mac16,13/macOS27.0.1/26A434/firmwaremBoot-20457.1.29 target.

Two separately defined one-use experiments, in this order:

1. From fresh00+adapter, single CHIE00→08 in fixed120-second mode. After at least3seconds since first inhibited readback and fresh battery evidence, kill only this guardian. Independent worker must restore on EOF; its120-second lease remains nonrenewable. Confirm exclusive writer absence and fresh00+adapter before separate fixed00 journal cleanup. Unknown/fallback result stops sequence; no second test or retry.
2. Only after the first qualified result, recheck signatures, stopped controllers/service and fresh00+adapter. Start the same120-second mode once. A separately pinned sleep observer requests system sleep only after fresh08+battery evidence. WILL_SLEEP closes guardian ownership. Observer receives verified acknowledgment only after guardian exit0 and fresh restored00+adapter; it allows unknown after its8-second acknowledgment deadline, which cannot qualify. User wakes/unlocks the Mac; perform a separate fresh read-only service inspection after wake before accepting full sleep/wake result.

Both require≥50% battery and normal thermal state; no synthetic heat or load. Keep charger attached and lid open. No simultaneous worker kill. Each allows one guarded00 fallback only after exclusive writer exclusion; fallback never qualifies. Source scripts default disabled. Temporary observer is hash-checked in memory and copied to root-private staging before execution; it installs no background job. Observer SHA2560a0e39d1b27c3aac03e9709fe5deab2febb4108f3730be2f559064136be4881f, built from isolated StatBattSleepLab source with its sole gate enabled at /private/tmp/statbatt-sleep-observer13-0k4bhbdy. Source remains disabled in repository.

The sequence is claimed before administrator authentication, stops on any failed experiment, and saves stdout for review. Root recovery remains independent of stdout. Kernel/firmware stalls can exceed software deadlines; this is scoped qualification, not a physical restoration guarantee. Passing both does not by itself test the automatic UI/policy session.

Twelve guardian-loss mocked tests and four sleep flow/evidence tests pass. No new hardware operation has been executed during preparation.

Pinned directory: `/private/tmp/statbatt-recovery13-ready-22d8w_35`.

```json
{
  "sequence.py": "9c0c7b3f6b6fa49870e17e91aa985eee4d476b4e252fe8af149a519d036bf547",
  "common.py": "870d7cb6d877eb43d01b0c4f6b9355647b4de2984d896345658ee36026b11bc0",
  "sleep.py": "0d77be31bbf3cba26159a2a66ae0cd71e9c06f855318c1e5ed2d0624dedcb7c0",
  "guardian-loss.py": "bde3f0d20ac678e9cca11bb8b64c2a79d93a909cf4c3f9f27b8120e7515a558d",
  "run-once.command": "dec522e152479f50fe58331659a80f8e03c3c4aee2224f2b7e53ff38fe131b60"
}
```
