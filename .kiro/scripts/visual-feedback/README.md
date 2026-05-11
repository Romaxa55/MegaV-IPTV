# visual-feedback pipeline

Node.js infrastructure for the **visual-feedback-pipeline** kiro spec
(`.kiro/specs/visual-feedback-pipeline/`).

Captures screenshots of (a) JSX baseline prototypes from
`.kiro/design/megav-iptv-handoff/project/screens/` and (b) the MegaV Flutter
web build, then compares them pixel-by-pixel via `pixelmatch` and produces
an HTML report.

## Phase 1 (current): JSX-only

Flutter web snapshot is **temporarily blocked** by upstream
[GitHub #16](https://github.com/Romaxa55/MegaV-IPTV/issues/16) — `media_kit`
`NativePlayer.setProperty()` does not exist on the web stub and breaks
`flutter build web`. Until that is resolved:

- `npm run snapshot:jsx` works — produces baselines from JSX prototypes.
- `npm run diff` works against any pair of PNG sets.
- `npm run snapshot:flutter` and `npm run run` return
  `MANUAL_VERIFY_REQUIRED` referencing issue #16.
- The `kiro-validate-visual` skill (introduced in this spec) handles the
  `MANUAL_VERIFY_REQUIRED` path gracefully so downstream usage from
  `/kiro-impl` does not break.

## Prerequisites

- Node.js 20 or newer
- Chromium for Playwright (installed via `npx playwright install chromium`)
- For Phase 2 only: Flutter SDK with `flutter build web` working (currently blocked)

## Quickstart

```sh
cd .kiro/scripts/visual-feedback/
npm install
npx playwright install chromium

# Phase 1: capture JSX baselines for all 9 screens
npm run snapshot:jsx -- --all

# Phase 1: diff a current run against baselines (placeholder until 4.2)
npm run diff -- --run-dir .kiro/screenshots/<timestamp>
```

## Layout

```
.kiro/scripts/visual-feedback/
├── bin/                  # CLI entry points (snapshot-jsx, snapshot-flutter, diff, run-all)
├── lib/                  # Shared modules (playwright-config, png-utils, thresholds, report)
├── scenarios/            # D-pad scenarios for Flutter snapshot (JSON; Phase 2)
├── jsx-renderer/         # HTML+JS shim that renders one JSX screen for snapshot
├── package.json
├── package-lock.json     # Committed for reproducibility
└── README.md             # this file
```

## Configuration

Pass/fail thresholds live in `.kiro/screenshots/config.json`. If absent,
defaults are `pass_threshold: 2.0%`, `fail_threshold: 5.0%`.

## Known gotchas

- **`serve` MUST run without `-s` (SPA mode)**. With `-s`, `serve` strips
  the `.html` extension from URLs and produces a 301 redirect chain that
  ends in a directory listing instead of `index.html`. Use plain
  `npx serve -l <port> <root>` and address `index.html` explicitly.
- **In-browser Babel is slow** — first paint of the JSX renderer can take
  3-5 seconds. Snapshot scripts must wait for `window.__rendererReady ===
  true` (set by the renderer after `requestAnimationFrame` × 2), not just
  `domcontentloaded`.
- **`window.__rendererError`** is set to a slug describing what went wrong
  (`unknown_screen:…`, `component_missing:…`, `render_failed:…`). Snapshot
  scripts should treat any non-null value as a baseline failure.

## Documentation

Full design rationale, web ≠ TV caveats, and update procedure:
`.kiro/steering/visual-feedback.md`.
