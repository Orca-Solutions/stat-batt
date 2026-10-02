# Battery app comparison — sources and review

Checked October 2, 2026. The comparison page uses current official publisher documentation and the local StatBatt implementation. Vendor statements are documented claims, not independent device tests. No competitor was downloaded, installed, run, benchmarked, or modified for this page.

| Source | Evidence used |
|---|---|
| [coconutBattery product and release notes](https://www.coconut-flavour.com/coconutbattery/) | Mac/iOS diagnostics, history, Plus analysis/notifications, and explicit version4.4 macOS27 support |
| [Energiza product and FAQ](https://appgineers.de/energiza/) | Free monitoring/notifications and Pro charge bands, discharge, thermal protection |
| [Energiza changelog](https://appgineers.de/energiza/files/Energiza.html) | Published1.3.5/M5 and1.3.4/Tahoe entries; no explicit macOS27 entry at review |
| [StatBatt implementation status](../IMPLEMENTATION_STATUS.md) and [app README](../../apps/statbatt/README.md) | Implemented local monitoring/history/CSV, target-specific native setup, and pending acceptance |

## Interpretation and maintenance

- Give competitors credit for documented features. An absent published claim is **not documented**, not evidence of an absent feature.
- Separate coconutBattery/Plus and Energiza's free monitor/Pro capabilities where the publisher identifies editions. Do not infer missing edition checkmarks from a text extraction.
- Do not imply that general OS compatibility establishes charging control on the exact StatBatt target. Lack of an explicit release-note entry does not establish incompatibility.
- StatBatt's design strengths are its explicit estimates/unavailable state, integrated local minute-resolution history/CSV with visible gaps, and capability-specific charging presentation. These are implementation choices, not proof of better measurement accuracy, battery longevity, performance, privacy, or overall feature parity.
- Preserve disclosure that StatBatt is a local development build with no public download and that its trusted Apple80% app/cutoff/lifecycle checks remain pending. Custom bands/discharge/thermal charging control remain unavailable.
- Do not classify competitors' general app operation as cloud-dependent from an optional online feature, or use unsupported price/support claims.
- The comparison uses original text and no competitor logos, screenshots, or code. Links identify the publishers and their evidence.
- Refresh the checked date and relevant official sources when changing a row. Product or qualification changes must be reflected on both the home page and comparison page.

The comparison is developed separately on `codex/battery-comparison`, based on the completed setup branch, and its PR targets `main`. The foundation [PR #1](https://github.com/Orca-Solutions/stat-batt/pull/1), `codex/monorepo-landing` → `main`, is merged. Its remote feature head matches `bc1022f`; all completed foundation work is committed and pushed.
