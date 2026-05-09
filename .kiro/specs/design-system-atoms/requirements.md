# Requirements Document

## Introduction

`design-system-atoms` — Wave 2 финальный foundation-спек. Дизайн handoff вводит **13 новых atoms** которые переиспользуются всеми screen-redesign спеками (#5-#12). Без centralized atoms package каждый screen дублирует widgets, и любое изменение визуального языка касается 7+ файлов. Этот спек создаёт `lib/core/ui/atoms/` с 13 widget'ами + рефакторит 4 existing widgets в alignment с новым API.

Атомы — **pure presentation** (без bizz logic, без Riverpod state). Они потребляют:
- Theme tokens из `design-system-foundation` (#4, ЗАКРЫТ): `AppPalette`, `AppRadius`, `MegaVTextStyles`, `AppColors` proxy.
- Safe widget primitives из `perf-safe-widgets` (#13, ЗАКРЫТ): `SafePill`, `SafeFocusRing`, `SafeFilmGrain`, `SafeBackdrop`, `combinedHeroGradient`, `ComputedColors`, `kSafeShadowBlurMax`.

Атомы НЕ модифицируют: closed специй (`home-grid-*`, `player-overlay-state-machine`), data layer, native player engines, routing.

Целевое устройство неизменно: Realtek `rtd2851a` Android TV-бокс. Performance budget из `flutter-tv-perf.md` соблюдается.

См. `brief.md`, GH issue #14, и handoff bundle (`atoms.jsx`, `styles.css`) для design source-of-truth.

## Boundary Context

- **In scope** (NEW в `lib/core/ui/atoms/`):
  - `Brand` — мини-логотип (gradient square + cutout) + wordmark.
  - `StatusBar` — city/temp/time pill с flag (упрощённая версия для editorial home).
  - `Chip` (unified) — variants `live`/`brand`/`gold`/`ghost`/`default`. `live` имеет lightweight pulse animation.
  - `Poster` — landscape & portrait variants, `hideText`, badge slots TL/TR, optional progress bar.
  - `MMLogo` — small "M" channel badge (38×38).
  - `GenreTabs` — horizontal tab strip с underline-on-active.
  - `SectionTitle` — H3 + italic em + count + optional «more →» action.
  - `RemoteHint` — keycap pills row (стрелки/OK/BACK).
  - `MvButton` — variants `primary`/`ghost`/`accent` + sizes.
  - `MvIconButton` — 38×38 rounded icon button.
  - `MvTrack` — progress bar с glow knob (для контента, EPG, settings).
  - `MvStrip` — filmstrip frames (для editorial home).
  - `MvKey` — keycap (single key visual для RemoteHint composition).
  - Golden tests + unit tests для каждого atom.
  - `lib/core/ui/atoms/atoms.dart` — barrel export.

- **In scope** (REFACTOR existing widgets для alignment):
  - `lib/features/home/widgets/glass_button.dart` → переименовать API в `MvButton.ghost` или сделать тонкий backward-compat wrapper.
  - `lib/features/home/widgets/hero_badges.dart` → split на `Chip` + `MMLogo`.
  - `lib/features/home/widgets/_card_poster.dart` → align styling с новым `Poster` atom (или оставить как есть если уже equivalent).
  - `lib/core/ui/channel_quality_badge.dart` → консолидировать в `Chip`.
  - Все рефакторы — backward-compat: existing call-sites продолжают работать без модификаций.

- **Out of scope**:
  - Screen-level layouts (issues #5-#12 owners).
  - Theming infrastructure (#4, ЗАКРЫТ).
  - Perf-safe primitives (#13, ЗАКРЫТ — atoms их потребляют).
  - Native player engines, providers, models, API.
  - Routing, navigation, focus tree management beyond atom-internal focus visuals.
  - Mobile-specific atom variants — issue #12 (`mobile-adaptive-layout`) решит, какие atoms адаптировать.

- **Adjacent expectations**:
  - Closed kiro specs продолжают компилироваться без изменений.
  - `design-system-foundation` (#4) предоставляет theme tokens — atoms читают их через `Theme.of(context)` и `AppColors.X`.
  - `perf-safe-widgets` (#13) предоставляет safe primitives — atoms композируют их вместо raw CSS-translation.
  - Все 65 существующих тестов продолжают проходить (Req 9.2 carried over from #4 + #13).
  - Downstream screen-specs (#5-#12) импортируют atoms через barrel `package:megav_iptv/core/ui/atoms/atoms.dart`.

## Requirements

### Requirement 1: Atom barrel export + directory scaffold

**Objective:** Как разработчик downstream screen-spec, я хочу импортировать любой atom через единый barrel, чтобы не помнить indivudal-file paths.

#### Acceptance Criteria

1. The Atoms Module shall expose a barrel file at `lib/core/ui/atoms/atoms.dart` that re-exports every public atom widget defined in this spec.
2. The Atoms Module shall keep all atom widgets in the `lib/core/ui/atoms/` directory, one widget per file (or one logical group per file when widgets are tightly coupled, e.g., `MvKey` + `RemoteHint`).
3. The Atoms Module shall not place feature-specific or screen-specific widgets in `lib/core/ui/atoms/`.

### Requirement 2: Brand atom

**Objective:** Как пользователь, видящий header экрана, я хочу видеть фирменный логотип MegaV (gradient square + bar) и optional wordmark.

#### Acceptance Criteria

1. The Brand atom shall render a gradient-filled square mark with an internal cutout shape, sized to the configured logical pixel dimension (default 32 px).
2. While `showWordmark` is true, the Brand atom shall display the «MegaV» text wordmark next to the square mark using the active palette's display font.
3. While `showWordmark` is false, the Brand atom shall display only the square mark.
4. The gradient colors shall derive from the active `AppPalette.accent` and `accentGlow` tokens.

### Requirement 3: StatusBar atom

**Objective:** Как пользователь editorial home screen, я хочу видеть мини status pill с city / temperature / time.

#### Acceptance Criteria

1. The StatusBar atom shall render a single horizontal row containing optional flag emoji, city label, temperature label, and current time label.
2. While any field is null or empty, the StatusBar atom shall omit it from the rendered row without leaving empty padding.
3. The StatusBar atom shall use a `SafePill`-style opaque-tint background with `AppPalette.surface2` and rounded corners using `AppRadius.brSm`.
4. The StatusBar atom shall not own clock-tick logic; the `time` value is supplied by the caller via constructor parameter.

### Requirement 4: Chip atom (unified, with variants)

**Objective:** Как разработчик любого экрана, я хочу один Chip widget с вариантами `live`/`brand`/`gold`/`ghost`/`default`, чтобы не плодить 5 отдельных badge widgets.

#### Acceptance Criteria

1. The Chip atom shall accept a `variant` parameter of an enumeration with values `live`, `brand`, `gold`, `ghost`, and `defaultVariant` (or equivalent), and shall apply variant-specific colors from the active palette.
2. While `variant` is `live`, the Chip atom shall render with `AppPalette.live` background and an animated pulse dot indicator.
3. The pulse animation, when active, shall be wrapped in a `RepaintBoundary` so its repaints do not bubble into parent widgets.
4. While `variant` is `brand`, the Chip atom shall render with `AppPalette.accentSoft` background and accent-tinted text.
5. While `variant` is `gold`, the Chip atom shall render with `AppPalette.goldSoft` background and gold text.
6. While `variant` is `ghost`, the Chip atom shall render with transparent background and dim-tone text.
7. While `variant` is `defaultVariant`, the Chip atom shall render with `AppPalette.surface2` background and primary text.
8. The Chip atom shall accept an optional leading icon and a required label string.

### Requirement 5: Poster atom

**Objective:** Как разработчик rail, я хочу landscape/portrait poster widget с opt-in title overlay, badge slots, и progress bar — чтобы не строить заново под каждый экран.

#### Acceptance Criteria

1. The Poster atom shall accept an `orientation` parameter of `landscape` or `portrait` (or equivalent enum) and apply the corresponding aspect ratio (16:9 for landscape, 2:3 for portrait).
2. The Poster atom shall display a primary image via `ImageProvider` with cover fit; if image fails to load, a solid `AppPalette.surface1` fallback shall be shown without crashing.
3. While `hideText` is false, the Poster atom shall overlay title and optional subtitle text near the bottom edge, scrim-shaded for readability.
4. While `hideText` is true, the Poster atom shall display only the image with no text overlay.
5. The Poster atom shall accept optional top-left (`badgeTL`) and top-right (`badgeTR`) widget slots, positioned with consistent insets.
6. While `progress` is non-null and within `[0.0, 1.0]`, the Poster atom shall render a thin progress bar overlay along the bottom edge.
7. While the Poster atom is focused (per `isFocused` parameter), it shall apply a `SafeFocusRing` with default ring color from `AppPalette.accent` (Req 3 of perf-safe-widgets).

### Requirement 6: MMLogo atom

**Objective:** Как разработчик channel rail, я хочу маленький "M" badge (38×38) для channel branding.

#### Acceptance Criteria

1. The MMLogo atom shall render at a fixed 38×38 logical pixel size unless overridden by a `size` parameter.
2. The MMLogo atom shall display the «M» glyph centered using the display font from the active theme.
3. The MMLogo atom shall accept an optional background color, defaulting to `AppPalette.accent`.

### Requirement 7: GenreTabs atom

**Objective:** Как пользователь, я хочу горизонтальный таб-стрип с подчёркиванием активного жанра, чтобы переключаться между категориями.

#### Acceptance Criteria

1. The GenreTabs atom shall accept a list of genre labels and an active index.
2. The GenreTabs atom shall render each label as a horizontal tab; the active tab shall display an underline using `AppPalette.accent` color.
3. The GenreTabs atom shall accept an `onTabChanged` callback invoked with the new index when a tab is activated.
4. The active-tab underline animation, when index changes, shall complete within 150 ms (per Leanback timing in `flutter-tv-perf.md`).

### Requirement 8: SectionTitle atom

**Objective:** Как разработчик rail header, я хочу H3 title с italic emphasis + optional count + «more →» action.

#### Acceptance Criteria

1. The SectionTitle atom shall display a primary title using `MegaVTextStyles.displayLarge` (or a comparable display style).
2. The SectionTitle atom shall accept an optional emphasis fragment displayed in italic style alongside the primary title.
3. The SectionTitle atom shall accept an optional count badge displayed after the title.
4. The SectionTitle atom shall accept an optional «more» action callback; when provided, a «more →» trailing button shall be shown.

### Requirement 9: RemoteHint atom

**Objective:** Как пользователь TV, я хочу видеть подсказки клавиш пульта (стрелки / OK / BACK) внизу экрана.

#### Acceptance Criteria

1. The RemoteHint atom shall render a horizontal row of keycap-style pills described by a list of `(key, label)` pairs.
2. The RemoteHint atom shall use the `MvKey` atom to render each individual keycap.
3. The RemoteHint atom shall lay out the row with consistent spacing using `AppRadius.brSm` for keycap rounding.
4. The RemoteHint atom shall accept an `alignment` parameter for horizontal alignment of the row.

### Requirement 10: MvButton atom (3 variants + sizes)

**Objective:** Как разработчик любого экрана, я хочу единый button widget с variants `primary`/`ghost`/`accent` и size scale, чтобы заменить ad-hoc `glass_button` и других.

#### Acceptance Criteria

1. The MvButton atom shall expose three constructor variants or a `variant` parameter: `MvButton.primary`, `MvButton.ghost`, `MvButton.accent`.
2. While the `primary` variant is active, the button shall render with `AppPalette.text` background and `AppPalette.background` foreground.
3. While the `ghost` variant is active, the button shall render with transparent background, `AppPalette.lineStrong` border, and `AppPalette.text` foreground.
4. While the `accent` variant is active, the button shall render with `AppPalette.accent` background and high-contrast white foreground.
5. The MvButton atom shall accept an optional leading icon and a required label.
6. While the button is focused, it shall apply a `SafeFocusRing` (perf-safe-widgets Req 3).
7. The MvButton atom shall expose at least two sizes (e.g., `small`, `medium`) selectable via parameter.
8. While the button is in a hover or pressed state on TV, no `Color.lerp` blend or runtime computation shall occur in the build path; pre-computed `ComputedColors.from(palette)` values shall be used (perf-safe-widgets Req 6).

### Requirement 11: MvIconButton atom

**Objective:** Как разработчик OSD, я хочу 38×38 icon button с rounded corners для compact controls.

#### Acceptance Criteria

1. The MvIconButton atom shall render at a fixed 38×38 logical pixel size unless overridden.
2. The MvIconButton atom shall accept a required icon widget and an `onPressed` callback.
3. The MvIconButton atom shall use `AppRadius.brSm` for corner rounding.
4. While the icon button is focused, it shall apply a `SafeFocusRing`.

### Requirement 12: MvTrack atom (progress bar)

**Objective:** Как разработчик контента / EPG / settings, я хочу единый progress bar с glow knob.

#### Acceptance Criteria

1. The MvTrack atom shall display a horizontal progress bar with a thin background and an `AppPalette.accent` filled portion driven by `progress` parameter in `[0.0, 1.0]`.
2. The MvTrack atom shall optionally display a knob (filled circle) positioned at the progress endpoint when `showKnob` is true.
3. The progress fill animation, when `progress` value changes, shall complete within 250 ms using `Curves.fastOutSlowIn` (per Leanback row scroll timing).
4. The MvTrack atom shall not perform layout-relevant animations; only paint properties (width factor, color) shall animate.

### Requirement 13: MvStrip atom (filmstrip frames)

**Objective:** Как разработчик editorial home, я хочу filmstrip-style decorative frames (для headers / dividers).

#### Acceptance Criteria

1. The MvStrip atom shall render a row of frame-shaped tiles (rectangles with sprocket-hole-like notches at top and bottom) using palette tokens.
2. The MvStrip atom shall accept a `frameCount` parameter and tile width parameter.
3. The MvStrip atom shall be purely decorative — no interactive elements, no focus ring, no animation.

### Requirement 14: MvKey atom (keycap)

**Objective:** Как `RemoteHint`, я нуждаюсь в single keycap widget для composition.

#### Acceptance Criteria

1. The MvKey atom shall render a single keycap-styled pill with the supplied key glyph (text or icon).
2. The MvKey atom shall use `AppPalette.surface2` background and `AppRadius.brXs` rounding.
3. The MvKey atom shall render at a compact size (height ≈ 24-28 logical pixels) suitable for inline hint rows.

### Requirement 15: Existing widget refactor — backward compatibility

**Objective:** Как maintainer 65 закрытых тестов, я хочу чтобы рефакторинг 4 existing widgets не сломал ни один call-site.

#### Acceptance Criteria

1. The Atoms Module shall keep `lib/features/home/widgets/glass_button.dart` callable from existing files; either as a deprecation-noted wrapper around `MvButton.ghost` or as the original widget plus a documentation pointer to `MvButton.ghost`.
2. The Atoms Module shall keep `lib/features/home/widgets/hero_badges.dart` callable from existing files; the file may internally use `Chip` + `MMLogo` atoms but its public API shall not change visibly.
3. The Atoms Module shall keep `lib/features/home/widgets/_card_poster.dart` callable from existing files; refactor is OPTIONAL and only if visual alignment with `Poster` atom is achievable without breaking call-sites.
4. The Atoms Module shall keep `lib/core/ui/channel_quality_badge.dart` callable from existing files; the file may internally use `Chip` atom but its public API shall not change visibly.
5. While the regression test suite runs, all 65 existing automated tests shall pass without modification.

### Requirement 16: Performance compliance

**Objective:** Как пользователь TV-бокса, я хочу чтобы новые atoms не вводили perf-проблем.

#### Acceptance Criteria

1. The Atoms Module shall not introduce any operation that violates `flutter-tv-perf.md` rules: no `BackdropFilter`, no `BoxShadow.blurRadius > 12`, no `ShaderMask`, no `mix-blend-mode` analog.
2. While an atom uses BoxShadow, its `blurRadius` shall not exceed `kSafeShadowBlurMax` (12.0) from `perf-safe-widgets`.
3. While an atom needs a focus ring, it shall use `SafeFocusRing` from `perf-safe-widgets`, not raw `BoxShadow.blurRadius` or `Border`.
4. While an atom needs a translucent fill over potentially video-bearing surfaces, it shall use `SafePill`-style opaque tint, not `BackdropFilter`.
5. While the `live` Chip variant is animating, the animation widget shall be wrapped in `RepaintBoundary` to isolate repaints.
6. While a `MvTrack` progress value changes, the animation shall update only paint properties; no relayout of siblings.

### Requirement 17: Тестируемость

**Objective:** Как разработчик, я хочу чтобы каждый atom имел unit или widget test, чтобы регрессии в этой инфраструктуре ловились до runtime.

#### Acceptance Criteria

1. The project shall include a unit or widget test for each of the 13 atoms verifying basic render does not crash and accepts the documented public parameters.
2. The project shall include a widget test for the `Chip` atom asserting all 5 variants render with distinct background colors derived from the active palette.
3. The project shall include a widget test for the `MvButton` atom asserting all 3 variants render with distinct foreground/background colors.
4. The project shall include a widget test for the `Poster` atom verifying that `hideText: true` renders no title text and that `progress` non-null renders a progress bar.
5. The project shall include a widget test for the `MvTrack` atom verifying that `progress: 0.5` results in a fill width factor of 0.5 (within tolerance).
6. The project shall include a regression test confirming that all 65 pre-existing tests still pass without modification.
7. Golden tests are out of mandatory scope for this spec but recommended; if added, they shall live under `test/core/ui/atoms/golden/` and be committed deterministically.

### Requirement 18: No new packages

**Objective:** Как maintainer pubspec, я хочу чтобы атомы не добавляли новых зависимостей.

#### Acceptance Criteria

1. The Atoms Module shall not add any new package to `pubspec.yaml`. All atoms use existing dependencies (`flutter`, `flutter_riverpod`, `google_fonts`).
2. While golden tests are added (optional), they shall use only the built-in `flutter_test` `matchesGoldenFile` matcher; no new golden-test framework shall be introduced.
