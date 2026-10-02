# StatBatt landing page

A dependency-free static landing page for the current local StatBatt build. Source and delivery files live in `dist/`; the native app's `apps/statbatt/dist/` is separate.

## Preview

From the repository root:

```sh
python3 -m http.server 4187 --bind 127.0.0.1 --directory apps/landing/dist
```

Open `http://127.0.0.1:4187/`. No package installation or build step is required. The page uses local assets, system fonts, semantic HTML, and native disclosure elements for the FAQs. There are no external requests, forms, tracking, or downloads.

## Editing and release

- `dist/index.html`: content, navigation, metadata, and illustrative product panel.
- `dist/styles.css`: responsive layout, theme, focus states, and reduced-motion behavior.
- `dist/assets/battery-sculpture.jpg`: original AI-generated hero artwork; see `ART_DIRECTION.md` for provenance and the generation prompt.
- App panel and chart values are synthetic and visibly labeled. They are website illustrations, not app screenshots or live telemetry.
- Claims reflect the current development build. The Apple 80% path remains subject to the documented exact-target qualification and pending end-to-end checks; no public download is implied.

The owner authorized the private [Orca-Solutions/stat-batt](https://github.com/Orca-Solutions/stat-batt) remote and a setup/landing PR. Source and original project assets are [proprietary to Orca Solutions](../../LICENSE). Deployment follows review; no hosting provider or public URL is configured yet, and no app release has been published. Static hosting must serve only `apps/landing/dist/`, never the repository root or native app distribution folder. No install or build command is needed for this page.

See the [build and deployment guide](../../docs/BUILD_GUIDE.md) and [user guide](../../docs/USER_GUIDE.md).

Before publishing, recheck the copy against the app's latest implementation and distribution status.
