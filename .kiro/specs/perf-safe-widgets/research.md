# Research Log — perf-safe-widgets

## Discovery scope

**Type**: Extension (existing system).

**Sources**:
- `.kiro/steering/flutter-tv-perf.md` — proven perf rules from 3 closed specs.
- `.kiro/specs/perf-safe-widgets/brief.md` — 7 conflicts catalog (synced from GH issue #13).
- `.kiro/design/megav-iptv-handoff/project/themes.css` + `styles.css` + `*.jsx` — original handoff artefacts that introduced the conflicts.
- Closed kiro specs (`home-grid-optimization`, `home-grid-visual-polish`, `player-overlay-state-machine`) — patterns we must NOT regress.
- `lib/features/home/widgets/cinema_row.dart:468-475` — existing precedent for «gradient-overlay вместо ShaderMask» (confirms approach for `combinedHeroGradient`).
- `lib/features/home/widgets/cinema_card.dart:134` — current safe `blurRadius: 12` boundary.

## Key findings

1. **Pre-rendered blur is the only viable replacement for `blur(40px)` on TV-Mali**. Runtime `BackdropFilter` over Texture-video is catastrophic; runtime `ImageFilter.blur` in `build()` repeats per frame. Pre-render once via offscreen `PictureRecorder` + `ImageFilter.blur` → cache `ui.Image` keyed by source URL → display via `RawImage`. Cost: ~200ms one-shot per artwork change, then 0ms steady state.
2. **`BoxShadow(spreadRadius: N, blurRadius: 0)` exactly reproduces CSS `outline-offset`**. spread inflates the shadow rectangle outwards by N px; blur=0 keeps it crisp. No saveLayer (no blur).
3. **Baked PNG > runtime SVG turbulence**. Static asset `assets/grain_overlay.png` (1024×1024 with pre-applied noise + light overlay tone) drawn with `Opacity(0.08)` is one decode + one composite. `mix-blend-mode: overlay` analog in Flutter would require `BlendMode.overlay` which forces saveLayer per frame.
4. **Color mixing in Dart**: Flutter has no `color-mix(oklab)` equivalent. Linear-RGB lerp via `Color.lerp(a, b, t)` is the closest cheap approximation (gamma-incorrect but visually acceptable for tints). Pre-compute at palette construction time.
5. **Side-fade gradient is unnecessary** — current `cinema_row.dart` ends with the same `Color(0xFF08080F)` as background, so visually identical to no fade with proper bg-color matching.

## Architecture pattern decision

**Chosen**: Plain widgets in a new leaf-package `lib/core/perf/`, no global state, no provider integration. Each widget is `const`-constructible where possible, minimum dependencies (only `flutter/widgets.dart` + `flutter/material.dart` for `BoxShadow`). The `SafeBackdrop` widget owns an internal `StatefulWidget` + cache because pre-rendering is async; everything else is stateless.

**Why**:
- Leaf-package = zero coupling with feature widgets. Any screen-spec can `import 'package:megav_iptv/core/perf/perf_safe_widgets.dart'` without pulling extra deps.
- No provider scope = no Riverpod overrides needed in tests; pure unit tests via `pumpWidget`.
- `const` constructors where possible = compile-time canonicalization, zero allocation overhead.
- Single-file API (with internal split) = easier to grep / reference / maintain consistency.

**Rejected alternatives**:
- **Riverpod-managed pool of pre-rendered images**: overkill for one consumer (`SafeBackdrop`). Internal `StatefulWidget` cache is sufficient.
- **Per-widget separate file**: `lib/core/perf/safe_backdrop.dart`, `safe_pill.dart`, etc. — fragments API surface; harder to discover. One file with internal sub-classes is cleaner for 4 widgets.
- **Extension methods on existing widgets**: would couple safe primitives to specific widget types (`Container.safeFocused()`); breaks reusability.

## Technology alignment

- **No new packages**. `SafeBackdrop` uses `dart:ui` (`PictureRecorder`, `ImageFilter`, `ui.Image`) which is part of Flutter SDK. `SafeFilmGrain` uses `Image.asset` from `flutter/widgets.dart`. `combinedHeroGradient` returns built-in `RadialGradient`.
- `pubspec.yaml` modification: add `assets/grain_overlay.png` under `flutter.assets:` so the asset is bundled. No package addition.
- Foundation dependency: `lib/core/theme/app_palette.dart` for tinting (already provides `accent`, `background`, `text`, etc.).

## Risks

- **Risk**: Pre-rendering 1080p artwork via offscreen `PictureRecorder` may take 200-400ms on first hero-load, visible as a brief solid-fill flicker. **Mitigation**: render solid-fill background instantly while async rendering proceeds; swap to blurred image on completion. Document this latency budget in widget doc-comment.
- **Risk**: Asset bundle grows by ~50-100kb (1024×1024 PNG with high-frequency noise compresses poorly). **Mitigation**: optimize PNG via `pngquant` to ~30-40kb; document final size in spec.
- **Risk**: `Color.lerp` in linear-RGB diverges visibly from CSS `oklab` mixing for highly saturated palettes. **Mitigation**: limit `ComputedColors` API to small mix ratios (4-15% blend) where the difference is imperceptible. Document limitation.
- **Risk**: Some downstream screen-specs may forget to import safe widgets and reach for raw CSS-translation. **Mitigation**: add ai-grep regex check to validate-impl `kiro-validate-impl` template that flags raw `BackdropFilter` / `BoxShadow.blurRadius > 12` outside `lib/core/perf/`.

## Synthesis outcomes

- **Generalization found**: All 4 widgets share the «replace runtime saveLayer with pre-baked or no-blend» pattern. Documented in steering doc augmentation.
- **Build vs adopt**: 100% build (no third-party widget library covers TV-Mali constraints).
- **Simplifications**: Side-fade gradient dropped entirely (just match bg color with parent padding). Computed color mixing approximated via linear-RGB `Color.lerp` instead of true OKLab — visually adequate for the small tint ratios in handoff.
