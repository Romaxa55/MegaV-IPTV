# Requirements Document

## Introduction

`perf-safe-widgets` — мета-спек который определяет **safe replacements** для 7 design-handoff конфликтов с steering doc `.kiro/steering/flutter-tv-perf.md`. Handoff bundle от Claude Design содержит CSS-приёмы (full-screen `mix-blend-mode`, `blur(40px)`, `backdrop-filter` поверх video, multiple stacked gradients, `outline-offset`, `color-mix oklab`, `text-shadow blur 18px`) которые гарантированно регрессят perf на TV `rtd2851a` («сильно тормозит» — главный pain). Каждое replacement доказано безопасным в трёх закрытых perf-спеках (`home-grid-optimization`, `home-grid-visual-polish`, `player-overlay-state-machine`).

Этот спек **не модифицирует существующий код** — он создаёт переиспользуемые widgets / asset / pre-computed colors которые downstream screen-redesign спеки (#5-#12) обязаны импортировать вместо verbatim CSS-translation. Также дополняет steering doc новой секцией «Design handoff conflicts → safe replacements» как single source of truth.

Целевое устройство неизменно: Realtek `rtd2851a` Android TV-бокс. Performance budget из `flutter-tv-perf.md` соблюдается: avg `GPURasterizer::Draw ≤ 16.7 ms` при scroll, avg `BUILD ≤ 5/30 sec` в idle.

Зависимости: `design-system-foundation` (#4, ЗАКРЫТ — provides `AppPalette` для tinting + `AppColors` proxy для backward-compat).

## Boundary Context

- **In scope**:
  - 4 переиспользуемых widget'а в `lib/core/perf/perf_safe_widgets.dart`:
    - `SafeBackdrop` — pre-blurred hero artwork via cached `ui.Image` (replaces CSS `blur(40px)`).
    - `SafePill` — opaque-tint translucent fill (replaces CSS `backdrop-filter: blur(20px)` поверх video).
    - `SafeFocusRing` — `BoxShadow(spreadRadius: N, blurRadius: 0)` вокруг box (replaces CSS `outline + outline-offset`).
    - `SafeFilmGrain` — `Opacity` поверх baked PNG asset (replaces CSS `mix-blend-mode: overlay` + SVG turbulence).
  - 1 baked PNG asset `assets/grain_overlay.png` (1024×1024 pre-applied noise+overlay tone).
  - `lib/core/theme/computed_colors.dart` — pre-mixed Color constants заменяющие CSS `color-mix(oklab, ...)` для focus/hover hover-states.
  - 1 helper `combinedHeroGradient()` factory для свёрнутых stacked gradients (vignette + bottom-shade в один `RadialGradient`).
  - 1 helper guideline для `Shadow(blurRadius: 8)` вместо `text-shadow blur 18px` — встраивается в `MegaVTextStyles` через подходящие display styles.
  - Дополнение `.kiro/steering/flutter-tv-perf.md` секцией «Design handoff conflicts → safe replacements» с before/after табличкой и API хороших widget'ов.
  - Юнит-тесты для каждого safe widget (deterministic visual output, no perf regression при scroll).
  - Golden test для `SafeFilmGrain` opacity range, `SafeFocusRing` spread shadow geometry.

- **Out of scope**:
  - Применение safe widgets к screen-widget'ам — это owner отдельных screen-redesign спеков (#5, #7, #8, #11, etc.).
  - Mobile-specific перепалитра — на mobile (issue #12) `BackdropFilter` приемлем, perf-conflict только TV. Этот спек **не запрещает** raw `BackdropFilter` в mobile-specific code paths.
  - Server-side imgproxy интеграция (опция (b) для `SafeBackdrop`) — это потенциальная enhancement, не входит в minimum viable.
  - Native player engines, providers, models, API.
  - Модификации closed специй (`home-grid-*`, `player-overlay-state-machine`).

- **Adjacent expectations**:
  - Closed kiro specs продолжают компилироваться и проходить тесты без касания. `SafeFocusRing` ON-DEMAND переиспользуется home-grid feature через alias-path, но grid-карточки сами **не** переписываются.
  - `design-system-foundation` (#4) предоставляет `AppPalette.accent` для `SafeFocusRing` color, `AppPalette.background` для `combinedHeroGradient()` стопов, и базовые `AppColors.X` aliases для downstream call-sites.
  - GitHub issue #13 — primary discussion / progress tracking.
  - Все downstream screen-specs (#5-#12) **должны** импортировать widgets отсюда вместо CSS-translation. Ревью каждого screen-spec обязано проверять отсутствие raw `BackdropFilter`, `BoxShadow.blurRadius > 12`, `mix-blend-mode`, `ShaderMask` (через grep).

## Requirements

### Requirement 1: SafeBackdrop — pre-rendered blur вместо runtime `blur(40px)`

**Objective:** Как разработчик hero-секции, я хочу widget показывающий blurred-копию текущего hero artwork без перерисовки blur каждый кадр, чтобы scroll и idle оставались в budget на TV-боксе.

#### Acceptance Criteria

1. The Perf Safe Widgets module shall expose a `SafeBackdrop` widget that displays a pre-rendered blurred image given an artwork source and a configured blur sigma.
2. While a hero artwork source does not change, the `SafeBackdrop` shall not re-execute the heavy blur step on each frame.
3. When the hero artwork source changes, the `SafeBackdrop` shall re-render the blurred image once and cache the resulting `ui.Image` until the next change.
4. If the source artwork is not yet loaded or fails to load, the `SafeBackdrop` shall display a solid fill from the active palette's `background` token without crashing.
5. The `SafeBackdrop` shall not call `BackdropFilter`, `ImageFilter.blur` inline, or any other per-frame blur operation in its `build` method.
6. While `SafeBackdrop` is active, the `flutter analyze` static check on this module shall not flag any `BackdropFilter` usage.

### Requirement 2: SafePill — translucent fill без `backdrop-filter` поверх video

**Objective:** Как разработчик OSD chip / status badge поверх video-Texture, я хочу translucent pill без runtime blur, чтобы overlay не вызывал regression на TV.

#### Acceptance Criteria

1. The Perf Safe Widgets module shall expose a `SafePill` widget that displays a translucent fill via opaque tint with configurable alpha and rounded corners.
2. The `SafePill` shall not use `BackdropFilter` or any per-frame blur effect.
3. When given a tint color and alpha, the `SafePill` shall render an opaque-tint background using `Color.fromRGBO(R, G, B, alpha)` (or equivalent) without sampling the layer below.
4. The `SafePill` shall expose a `borderRadius` parameter using `AppRadius.brSm` / `brMd` / `brLg` constants from the theming foundation as recommended values.
5. While the active palette switches, the `SafePill` shall update its tint color on the next frame without manual rebuild.

### Requirement 3: SafeFocusRing — `BoxShadow spreadRadius` вместо CSS `outline + outline-offset`

**Objective:** Как разработчик фокусируемой плитки, я хочу solid-color ring рисуемый снаружи box с настраиваемым отступом, без блюра, чтобы visually воспроизвести `outline-offset: 3px` без perf-cost.

#### Acceptance Criteria

1. The Perf Safe Widgets module shall expose a `SafeFocusRing` widget that wraps a child and draws a solid-color ring outside the child's bounds when active.
2. The ring shall be rendered using `BoxShadow(spreadRadius: N, blurRadius: 0, color: ringColor)` (or equivalent solid-fill technique) without any gaussian blur.
3. When `isFocused` is `true`, the `SafeFocusRing` shall display the ring; when `isFocused` is `false`, the ring shall not be visible.
4. The ring color shall default to the active palette's `accent` token but allow override.
5. The ring offset (gap between child bounds and ring) shall be configurable and default to 3 logical pixels.
6. The transition between focused and unfocused states shall complete within 150 ms (Leanback `lb_card_activated_animation_duration`) using a GPU-only animation (no relayout of siblings).
7. While `flutter analyze` runs, the `SafeFocusRing` source shall not contain any `blurRadius` value greater than 12.

### Requirement 4: SafeFilmGrain — baked PNG overlay вместо runtime `mix-blend-mode`

**Objective:** Как разработчик фон-сцены, я хочу noise / film grain overlay без runtime per-frame blend, чтобы текстурный «киношный» вид не стоил 3-6 ms / frame.

#### Acceptance Criteria

1. The Perf Safe Widgets module shall expose a `SafeFilmGrain` widget that overlays a baked grain texture on top of its child or as a stack layer.
2. The grain shall be loaded from a static PNG asset bundled with the application (`assets/grain_overlay.png` or equivalent), with pre-applied noise and tone, sized for at least 1024×1024 logical pixels.
3. The `SafeFilmGrain` shall apply the asset using opacity in the range 0.04-0.12 (recommended default 0.08), without `BlendMode` other than `BlendMode.srcOver` (the default).
4. The `SafeFilmGrain` shall not be applied to scrolling content surfaces (a guideline enforced by inline doc-comment and steering note).
5. While the application loads, the grain asset shall be decoded and cached once; subsequent frames shall not re-decode it.
6. If the grain asset is missing or fails to load, the `SafeFilmGrain` shall render its child without crashing and log a one-time warning in debug mode.

### Requirement 5: combinedHeroGradient — single composite gradient вместо 3 stacked

**Objective:** Как разработчик hero-overlay, я хочу один `RadialGradient` свёрнутый из vignette + bottom-shade, чтобы потратить 1 проход вместо 3 на full-screen layer над видео-Texture.

#### Acceptance Criteria

1. The Perf Safe Widgets module shall expose a `combinedHeroGradient(AppPalette palette)` factory that returns a single `Gradient` composing the visual effect of vignette + bottom-shade in a single render pass.
2. The returned `Gradient` shall use `RadialGradient` with custom `stops` and `Alignment.bottomCenter` (or equivalent geometry) to approximate the visual layering of vignette + bottom shade.
3. The `combinedHeroGradient` output shall be drawable via a single `DecoratedBox` or `Container.decoration`, not stacked behind multiple `Positioned` overlays.
4. The factory shall accept an `AppPalette` to sample `background` / `surface1` / `surface2` tokens, ensuring the gradient adapts to the active palette.
5. The factory output shall not include any side-fade gradient by default; side fade, if needed, shall be the same color as the background and rely on natural padding.

### Requirement 6: computed_colors — pre-mixed `color-mix(oklab)` equivalents

**Objective:** Как разработчик hover/focus button styles, я хочу готовые pre-mixed Color константы заменяющие CSS `color-mix(in oklab, var(--text) 92%, var(--accent) 8%)`, чтобы Dart-Color не имел equivalent runtime-функции.

#### Acceptance Criteria

1. The Theme Foundation extension shall provide a class or set of constants in `lib/core/theme/computed_colors.dart` named `ComputedColors` (or equivalent) holding pre-mixed colors used by hover, pressed, and focus visual states.
2. Each pre-mixed color shall be derived from an active `AppPalette` instance by mixing two named tokens (e.g., `text` 92% with `accent` 8%) approximated in linear-RGB space and exposed as a `Color`.
3. The `ComputedColors` API shall accept an `AppPalette` argument and return a deterministic set of `Color` values for the same palette input.
4. While the active palette switches, callers requesting `ComputedColors.from(newPalette)` shall receive the new palette's mixed values; previously cached values are not used after the palette switch.
5. The `ComputedColors` class shall expose at minimum: `textTintAccent` (text 92% + accent 8%), `accentTintText` (accent 92% + text 8%), `surfaceTintAccent` (surface1 92% + accent 8%) — the three highest-frequency CSS uses from the handoff bundle.

### Requirement 7: Reduced text-shadow blur (≤ 12) for section titles

**Objective:** Как разработчик section-title с тенью, я хочу `Shadow(blurRadius ≤ 8)` вместо CSS `text-shadow blur 18px`, чтобы scroll section titles не вызывал per-frame gaussian re-rasterize.

#### Acceptance Criteria

1. The Theme Foundation's `MegaVTextStyles` shall not declare any `Shadow` with `blurRadius` greater than 12 logical pixels in its display styles.
2. Where a display style requires a drop-shadow effect, the Theme Foundation shall use `Shadow(blurRadius: 8, ...)` or smaller as the recommended default.
3. The Perf Safe Widgets module shall expose a documented constant `kSafeShadowBlurMax = 12.0` for downstream call-sites referencing the limit.

### Requirement 8: Steering doc augmentation

**Objective:** Как разработчик любого downstream screen-spec, я хочу единый source of truth со списком 7 design-handoff конфликтов и их safe replacements, чтобы не перепиливать perf на этапе validate-impl.

#### Acceptance Criteria

1. The steering document at `.kiro/steering/flutter-tv-perf.md` shall include a new section titled «Design handoff conflicts → safe replacements» listing each of the 7 conflicts with its safe replacement and a link to the corresponding widget API.
2. The steering update shall include a before/after table showing CSS source vs Flutter API name for each conflict.
3. The steering update shall reference issue #13 as primary discussion thread.
4. While downstream screen-specs (#5-#12) are written, their `requirements.md` and `design.md` shall reference safe replacements from this section explicitly.

### Requirement 9: Backward compatibility и closed-spec invariants

**Objective:** Как maintainer трёх закрытых perf-спеков, я хочу чтобы добавление этих widgets не сломало ни одного call-site из `home-grid-*` и `player-overlay-state-machine`.

#### Acceptance Criteria

1. The Perf Safe Widgets module shall not modify, rename, or remove any public symbol from `lib/core/theme/`, `lib/features/home/widgets/`, or `lib/features/player/`.
2. While the regression test suite runs, all existing 53 automated tests shall pass without modification.
3. The `flutter analyze` command shall report zero new errors after the module is added.
4. The `pubspec.yaml` shall not gain any new package dependency for this spec; all widgets use existing dependencies (`flutter`, `flutter_riverpod`, `google_fonts`).

### Requirement 10: Performance budget

**Objective:** Как пользователь TV-бокса, я хочу чтобы новые safe widgets не вводили новых perf-проблем на скроле и в idle.

#### Acceptance Criteria

1. The Perf Safe Widgets module shall not introduce any operation that violates `flutter-tv-perf.md` rules: no `BackdropFilter`, no `BoxShadow.blurRadius > 12`, no `ShaderMask`, no `mix-blend-mode` analog.
2. While a screen using `SafeBackdrop` displays a hero with stable artwork URL for 30 seconds, the BUILD-events count for the `SafeBackdrop` widget shall not exceed 5 per 30-second window.
3. While a screen scrolls a list of focusable cards each wrapped in `SafeFocusRing`, the avg `GPURasterizer::Draw` shall remain at or below 16.7 ms per frame on the reference TV-box.
4. While a screen displays `SafeFilmGrain` over a static layer, the GPU cost contribution of the grain layer shall not exceed 1 ms per frame on the reference TV-box.
5. The Perf Safe Widgets module shall include a perf-validation note in its README or doc-comment describing the measurement methodology (`flutter run --profile` + VM Service `getVMTimeline`).

### Requirement 11: Тестируемость

**Objective:** Как разработчик, я хочу чтобы каждый safe widget имел unit или widget тест, чтобы регрессии в этой инфраструктуре ловились до runtime.

#### Acceptance Criteria

1. The project shall include a unit test that asserts `SafeBackdrop` does not call `ImageFilter.blur` in its `build` method (verified via no-blur-in-paint introspection or equivalent).
2. The project shall include a widget test that asserts `SafePill` renders without spawning a saveLayer (verified via `tester.binding.takeException()` and a `SaveLayer` count check, or by visual inspection of the layer tree).
3. The project shall include a widget test that asserts `SafeFocusRing` toggles ring visibility on focus state change within 150 ms.
4. The project shall include a unit test that asserts `SafeFilmGrain` decodes its asset only once across multiple paint cycles.
5. The project shall include a unit test that asserts `combinedHeroGradient(palette)` returns a `Gradient` instance and that its colors derive from the supplied palette.
6. The project shall include a unit test that asserts `ComputedColors.from(palette).textTintAccent` differs between two distinct palettes (Noir Cobalt vs Crimson Reel), proving palette-awareness.
