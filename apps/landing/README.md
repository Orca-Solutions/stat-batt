# StatBatt archive landing page

A dependency-free static archive of StatBatt, discontinued October 17, 2026. The original design and artwork remain, with an archive notice and final status. Source and delivery files live in `dist/`; the native app's `apps/statbatt/dist/` is separate. See [the archive record](../../ARCHIVE.md).

## Preview

From the repository root:

```sh
python3 -m http.server 4187 --bind 127.0.0.1 --directory apps/landing/dist
```

Open `http://127.0.0.1:4187/`. No package installation or build step is required. The page uses local assets, system fonts, semantic HTML, and native disclosure elements for the FAQs. There are no external requests, forms, tracking, or downloads.

## Editing and release

- `dist/index.html`: content, navigation, metadata, and illustrative product panel.
- `dist/styles.css`: responsive layout, theme, focus states, and reduced-motion behavior.
- `dist/compare.html` and `dist/comparison.css`: side-by-side StatBatt, coconutBattery, and Energiza comparison, official evidence links, and mobile table layout.
- `dist/assets/battery-sculpture.jpg`: original AI-generated hero artwork; see `ART_DIRECTION.md` for provenance and the generation prompt.
- App panel and chart values are synthetic and visibly labeled. They are website illustrations, not app screenshots or live telemetry.
- The home page summarizes the final saved build-14 checkpoint. The comparison table preserves the October 2 build and vendor claims, with a visible historical notice. No public download or future release is offered.

The [Orca-Solutions/stat-batt](https://github.com/Orca-Solutions/stat-batt) repository is public; source and original project assets remain [proprietary to Orca Solutions](../../LICENSE). GitHub Pages is configured with the custom domain `statbatt.orcasolutions.dev`, using the existing main-branch static deployment workflow. Preserve that hosting and DNS for the archive. Static hosting must serve only `apps/landing/dist/`, never the repository root or native app distribution folder. No install or build command is needed.

See the [build and deployment guide](../../docs/BUILD_GUIDE.md) and [user guide](../../docs/USER_GUIDE.md).

The archive source merged through PR #5 (`3434509`). Before setting the GitHub repository read-only, verify its completed Pages deployment, HTTPS, and both archive routes. Source merge alone does not establish hosted acceptance; this documentation does not change deployment or repository archive settings.

Vendor documentation was checked October 2, 2026; it does not constitute live competitor tests or current purchasing guidance. Preserve the date and [comparison source notes](../../docs/research/BATTERY_COMPARISON.md). Verify `compare.html` alongside the home route before deployment. `archive-preview.jpg` records the archive notice; the older preview JPGs record the original design.
