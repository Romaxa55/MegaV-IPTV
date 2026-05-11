# Requirements Document — hero-collapse-tile-morph

## Introduction

На `CinematicHomeScreen` коллапс hero при переходе фокуса вниз к рядам и его
обратное появление при подъёме реализованы через `AnimatedCrossFade`: hero
визуально **исчезает в чёрную пустоту**, оставляя пользователя без точки
опоры, а возврат вверх дорисовывает hero «из ниоткуда» обратным крестфейдом.
User feedback (дословно):

- «Когда возвращаюсь вверх не появляется эта хуйня, ну то есть все исчезает,
  чёрное место остается пустое.»
- «херо херо наверно сделать размером как буддто 1 строчка из плиток ну вс
  поуму и по феншую.»
- «скрытие с эффектом сдвига чтоль.»

Цель спецификации — **киносъёмочный morph**: hero не исчезает, а **сжимается
до размера обычной плитки в слоте 0 первой полосы** через slide + scale
анимацию. Hero и плитка слота 0 — это **один и тот же виджет в дереве** в
двух layout-режимах (`expanded` и `collapsed`), что устраняет cross-fade,
делает focus transfer тривиальным и убирает «чёрные дыры» в кадре.

Spec поверх уже сгенерированного upstream `home-grid-stability-pass`: оттуда
берутся финальные значения `cardHeightDp` (≈720), `pinnedSlotIdx` (=1),
`focusedScale` (1.01) и **Pinned-Slot Invariant** как read-only контракт.
Закрытые спеки (`home-cinematic-redesign`, `home-grid-optimization`,
`home-grid-visual-polish`) **не открываются**: все правки оформляются как
новый виджет (`HeroTileMorph`) + точечная интеграция в `CinemaRow`
(опциональный `firstSlot` API) и `CinematicHomeScreen` (рефакторинг hero из
`Positioned` в `firstSlot` первой `CinemaRow`).

## Boundary Context

- **In scope**:
  - Новый виджет `HeroTileMorph` с двумя layout-режимами (`expanded`
    ≈620 dp height, `collapsed` ≈ `GridTokens.cardHeightDp` dp).
  - Анимация morph: единый `AnimationController`, фиксированная длительность
    **300 ms**, кривая `Curves.easeInOutCubic`, никакой spring physics.
  - State machine из 4 наблюдаемых состояний (`idle-expanded`,
    `morphing-collapsing`, `idle-collapsed`, `morphing-expanding`).
  - Подмена первой плитки первой `CinemaRow` через **новый опциональный
    `firstSlot` API** — единственная правка `cinema_row.dart`.
  - Рефакторинг `CinematicHomeScreen`: hero перестаёт быть отдельным
    `Positioned(top:0, height:expandedH)` блоком; вместо этого первая
    `CategoryRowWrapper` / `CinemaRow` принимает hero-tile widget как
    `firstSlot`.
  - Focus transfer контракт: persistent `FocusNode` живёт через все 4
    состояния morph, не уничтожается между layout-режимами.
  - `MediaQuery.disableAnimations` honoring: instant snap между режимами
    без вызова `AnimationController.forward()` / `reverse()`.
  - Opacity-crossfade вспомогательных элементов (Watch button, title,
    full-bleed backdrop) во второй половине анимации; обложка + краткая
    подпись постепенно проявляются в коллапсированном режиме.
  - Тесты:
    - State machine unit test (4 состояния, переходы, completion callbacks).
    - Focus survival widget test (focus сохраняется на hero-tile через
      morph в обе стороны).
    - Manual smoke test checklist для macOS debug build / TV smoke.

- **Out of scope**:
  - Любое изменение `cardHeightDp`, `pinnedSlotIdx`, `focusedScale`,
    `metadataReservedHeightDp`, `unfocusedNeighbourOpacity` — owned by
    `home-grid-stability-pass`, read-only.
  - Алгоритм `pickColumns 3/4/5` — closed `home-grid-optimization`.
  - Pinned-Slot scrolling механика и focus debounce 400 мс — closed
    `home-grid-optimization` + `home-grid-stability-pass`.
  - Carousel timer (8 с), preview player lifecycle, boot overlay logic —
    `home-cinematic-redesign`, **не модифицируем семантически**, только
    переносим точки крепления при рефакторинге layout'а.
  - Hero для legacy `HomeScreen` (`/home`) — не затрагивается.
  - Fade-edge через `DecoratedBox` — closed `home-grid-visual-polish`.
  - `SafeFocusRing` и pure perf-toolkit — closed `perf-safe-widgets`.
  - Видео-preview логика и `PlayerManager` — `player-cinematic-redesign`
    + `core/player/`.

- **Adjacent expectations**:
  - Все 30+ существующих тестов остаются зелёными. Если рефакторинг
    `CinematicHomeScreen` ломает числовые ожидания (например, позиция
    hero), правка фиксирует новое наблюдаемое поведение, а не подгоняет
    тест.
  - Steering `flutter-tv-perf.md`: запрещено `BackdropFilter`,
    `ImageFilter.blur`, `ShaderMask`, `BoxShadow.blurRadius > 12`,
    `AnimatedContainer.width`. Разрешено `Transform.scale`,
    `AnimatedPositioned`, `Opacity`, `AnimatedBuilder`, `TweenSequence`.
  - Никаких новых пакетов в `pubspec.yaml`.

## Requirements

### Requirement 1: Hero morph state machine

**Objective:** As a TV user, I want hero collapse/expand to behave as a
predictable, observable state machine with exactly four states, so that the
animation never lands in an undefined intermediate frame and the focus
behaviour is reasoning-friendly for both implementation and tests.

#### Acceptance Criteria

1. The HeroTileMorph widget shall expose exactly four observable states: `idle-expanded`, `morphing-collapsing`, `idle-collapsed`, `morphing-expanding`.
2. While the widget is in `idle-expanded` state, the layout shall be the full hero geometry (height equals `expandedHeroHeightDp`, full backdrop visible, Watch button visible) and no `AnimationController` shall be active.
3. While the widget is in `idle-collapsed` state, the layout shall be the tile geometry equal to `GridTokens.cardHeightDp` × the slot-0 width computed by the parent CinemaRow, and no `AnimationController` shall be active.
4. While focus enters the hero subtree from below, the widget shall transition `idle-collapsed → morphing-expanding → idle-expanded` exactly once per user gesture, with the controller running from 1.0 to 0.0.
5. While focus leaves the hero subtree downward to the rails, the widget shall transition `idle-expanded → morphing-collapsing → idle-collapsed` exactly once per user gesture, with the controller running from 0.0 to 1.0.
6. When a focus gesture reverses mid-morph (user re-enters hero before collapse finishes, or leaves hero before expand finishes), the widget shall reverse the running animation in place and finish in the most-recent target state, without restarting the controller from a boundary value.
7. The widget shall guarantee that no two parallel hero subtrees exist in the render tree at any frame, including all intermediate morph frames (single-source contract).

### Requirement 2: Длительность и кривая анимации

**Objective:** As a TV user, I want the morph animation to feel cinematic
but never sluggish, with deterministic timing so it never depends on input
velocity or spring physics, so that focus transitions stay snappy and
predictable on the reference TV box.

#### Acceptance Criteria

1. The HeroTileMorph widget shall drive its layout interpolation with a single `AnimationController` whose `duration` equals **300 milliseconds**.
2. The HeroTileMorph widget shall apply `Curves.easeInOutCubic` to the controller value for all geometry interpolation (size, position, scale).
3. The HeroTileMorph widget shall NOT use spring physics, `SpringDescription`, `simulation:`, or any time-variable curve — the duration is fixed and deterministic.
4. The HeroTileMorph widget shall complete the full transition between layout modes within the configured 300 ms window plus a single post-frame settle, after which the controller is at its boundary value (0.0 or 1.0) and `isAnimating == false`.

### Requirement 3: Single-source widget contract (hero == слот 0)

**Objective:** As an integrator of the cinematic home screen, I want the
hero block and the first tile of the first row to be the SAME widget
instance in the widget tree (in two layout modes), so that there is no
cross-fade, no double widget tree, and focus transfer becomes a
free-by-construction property.

#### Acceptance Criteria

1. The CinematicHomeScreen shall NOT render the hero as a sibling `Positioned` widget; instead the first CinemaRow's slot 0 shall host the HeroTileMorph widget through a new optional `firstSlot` API on CinemaRow.
2. The CinemaRow widget shall accept an optional parameter (`firstSlot`, `WidgetBuilder?` or equivalent) that, when non-null, replaces the rendering of the first tile (index 0) with the supplied builder's result.
3. While `firstSlot` is null (default, used by all non-first rows and by legacy HomeScreen), the CinemaRow shall render exactly as before — no change to existing call sites.
4. While `firstSlot` is non-null, the CinemaRow shall delegate focus, scroll, key events and pinned-slot scrolling for index 0 to whatever widget the builder returns; the row shall NOT wrap the first-slot widget in its own Focus/MouseRegion (the firstSlot widget owns its focus).
5. The CinematicHomeScreen shall create exactly one HeroTileMorph instance per build, mounted via the firstSlot of the first CinemaRow only.
6. While inspecting the widget tree during any intermediate morph frame, the tree shall contain exactly one HeroTileMorph instance and zero `AnimatedCrossFade` widgets for hero collapse purposes.

### Requirement 4: Focus survives morph

**Objective:** As a TV user, I want the D-pad focus to remain on the hero
during expand/collapse and on the first tile of the row when collapsed, so
that I never have to chase focus after a morph and `requestFocus()` calls
are not needed after animation completion.

#### Acceptance Criteria

1. The HeroTileMorph widget shall own a persistent `FocusNode` (constructed once in `initState`, disposed once in `dispose`) that lives through all four state-machine states.
2. While transitioning `idle-expanded → morphing-collapsing → idle-collapsed`, the persistent FocusNode shall retain its `hasFocus` value throughout the morph (no intermediate frame may show `hasFocus == false` caused by widget rebuild).
3. While transitioning `idle-collapsed → morphing-expanding → idle-expanded`, the persistent FocusNode shall retain its `hasFocus` value throughout the morph.
4. After morph completion in either direction, the focus invariant shall hold without any explicit `FocusNode.requestFocus()` call from the animation completion callback.
5. The HeroTileMorph widget shall NOT swap, reparent, or recreate its FocusNode between layout modes — there is exactly one node from mount to unmount.
6. The widget shall be verifiable by an automated widget test that mounts HeroTileMorph, drives focus to its node, runs a full collapse-then-expand cycle, and asserts `focusNode.hasFocus == true` at every sampled frame.

### Requirement 5: MediaQuery.disableAnimations honoring (accessibility)

**Objective:** As a user who has enabled the system-level «reduce motion»
preference, I want the hero morph to skip animation and snap instantly to
the target layout, so that the home screen respects accessibility settings
and never causes vestibular discomfort.

#### Acceptance Criteria

1. While `MediaQuery.disableAnimationsOf(context)` is `true`, the HeroTileMorph widget shall snap directly to the target layout mode without running the `AnimationController`.
2. While snapping under disableAnimations, the widget shall set the controller value directly to the boundary (`0.0` for expanded, `1.0` for collapsed) without invoking `forward()` or `reverse()`.
3. The widget shall react to changes in `MediaQuery.disableAnimationsOf(context)` mid-flight: if the user toggles reduce-motion while a morph is in progress, the next build shall complete the controller immediately to its target boundary.
4. While `disableAnimations` is `true`, the four-state machine shall still hold (`idle-expanded` and `idle-collapsed` remain reachable), but the two `morphing-*` states shall not appear in any sampled frame.

### Requirement 6: Visual composition (backdrop, title, watch button, cover)

**Objective:** As a TV user, I want the visual contents of the hero to fade
out smoothly into the tile's contents (cover image, channel caption)
without any black gap or jump, so that the morph reads as a single visual
flow from full-bleed hero to a Netflix-style tile.

#### Acceptance Criteria

1. While in `idle-expanded` state, the HeroTileMorph widget shall render the full-bleed backdrop image, large title, Watch button, and any auxiliary metadata the existing `CinematicHeroBlock` showed.
2. While in `idle-collapsed` state, the HeroTileMorph widget shall render the same cover image as a tile, plus a brief caption (channel name and/or programme title) consistent with how slot-0 of a CinemaRow looks for the same `NowPlayingItem`.
3. While in `morphing-collapsing` state, the auxiliary elements (Watch button, large title, full-bleed backdrop opacity) shall crossfade from visible to hidden using `Opacity` only (no `BackdropFilter`, no `ShaderMask`), and the tile cover + caption shall crossfade from hidden to visible.
4. While in `morphing-expanding` state, the same opacity crossfade shall run in reverse.
5. The opacity crossfade shall be driven from the same `AnimationController` as the geometry morph, applied through a `TweenSequence` such that the crossfade occupies the **last 50% of the controller value range** (controller value `0.5..1.0` for collapsing, `0.0..0.5` for expanding when running reversed).
6. During the first 50% of the controller value range the auxiliary elements shall remain at their starting opacity to allow the geometry morph to dominate the early phase of the animation.

### Requirement 7: No black gaps / no jumps on any intermediate frame

**Objective:** As a TV user, I want every intermediate frame of the morph
to be visually continuous, with no «black hole» where the hero used to be
and no perceptible jump in geometry, so that the animation truly reads as
a single object morphing rather than two widgets swapping.

#### Acceptance Criteria

1. While any morph state is active, the bounding rect of HeroTileMorph in screen space shall change monotonically (height shrinks or grows without reversal) frame-to-frame, except when the user reverses gesture mid-morph (Req 1.6).
2. While any morph state is active, no Container with `color: Colors.transparent` or `color: Colors.black` shall appear as a visible «gap» where the hero used to be — the morphing widget's bounding box itself is the only source of geometry change.
3. While the morph transitions into `idle-collapsed`, the final bounding rect of HeroTileMorph shall match the bounding rect that slot-0 of the same CinemaRow would have if `firstSlot` were null, within ±1.0 logical pixel tolerance.
4. While the morph transitions into `idle-expanded`, the final bounding rect of HeroTileMorph shall match the expected hero geometry (top=0, left=0, right=screenWidth, height=`expandedHeroHeightDp`) within ±1.0 logical pixel tolerance.
5. The other tiles in the first CinemaRow (index ≥ 1) shall not visibly «jump» when the firstSlot transitions between layout modes — their layout positions are driven entirely by the CinemaRow's existing slot layout, with HeroTileMorph occupying slot 0 in both modes (only the slot 0 widget's visible bounds change).

### Requirement 8: Preservation of carousel timer, preview player, boot overlay

**Objective:** As an operator of MegaV IPTV, I want the existing
CinematicHomeScreen plumbing (8 s hero carousel, 7 s preview-player
trigger after hover settle, boot overlay with baseUrl prompt, clock tick)
to keep working after the hero-as-firstSlot refactor, so that no
operationally important behaviour is regressed by the geometry change.

#### Acceptance Criteria

1. While the refactor moves the hero from a standalone `Positioned` into the firstSlot of the first CinemaRow, the carousel timer (`Timer.periodic(_carouselInterval, ...)`) shall continue to advance `_carouselIndex` every 8 seconds while `_heroFocused == true`.
2. While the refactor moves the hero from a standalone `Positioned` into the firstSlot of the first CinemaRow, the hover settle behaviour (`_hoverSettleDelay = 600ms` debounce → `_previewTimer = 7000ms` trigger → `_startPreview()`) shall continue to operate identically for non-hero tiles.
3. While the refactor moves the hero from a standalone `Positioned` into the firstSlot of the first CinemaRow, the boot overlay (`_showBootOverlay`, `_runHomeBootstrap`, `_bootUrlController`, `_onBootRetryConnect`, `_onBootFadeOutEnded`) shall continue to drive the same launch sequence with the same observable transitions.
4. While the refactor moves the hero from a standalone `Positioned` into the firstSlot of the first CinemaRow, the StatusBar clock tick (`_clockTimer = Timer.periodic(30s, ...)`) shall continue to update `_clockTime` and propagate to the hero block.
5. While the refactor moves the hero from a standalone `Positioned` into the firstSlot of the first CinemaRow, the post-boot focus request (`_scheduleHeroWatchFocus`) shall continue to land focus on the hero Watch button after boot overlay fades out — the persistent FocusNode of HeroTileMorph shall be the focus target instead of `_heroWatchFocusNode`, but the observable behaviour (Watch button gains focus) is identical.
6. While the refactor moves the hero from a standalone `Positioned` into the firstSlot of the first CinemaRow, the `_isWatchFocused` flag and the `_onHoveredItemChanged` debounce pipeline shall continue to work with no semantic change.

### Requirement 9: Legacy /home (HomeScreen) is not touched

**Objective:** As a maintainer of the legacy home, I want the legacy
`HomeScreen` route (`/home`) to remain completely unaffected by this spec,
so that mobile-adaptive routing and TV legacy fallback continue to work
without coordinated changes.

#### Acceptance Criteria

1. While this spec is in effect, the file `lib/features/home/home_screen.dart` shall not be modified.
2. While the legacy `/home` route renders, it shall use `CinemaRow` with `firstSlot == null` for all rows, preserving the previous rendering path bit-for-bit.
3. The CinemaRow modifications introduced by this spec shall be **backward compatible**: existing call sites that do not specify `firstSlot` shall observe no behavioural change.
4. The HeroTileMorph widget shall NOT be imported, instantiated, or referenced from `lib/features/home/home_screen.dart` or any legacy home file.

### Requirement 10: TV-target performance compliance

**Objective:** As a TV user on a low-end Realtek box (rtd2851a), I want
the morph not to regress the GPU/CPU budget of the home screen, so that
the visual upgrade is not paid for in frame drops.

#### Acceptance Criteria

1. The HeroTileMorph widget shall NOT introduce any of the APIs prohibited by `flutter-tv-perf.md` for the TV target (`BackdropFilter`, `ImageFilter.blur`, `ShaderMask`, `BoxShadow.blurRadius > 12`, `AnimatedContainer.width` for morph geometry).
2. The HeroTileMorph widget shall use only `Transform.scale`, `AnimatedPositioned`, `Opacity`, `AnimatedBuilder`, `TweenSequence`, and `SizedBox` for its layout/animation primitives.
3. While the morph runs at 60 fps target on the reference device, the average GPU rasterizer frame time shall remain at or below 16.7 ms (matching the budget enforced by `home-grid-optimization`, `home-grid-visual-polish`, `home-grid-stability-pass`).
4. The HeroTileMorph widget shall instantiate exactly one `AnimationController` (no parallel controllers, no per-property controllers), and shall dispose it in `dispose`.
5. The HeroTileMorph widget shall NOT add any new continuous stream subscriptions or per-frame rebuilds beyond the single `AnimationController` tick.
