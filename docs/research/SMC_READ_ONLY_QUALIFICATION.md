# Read-only control metadata — October 2, 2026

The v1 completion team implemented and independently reviewed an original, narrow normal-user SMC diagnostic. The release diagnostic ran once on `Mac16,13 / arm64 / macOS 27.0.1 / 26A434 / mBoot-20457.1.29`. It installed no helper, executed no shortcut, and dispatched no hardware write.

## Observed results

| Fixed key | Observation | Meaning and limit |
|---|---|---|
| CHTE | Metadata transport returned 0; SMC result 132 | Rejected by the inspected interface; no valid layout or baseline obtained |
| CH0C | Metadata transport returned 0; SMC result 132 | Rejected; this is not a verified zero-size placeholder |
| CHIE | Size 1, type `hex_`, attributes `D4`; read returned 0, baseline `00` | Readable adapter-inhibit candidate only; write permission, discharge and restoration remain unverified |
| CH0J | Metadata returned `0xe00002c1` | Access denied; probe stopped without further key reads |
| CH0B / bfF0 / bfD0 / bfE0 | Not attempted after denial | Unknown on this target; no absence or support claim |

User-client open/close and service open/close all returned 0. Raw report and compiled artifacts remain local evidence, outside tracked publication. Successful transport is distinct from the SMC result and from electrical behavior. No app capability was promoted.

## Source and execution boundary

The closed diagnostic catalog uses an 80-byte, zero-initialized ABI, selector 2 with command 9 for metadata and command 5 for conditional reads. Lifecycle selectors 0/1 open and close the user client. There is no command 6, key enumeration, arbitrary key/value argument or write endpoint. Conditional reads require the exact fixed size/type/attributes and copy at most four bytes. The Swift CLI rejects all arguments and checks the exact tuple before opening the service. Permission denial stops the catalog and closes the connection.

Pinned primary references:

- [Battery Toolkit BSD power layouts](https://github.com/mhaeuser/Battery-Toolkit/blob/ed3adf103abfdad53223ce6f0a764ae7163c385b/Libraries/SMCComm%2BPower.swift): independent charge-hold keys and adapter-inhibit keys. Its APSL header is not copied.
- [MIT ABI field reference](https://github.com/caseymrm/go-smc/blob/4a31024c8b631d9a241ee3d21a83f94db966605e/smc.h) and [license](https://github.com/caseymrm/go-smc/blob/4a31024c8b631d9a241ee3d21a83f94db966605e/LICENSE): exact pinned files fetched and reviewed. Independent layout derivation confirmed size 80 and offsets 0/28/32/36/40/41/42/48.
- [Firmware-access report](https://github.com/charlie0129/batt/issues/152), [adapter fallback](https://github.com/charlie0129/batt/pull/154), and [sleep/runtime race repair](https://github.com/charlie0129/batt/pull/159): research references only; no GPL source copied or translated. Their reports are not local actuation evidence.

The standalone probe does not link into the normal app. [Third-party notices](../../apps/statbatt/THIRD_PARTY_NOTICES.md) accompany source; retain them with any distributed diagnostic binary.

## Remaining feasibility gate

The two inspected charge-hold interfaces provide no working route on this target. CHIE controls adapter input in the source reference, so it cannot be labeled charge hold retaining external power. A proposed five-second normal-user CHIE experiment still lacks a credible exact-target emergency recovery path if neither the experiment nor an independent guardian can restore the baseline. A software deadline is not a firmware expiry. Neither unplug/replug nor reboot has been proved to clear this latch on this exact tuple.

Do not perform that write, install a speculative daemon, bypass denial, or enable discharge from this report. Full custom hold/discharge/thermal acceptance stays open. Any accepted reduction must be an explicit owner decision; see [v1 acceptance](../V1_ACCEPTANCE.md) and [lab protocol](../LAB_PROTOCOL.md).
