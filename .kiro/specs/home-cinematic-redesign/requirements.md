# Requirements Document — home-cinematic-redesign

## Introduction

`home-cinematic-redesign` — Wave 1 первый screen-spec, который собирает «Cinematic A» вариант главного экрана из готовых foundation-блоков. Цель — визуально «переплюнуть Netflix с пульта» (chat1.md), не нарушая perf-бюджет TV-Mali (rtd2851a) и не модифицируя закрытые специй `home-grid-optimization` + `home-grid-visual-polish`.

Ключевое отличие от текущего `lib/features/home/home_screen.dart` — это **IPTV, не VOD**: вместо «Continue watching» нужно показывать «Сейчас в эфире» и «Скоро в эфире». Layout — два rail-варианта (landscape 16:9 + portrait 2:3) над live эфир блоком, italic display-titles, hero с safe-backdrop, GenreTabs сверху, RemoteHint внизу.

Спек не переписывает `cinema_row.dart` / `cinema_card.dart` — они закрыты двумя специями. Вместо этого создаётся отдельный «cinematic» компонент-set в `lib/features/home/cinematic/`, который **использует** существующие CinemaRow + CinemaCard для контентных рядов, но добавляет **новые** обёртки для editorial masthead, dual-rail aspect ratio, hero, GenreTabs и RemoteHint.

Foundation deps (все закрыты + GO):
- `design-system-foundation` (#4) — `AppPalette`, `AppRadius`, `AppColors` proxy, `MegaVTextStyles`, `themeProvider`.
- `perf-safe-widgets` (#13) — `SafePill`, `SafeFocusRing`, `SafeFilmGrain`, `SafeBackdrop`, `combinedHeroGradient`, `ComputedColors`, `kSafeShadowBlurMax`, `assets/grain_overlay.png`.
- `design-system-atoms` (#14) — 13 atoms через barrel `package:megav_iptv/core/ui/atoms/atoms.dart`.

Целевое устройство неизменно: Realtek `rtd2851a` Android TV-бокс. Performance budget из `flutter-tv-perf.md` соблюдается жёстко (Req 9).

См. `brief.md`, GH issue #5, `.kiro/design/megav-iptv-handoff/project/cinematic-v2.jsx`, `.kiro/steering/roadmap.md`, и `.kiro/steering/flutter-tv-perf.md` для design / perf source-of-truth.

## Boundary Context

- **In scope** (NEW в `lib/features/home/cinematic/`):
  - `CinematicHomeScreen` — Riverpod-aware top-level widget, новая Cinematic A раскладка, gated через feature-flag/builder (Req 11).
  - `cinematic_hero_section.dart` — hero с `SafeBackdrop` + `combinedHeroGradient` + `SafeFilmGrain` + italic display title через `MegaVTextStyles.displayLarge`.
  - `cinematic_genre_tabs_bar.dart` — top-bar wrapper над atom `GenreTabs` с edge-fade overlay (DecoratedBox-only, без ShaderMask).
  - `cinematic_dual_rail.dart` — пара под-rail'ов: landscape 16:9 + portrait 2:3, hideText=true.
  - `cinematic_rail.dart` — внутренний rail-builder, делегирует на существующий `CategoryRowWrapper` (closed spec) для контента, но переопределяет poster aspect через атом `Poster` обёрткой.
  - `cinematic_live_strip.dart` — «эфир» strip с pulse `Chip(variant: live)` + `MvTrack` progress + название текущей передачи.
  - `cinematic_remote_hint_footer.dart` — нижняя docked-bar с atom `RemoteHint`.
  - `cinematic_section_title.dart` — обёртка над atom `SectionTitle` для italic em + count + «more →».
  - Widget tests (≥1 на каждый новый widget) + smoke-test всего экрана.
  - Optional роут `/home-cinematic` или feature-flag (`useCinematicHome`) для безопасной выкатки.

- **In scope** (BACKWARD-COMPAT TOUCH, NOT MODIFYING closed widgets):
  - Опциональный новый файл `lib/features/home/cinematic/cinematic_router.dart` или провайдер для переключения raceway между legacy `home_screen.dart` и новым `cinematic_home_screen.dart`. Existing `home_screen.dart` остаётся unchanged.

- **Out of scope** (HARD prohibition):
  - Любые модификации `cinema_row.dart`, `cinema_card.dart`, `_card_poster.dart`, `_grid_tokens.dart` — owned by closed `home-grid-optimization` + `home-grid-visual-polish`.
  - Любые модификации `pickColumns 3/4/5` логики — closed.
  - Editorial Bento layout (issue #6) — отдельный спек.
  - Mobile layout (issue #12) — отдельный спек.
  - Backend / data layer (`lib/core/api/*`, `lib/core/playlist/*`, `lib/core/epg/*`) — read-only кроме reuse существующих providers.
  - Native player engines (`lib/core/player/*`) — read-only.
  - `pickColumns` / breakpoint логика — read-only.
  - Sealed `PlayerUiState` (issue #8) — отдельный спек.
  - Возврат `BoxShadow.blurRadius=50`, `ShaderMask`, `BackdropFilter` — запрещено `flutter-tv-perf.md`.

- **Adjacent expectations**:
  - Closed kiro specs продолжают компилироваться без изменений: `cinema_row.dart`, `cinema_card.dart`, `_grid_tokens.dart`, `_card_poster.dart`.
  - `design-system-foundation` (#4): theme tokens читаются через `Theme.of(context)` и `AppColors.X`.
  - `perf-safe-widgets` (#13): все «glassy» / blur-эффекты композируются из `SafeBackdrop` + `SafeFilmGrain` + `SafePill` + `SafeFocusRing` + `combinedHeroGradient`.
  - `design-system-atoms` (#14): импорт через barrel `package:megav_iptv/core/ui/atoms/atoms.dart`.
  - Все 94 существующих теста продолжают проходить unchanged (Req 12.1, 13.4).
  - `flutter-tv-perf.md` правила обязательны (Req 9).

## Requirements

### Requirement 1: Cinematic Home screen scaffold + entry

**Objective:** Как пользователь TV-бокса, я хочу новую «Cinematic A» раскладку главного экрана, которая выглядит как cinema-poster wall и при этом не ломает существующее поведение.

#### Acceptance Criteria

1. The Cinematic Home Module shall provide a public `CinematicHomeScreen` widget located at `lib/features/home/cinematic/cinematic_home_screen.dart`.
2. The Cinematic Home Module shall expose `CinematicHomeScreen` via either a new `go_router` route entry or a Riverpod-gated builder, leaving the existing `HomeScreen` route registered and reachable.
3. While the cinematic entry point is selected, the application shall mount `CinematicHomeScreen` as the root home content without modifying `home_screen.dart`.
4. While the legacy entry point is selected, the application shall mount the original `HomeScreen` unchanged.
5. The Cinematic Home Module shall not place any new files inside `lib/features/home/widgets/` (closed-spec ownership) — all new files live under `lib/features/home/cinematic/`.

### Requirement 2: Hero section with SafeBackdrop + grain + combined gradient

**Objective:** Как пользователь, я хочу видеть кинематографичный hero — затемнённое видео-постер с одним суммарным gradient overlay, тонким film-grain, и italic display-title — без BackdropFilter / ShaderMask.

#### Acceptance Criteria

1. The Cinematic Hero shall render a backdrop image / video poster via `SafeBackdrop` with cached pre-rendered blur (no runtime `BackdropFilter`).
2. The Cinematic Hero shall apply exactly one stacked gradient overlay produced by `combinedHeroGradient(palette)` from `perf-safe-widgets`.
3. The Cinematic Hero shall apply a subtle film-grain layer via `SafeFilmGrain` on top of the gradient, never as `mix-blend-mode: overlay`.
4. The Cinematic Hero shall not use `BackdropFilter`, `ShaderMask`, or `BoxShadow.blurRadius > kSafeShadowBlurMax` anywhere in its build tree.
5. The Cinematic Hero shall display the active item title using `Theme.of(context).megavText.displayLarge` (italic display style) with text shadow capped at `kSafeShadowBlurMax`.
6. The Cinematic Hero shall display a meta row (live `Chip`, channel name via `MMLogo` + label, optional progress via `MvTrack`) composed from atoms only.
7. The Cinematic Hero shall expose a primary action (`MvButton.primary`) with focusable `FocusNode` that initially receives focus on mount.

### Requirement 3: GenreTabs top bar with edge-fade

**Objective:** Как пользователь, я хочу горизонтальную полосу жанров сверху с активным pill-индикатором, count'ами, и плавным fade по краям при overflow — без ShaderMask.

#### Acceptance Criteria

1. The Cinematic GenreTabs Bar shall render a horizontal strip of tabs using the `GenreTabs` atom from the atoms barrel.
2. The Cinematic GenreTabs Bar shall display each tab with its label and an optional numeric count obtained from upstream category providers.
3. The Cinematic GenreTabs Bar shall mark exactly one tab as `active` per render, derived from a Riverpod-managed selected-genre state.
4. The Cinematic GenreTabs Bar shall apply edge-fade overlays at the left and right ends using stacked `DecoratedBox` + `LinearGradient` (per `flutter-tv-perf.md` Replace-ShaderMask rule), never `ShaderMask`.
5. While the user navigates left/right at the strip's last tab boundary, the focus shall not wrap by default and shall surface the boundary event to the parent (consistent with existing CinemaRow boundary semantics).

### Requirement 4: Dual-rail layout — landscape + portrait

**Objective:** Как пользователь IPTV, я хочу видеть два отдельных rail'а с разными aspect ratios — landscape 16:9 для «сейчас в эфире» и portrait 2:3 для «фильмы / VOD-style» — без модификации закрытых cinema_row / cinema_card.

#### Acceptance Criteria

1. The Cinematic Dual-Rail shall expose a public widget that composes two visually distinct rails: a landscape rail (16:9) and a portrait rail (2:3) stacked vertically.
2. The Cinematic Dual-Rail's landscape rail shall use the `Poster` atom in `landscape` orientation with `hideText: true` for each item.
3. The Cinematic Dual-Rail's portrait rail shall use the `Poster` atom in `portrait` orientation with `hideText: true` for each item.
4. The Cinematic Dual-Rail shall not modify `cinema_row.dart`, `cinema_card.dart`, `_card_poster.dart`, or `_grid_tokens.dart`.
5. The Cinematic Dual-Rail shall reuse existing data providers (`categoryNotifierProvider`, `moviesNotifierProvider`, equivalent IPTV-now-playing providers) without redefining their API.
6. The Cinematic Dual-Rail shall preserve adaptive `pickColumns 3/4/5` semantics — i.e., visible-card count derives from the same breakpoint logic as closed specs use, and the new rails do not hard-code a column count that contradicts `pickColumns`.

### Requirement 5: Section title with italic display em

**Objective:** Как пользователь, я хочу заголовки секций в формате «Сейчас в *эфире* · 12», где em-часть italic, и опциональная ссылка «more →» справа.

#### Acceptance Criteria

1. The Cinematic Section Title shall render via the `SectionTitle` atom from the atoms barrel.
2. The Cinematic Section Title shall accept a primary label string and an italic emphasis string segment, applying `MegaVTextStyles.displayMedium` (or palette equivalent) italic style to the emphasis segment.
3. While a `count` parameter is non-null and `>= 0`, the Cinematic Section Title shall append a counter pill / inline number using `MegaVTextStyles.metaMono`.
4. While an `onMoreTap` callback is non-null, the Cinematic Section Title shall expose a focusable «more →» action button on the trailing edge.
5. The Cinematic Section Title shall not use `BackdropFilter` / `ShaderMask` / shadow blur > `kSafeShadowBlurMax`.

### Requirement 6: Live эфир block with pulse Chip

**Objective:** Как пользователь IPTV, я хочу видеть отдельную «эфир» полосу с пульсирующим LIVE-индикатором, прогрессом текущей передачи, и названием — без ребилда parent на каждый тик прогресса.

#### Acceptance Criteria

1. The Cinematic Live Strip shall render a `Chip(variant: live)` whose pulse animation is wrapped in a `RepaintBoundary` (per atom Req 4.3).
2. The Cinematic Live Strip shall render a current programme progress bar via the `MvTrack` atom whose width animates without triggering relayout of siblings.
3. The Cinematic Live Strip shall not subscribe to `Stream` or `Provider` ticks inside its parent's `build`; any time-driven progress consumer shall live in a child `ConsumerWidget` / `StatefulWidget` wrapped in `RepaintBoundary` with a `const` parent constructor (per `flutter-tv-perf.md` Stream isolation rule).
4. The Cinematic Live Strip shall display the current programme title using `MegaVTextStyles.headline` and the next-up label via `MegaVTextStyles.metaMono`.
5. The Cinematic Live Strip shall not own clock-tick logic itself; current-time / progress values arrive via providers or constructor parameters.

### Requirement 7: Remote hint footer

**Objective:** Как новый пользователь, я хочу видеть нижнюю подсказку с keycap-pills (← → ↑ ↓ OK BACK) чтобы понять навигацию пультом без отдельного help-экрана.

#### Acceptance Criteria

1. The Cinematic Remote Hint Footer shall render the `RemoteHint` atom from the atoms barrel docked at the bottom edge of `CinematicHomeScreen`.
2. The Cinematic Remote Hint Footer shall not block focus traversal — it shall be `IgnorePointer` / `ExcludeFocus` for d-pad navigation.
3. The Cinematic Remote Hint Footer shall not redraw on focus changes elsewhere on the screen — its build subtree shall be `const` where possible and wrapped in `RepaintBoundary`.

### Requirement 8: Focus visuals via SafeFocusRing

**Objective:** Как пользователь TV-пульта, я хочу видеть чёткое focus-кольцо вокруг активного элемента без shadow-blur regression.

#### Acceptance Criteria

1. The Cinematic Home Module shall apply focus-ring visuals exclusively via the `SafeFocusRing` widget from `perf-safe-widgets`.
2. The Cinematic Home Module shall not introduce any `BoxShadow` with `blurRadius` greater than `kSafeShadowBlurMax` for any focusable element.
3. The Cinematic Home Module shall use `Transform.scale` (not `AnimatedContainer.width` / `AnimatedContainer.height`) for any focus-driven size emphasis on cards within new rails.
4. The focus animation duration on cinematic-only widgets shall be 150 ms (Leanback `lb_card_activated_animation_duration`).

### Requirement 9: Performance compliance with flutter-tv-perf.md

**Objective:** Как мейнтейнер, я хочу гарантию что новый экран не регрессит avg `GPURasterizer::Draw ≤ 16.7 ms` на rtd2851a и не вводит запрещённых GPU-операций.

#### Acceptance Criteria

1. The Cinematic Home Module shall not contain any usage of `BackdropFilter`, `ImageFilter.blur`, or `ShaderMask` in code paths reachable from `CinematicHomeScreen`.
2. The Cinematic Home Module shall not contain any `BoxShadow` literal whose `blurRadius` exceeds `kSafeShadowBlurMax` (`12.0`) in code paths reachable from `CinematicHomeScreen`.
3. The Cinematic Home Module shall not stack more than one full-screen `LinearGradient` over hero video; gradients are combined via `combinedHeroGradient(palette)`.
4. The Cinematic Home Module shall configure all horizontal `ListView` instances it creates with `cacheExtent: 1500`, `addAutomaticKeepAlives: true`, `addRepaintBoundaries: true`, and `clipBehavior: Clip.none` (per `flutter-tv-perf.md` defaults).
5. The Cinematic Home Module shall use focus-debounce of 400 ms for any heavy side-effect (preview player start, hero swap) (per Leanback `lb_card_selected_animation_delay`).
6. The Cinematic Home Module shall isolate any `StreamBuilder` / `ref.watch` of streaming state into a separate `ConsumerWidget` / `StatefulWidget` wrapped in `RepaintBoundary` with a `const` parent constructor.

### Requirement 10: Backward compatibility with closed specs

**Objective:** Как мейнтейнер, я хочу гарантию что закрытые специй `home-grid-optimization` + `home-grid-visual-polish` остаются работоспособными и нетронутыми.

#### Acceptance Criteria

1. The Cinematic Home Module shall not modify any file under `lib/features/home/widgets/` other than reading.
2. The Cinematic Home Module shall not modify `_grid_tokens.dart`, `cinema_row.dart`, `cinema_card.dart`, or `_card_poster.dart`.
3. The Cinematic Home Module shall not modify the `pickColumns(double screenW)` function signature, return values, or breakpoint thresholds.
4. The Cinematic Home Module shall not modify the existing fade-edge gradient overlay implementation in `cinema_row.dart`.
5. The Cinematic Home Module shall not modify `home_screen.dart` (legacy entry retained intact).
6. While the cinematic entry point is disabled, the application's behaviour shall be byte-for-byte identical to current `master`.

### Requirement 11: Feature-flag / dual-route rollout

**Objective:** Как мейнтейнер, я хочу безопасно выкатить cinematic redesign — с возможностью мгновенного отката на legacy экран без code revert.

#### Acceptance Criteria

1. The Cinematic Home Module shall be reachable via a deterministic switch — either a `go_router` route, a Riverpod-managed boolean flag (e.g., `useCinematicHomeProvider`), or a build-time const — chosen at design time.
2. While the switch is `false` / legacy route is selected, the existing `HomeScreen` shall render unmodified.
3. While the switch is `true` / cinematic route is selected, `CinematicHomeScreen` shall render and back-navigation shall behave consistently with `HomeScreen`'s back-navigation contract.
4. The default value of the switch shall be configurable in one place (single source of truth) so QA can flip it without modifying multiple files.

### Requirement 12: Test coverage and regression guard

**Objective:** Как мейнтейнер, я хочу обширное покрытие cinematic widgets + регрессионную защиту существующих тестов.

#### Acceptance Criteria

1. The Cinematic Home Module shall ship at least one widget-level test per new widget defined under Requirement 1 — Requirement 7 (≥7 widget tests).
2. The Cinematic Home Module shall ship at least one smoke-level test that pumps `CinematicHomeScreen` with mocked providers and asserts no exception is thrown for two frames.
3. The Cinematic Home Module shall ship one regression test asserting that `pickColumns(1280)`, `pickColumns(2560)`, `pickColumns(3840)` return their currently-documented values (3, 4, 5 respectively) — sourced from the closed `_grid_tokens.dart` API.
4. After all cinematic-spec tasks land, the full test suite (`flutter test`) shall report 94 / 94 tests passing (current baseline) plus all newly added cinematic tests.

### Requirement 13: Testability & observable hooks

**Objective:** Как мейнтейнер, я хочу чёткие точки наблюдения чтобы CI / kiro-review мог проверить compliance без ручного вмешательства.

#### Acceptance Criteria

1. The Cinematic Home Module shall expose stable `Key` identifiers (`Key('cinematic-hero')`, `Key('cinematic-genre-tabs')`, `Key('cinematic-dual-rail-landscape')`, `Key('cinematic-dual-rail-portrait')`, `Key('cinematic-live-strip')`, `Key('cinematic-remote-hint')`) on the corresponding root widgets so tests can locate them.
2. The Cinematic Home Module's static analysis shall be clean: `flutter analyze lib/features/home/cinematic/` reports zero issues.
3. The Cinematic Home Module shall be greppable by `BackdropFilter|ShaderMask|ImageFilter\.blur` returning zero hits in `lib/features/home/cinematic/` (verifiable by CI or by review checklist).
4. The Cinematic Home Module shall not require any new package in `pubspec.yaml`.
