# Energiza primary-source ledger

Reviewed: 2026-10-01. Public read-only research. The links below are source records; they do not imply runtime verification or permission to reuse vendor assets/code.

| ID | Source | Use and limitations |
|---|---|---|
| E-01 | [Vendor product and FAQ](https://appgineers.de/energiza/) | Feature tiers and advertised compatibility. Marketing copy may lag releases. |
| E-02 | [Vendor changelog](https://appgineers.de/energiza/files/Energiza.html) | Dated release evidence and lifecycle regression categories. No runtime tests. |
| E-03 | [Mac App Store listing](https://apps.apple.com/us/app/energiza-battery-monitor/id1643751440?mt=12) | Free monitor description, seller, version, metadata. Separate product from direct-download Pro. |
| E-04 | [Energiza EULA](https://appgineers.de/energiza/eula.html) | Authorship and proprietary license. Page title incorrectly says Privacy Policy; body is EULA, dated 2022-11-05. |
| E-05 | [Vendor imprint](https://appgineers.de/mountain/impressum.html) | Author identity. Linked from Energiza footer, hosted under Mountain. |
| E-06 | [General screenshot](https://appgineers.de/images/energiza_preferences_general.png) | Visual inspection in browser; historical helper version. |
| E-07 | [Charge Control screenshot](https://appgineers.de/images/energiza_preferences_charge_control.png) | Visible settings; dropdown choices not expanded. |
| E-08 | [Appearance screenshot](https://appgineers.de/images/energiza_preferences_appearance.png) | Visible selectors; not a complete option catalog. |
| E-09 | [Alerts screenshot](https://appgineers.de/images/energiza_preferences_alerts.png) | Visible event toggles; screenshot does not establish all later alert types. |
| E-10 | [Update screenshot](https://appgineers.de/images/energiza_preferences_update.png) | Historical updater layout. |
| E-11 | [Homebrew cask entry](https://formulae.brew.sh/cask/energiza) | Package metadata and route to binary distribution; not app source. |
| E-12 | [GitHub profile](https://github.com/jlinx) / [repository tab](https://github.com/jlinx?tab=repositories) | Same-name author candidate inspected directly; not vendor-verified identity. |

## Source search audit

Searches included `Energiza appgineers Linxweiler`, `Energiza GitHub Linxweiler`, `site:github.com "Energiza" "appgineers"`, `site:github.com "Jan Linxweiler"`, and public GitHub repository/user searches. The vendor site, FAQ, changelog, EULA, App Store seller, Homebrew entry, and same-name profile were inspected. GitHub’s `energiza appgineers` repository search showed zero matches; the broad name search contained unrelated projects. The `jlinx` repository tab showed all 15 public repositories, none containing an Energiza project name or description.

Conclusion: **no public Energiza application source or open-source license located**. This is a bounded search result, not proof that no private, unindexed, renamed, or separately licensed repository exists. Search-result URLs are not substitutes for the direct evidence above.

Unsuccessful API/web fetches were not treated as negative repository evidence. Generic `linxweiler` / `appgineers` profile URLs could not be validated through the web fetch tool. GitHub’s visible user search instead identified `jlinx`; no confirmed appgineers organization was located. No software was downloaded, installed, decompiled, or run.

## Freshness and contradictions

- Vendor homepage’s lineup still shows 1.3.3, while the Energiza product page and changelog show 1.3.5. Prefer the product changelog for release history. [Homepage](https://appgineers.de/)
- The App Store and direct-download versions have different release histories; do not combine them into a single current version.
- Older FAQ text describes stopping at sleep; later release history and settings screenshots establish configurable behavior. Treat sleep semantics as a dedicated specification and validation topic.
- Vendor images are linked references only. They are not checked into this project as reusable assets.
- “Supports macOS 10.13 and later” is a vendor claim. No source here establishes that Energiza or Stat Batt successfully controls charging on macOS 27.

For future decisions, preserve the source ID, reviewed date, explicit claim, confidence, tested build/model if any, and owner. Refresh vendor release and OS compatibility evidence before hardware prototyping or public compatibility claims.
