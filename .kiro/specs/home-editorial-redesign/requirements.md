# Requirements Document — home-editorial-redesign

## Introduction

`home-editorial-redesign` — Wave 3 опциональный screen-spec, реализующий **Editorial B** вариант главного экрана (бенто-grid, газетная подача) **параллельно** с уже-сгенерированным `home-cinematic-redesign` (#5). User не сделал явного финального выбора между Cinematic A и Editorial B — оба варианта должны coexist как feature-flag-переключаемые альтернативы, чтобы дать пользователю / QA выбор и позволить A/B-тестирование без code-revert.

Эталон дизайна: `.kiro/design/megav-iptv-handoff/project/screens/home-editorial.jsx` (228 строк) — бенто 6-column grid из карточек разных размеров (1×1, 1×2, 2×1, 2×2), портретный 420×620 hero-poster слева + meta-колонка справа, italic display masthead «Главная *сегодня* · 9 МАЯ 2026 · ВЫПУСК №127», film-reel strip каналов внизу.

Ключевая боковая constraint — **не трогать** `home-cinematic-redesign` (#5) и его директорию `lib/features/home/cinematic/`. Editorial живёт в **новой** директории `lib/features/home/editorial/`. Cinematic и Editorial делят общие foundation-блоки (#4, #13, #14) и data-providers, но **никаких общих файлов** в `home/` (кроме одной точки переключения — provider-flag или go_router route).

Foundation deps (все закрыты + GO):
- `design-system-foundation` (#4) — `AppPalette`, `AppRadius`, `AppColors` proxy, `MegaVTextStyles`, `themeProvider`.
- `perf-safe-widgets` (#13) — `SafePill`, `SafeFocusRing`, `SafeFilmGrain`, `SafeBackdrop`, `combinedHeroGradient`, `ComputedColors`, `kSafeShadowBlurMax`, `assets/grain_overlay.png`.
- `design-system-atoms` (#14) — 13 atoms через barrel `package:megav_iptv/core/ui/atoms/atoms.dart`. В частности Editorial интенсивно использует `Poster` (portrait+landscape), `MvStrip` (film-reel), `Brand` (увеличенный), `SectionTitle` (italic display em), `Chip` (live/brand/gold), `MvButton`, `MvTrack`, `GenreTabs`, `RemoteHint`, `StatusBar`, `MMLogo`.

Sibling dep:
- `home-cinematic-redesign` (#5) — sibling spec; **read-only** для Editorial. Editorial не импортирует `lib/features/home/cinematic/*`. Точка переключения между Cinematic и Editorial — общий enum-flag и одна модификация router/main файла, без trogания cinematic-кода.

Целевое устройство неизменно: Realtek `rtd2851a` Android TV-бокс. Performance budget из `flutter-tv-perf.md` соблюдается жёстко (Req 9), несмотря на то что бенто-grid вводит больше одновременно-видимых poster-decode'ов чем один cinematic rail.

См. `brief.md`, GH issue #6, `.kiro/design/megav-iptv-handoff/project/screens/home-editorial.jsx`, `.kiro/steering/roadmap.md`, и `.kiro/steering/flutter-tv-perf.md` для design / perf source-of-truth.

## Boundary Context

- **In scope** (NEW в `lib/features/home/editorial/`):
  - `EditorialHomeScreen` — Riverpod-aware top-level widget, новая Editorial B раскладка, gated через тот же source-of-truth flag что cinematic (Req 6).
  - `editorial_masthead.dart` — газетный масthead «Главная *сегодня* · 9 МАЯ 2026 · ВЫПУСК №NNN» с italic display + mono date-line + bottom hairline border.
  - `editorial_hero_section.dart` — hero-row из портретного 420×620 `Poster` (portrait, hideText) + meta-колонки (chips, italic display title, mono meta, summary, MvTrack, action buttons, две `EditorialSideCard`).
  - `editorial_side_card.dart` — компактная side-card 1/2-grid: thumbnail Poster 84×112 + label (mono) + italic title + remaining-time mono.
  - `editorial_bento_grid.dart` — `CustomMultiChildLayout` или `Wrap`/`GridView`-based 6-column bento с поддержкой `cols×rows` ячеек 1×1, 1×2, 2×1, 2×2.
  - `editorial_bento_card.dart` — карточка bento-сетки: фон-Poster + bottom-gradient + italic display title (size зависит от cols/rows) + chip(live)/mono meta.
  - `editorial_film_reel_strip.dart` — низ экрана: 18 рамок 16:9 через атом `MvStrip` + mono caption «КАНАЛЫ ↓» + counter «05 / 124» mono.
  - `editorial_section_title.dart` — обёртка над atom `SectionTitle` для italic em fragment + count.
  - `editorial_genre_tabs_bar.dart` — top-bar `GenreTabs` под masthead с edge-fade overlay (DecoratedBox-only).
  - `editorial_brand_header.dart` — увеличенный `Brand` атом (visual emphasis editorial-styling).
  - Widget tests (≥1 на каждый новый widget) + smoke test всего экрана.
  - Один **общий** `home_variant_provider.dart` (или эквивалент), описывающий enum `HomeVariant { cinematic, editorial }` и Riverpod state-provider — единая точка координации между Cinematic и Editorial. Этот файл живёт в `lib/features/home/` (не внутри cinematic/ или editorial/) — это единственный «общий» файл, который Editorial spec создаёт, и он не пересекается с уже-существующими файлами home-cinematic-redesign (это новый файл, отдельный от `use_cinematic_home_provider.dart`).

- **In scope** (BACKWARD-COMPAT TOUCH, NOT MODIFYING closed widgets):
  - Один-line добавление route entry `/home-editorial` в router-файл (Option B preferred per cinematic precedent), либо ONE-LINE расширение entry-switch который уже добавил cinematic-spec, чтобы он понимал три состояния: legacy / cinematic / editorial. Implementer выбирает один из двух подходов в task 1.2 и документирует решение в commit message.

- **Out of scope** (HARD prohibition):
  - Любые модификации `lib/features/home/cinematic/*` — owned by `home-cinematic-redesign` (#5).
  - Любые модификации `cinema_row.dart`, `cinema_card.dart`, `_card_poster.dart`, `_grid_tokens.dart` — owned by closed `home-grid-optimization` + `home-grid-visual-polish`.
  - Любые модификации `pickColumns 3/4/5` логики — closed.
  - Cinematic A layout (#5) — отдельный спек; Editorial не дублирует hero-cinematic, dual-rail, live-strip widgets.
  - Mobile layout (#12) — отдельный спек.
  - Detail / Player / EPG / Search / Settings — отдельные специй.
  - Backend / data layer (`lib/core/api/*`, `lib/core/playlist/*`, `lib/core/epg/*`) — read-only кроме reuse существующих providers.
  - Native player engines (`lib/core/player/*`) — read-only.
  - Sealed `PlayerUiState` (#8) — отдельный спек.
  - Возврат `BoxShadow.blurRadius=50`, `ShaderMask`, `BackdropFilter` — запрещено `flutter-tv-perf.md`.
  - Добавление `cached_network_image` или иных пакетов в `pubspec.yaml` — out of scope (потенциально откладывается в отдельный спек если perf-budget затронут).

- **Adjacent expectations**:
  - Closed kiro specs продолжают компилироваться без изменений: `cinema_row.dart`, `cinema_card.dart`, `_grid_tokens.dart`, `_card_poster.dart`.
  - `home-cinematic-redesign` (#5) продолжает работать unchanged: его файлы только читаются (на уровне типа-импортов где нужно — ничего не модифицируется).
  - `design-system-foundation` (#4): theme tokens читаются через `Theme.of(context)` и `AppColors.X`.
  - `perf-safe-widgets` (#13): все «glassy» / blur-эффекты композируются из `SafeBackdrop` + `SafeFilmGrain` + `SafePill` + `SafeFocusRing` + `combinedHeroGradient`.
  - `design-system-atoms` (#14): импорт через barrel `package:megav_iptv/core/ui/atoms/atoms.dart`.
  - Все существующие тесты (94 baseline + N добавленные cinematic-spec'ом) продолжают проходить unchanged (Req 11.1, 12.4).
  - `flutter-tv-perf.md` правила обязательны (Req 9).

## Requirements

### Requirement 1: Editorial Home screen scaffold + entry

**Objective:** Как пользователь TV-бокса, я хочу опциональную «Editorial B» раскладку главного экрана, которая выглядит как газетный бенто-разворот, и при этом не ломает legacy и не конфликтует с Cinematic A.

#### Acceptance Criteria

1. The Editorial Home Module shall provide a public `EditorialHomeScreen` widget located at `lib/features/home/editorial/editorial_home_screen.dart`.
2. The Editorial Home Module shall expose `EditorialHomeScreen` via either a new `go_router` route entry `/home-editorial` or a Riverpod-gated builder, leaving the existing `HomeScreen` route registered and reachable AND leaving the `CinematicHomeScreen` route from `home-cinematic-redesign` untouched.
3. While the editorial entry point is selected, the application shall mount `EditorialHomeScreen` as the root home content without modifying `home_screen.dart` or any file under `lib/features/home/cinematic/`.
4. While the cinematic or legacy entry point is selected, the application shall mount the corresponding screen unchanged.
5. The Editorial Home Module shall not place any new files inside `lib/features/home/widgets/` (closed-spec ownership) or `lib/features/home/cinematic/` (sibling spec ownership) — all new files live under `lib/features/home/editorial/` (plus exactly one shared variant provider at `lib/features/home/home_variant_provider.dart`).

### Requirement 2: Editorial masthead

**Objective:** Как пользователь, я хочу видеть газетный заголовок-«масштхэд» с italic display title «Главная *сегодня*», моно-датой и моно-номером выпуска, разделённый тонкой hairline-линией — для чёткого editorial-tone.

#### Acceptance Criteria

1. The Editorial Masthead shall render an italic display title composed of a base label (e.g., «Главная») and an italic em fragment (e.g., «сегодня») using `Theme.of(context).megavText.displayLarge` (or palette equivalent) with `fontStyle: FontStyle.italic` applied to the em segment.
2. The Editorial Masthead shall render a monospace meta-line with current date and issue number using `MegaVTextStyles.metaMono`, formatted as `«D MMMM YYYY · ВЫПУСК №NNN»` in Russian locale.
3. The Editorial Masthead shall draw a single 1-px hairline separator at its bottom edge using a `Container(decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))))` — no `BoxShadow`, no `BackdropFilter`.
4. The Editorial Masthead shall not use `BackdropFilter`, `ShaderMask`, or `BoxShadow.blurRadius > kSafeShadowBlurMax` anywhere in its build tree.
5. The Editorial Masthead's date and issue-number values shall be supplied as constructor parameters (or read from a provider) — the widget itself shall not own clock-tick logic.

### Requirement 3: Hero row — portrait poster + meta column + side cards

**Objective:** Как пользователь, я хочу editorial hero-блок с большим портретным постером 420×620 слева и meta-колонкой (chips, italic display title, mono summary, action row, две side-cards) справа — выразительный газетный layout без тяжёлых GPU-эффектов.

#### Acceptance Criteria

1. The Editorial Hero Section shall render a 2-column layout with `auto` (poster) and `1fr` (meta) widths, using a `Row` of `[Poster(portrait, w=420, h=620, hideText: true), Expanded(meta column)]`.
2. The Editorial Hero Section's portrait poster shall use the `Poster` atom in `portrait` orientation with `hideText: true`, wrapped in a `SafeFocusRing` for d-pad selection.
3. The Editorial Hero Section's meta column shall include, top-to-bottom: a chip-row (`Chip(variant: live)`, `Chip(variant: brand)` with `MMLogo`, `Chip(variant: gold)`), an italic display title via `MegaVTextStyles.displayLarge` (italic, `fontSize` ≈ 84 sp), a monospace meta-line (rating + year + genre + duration), a summary paragraph using `MegaVTextStyles.body` capped at `maxWidth ≈ 540`, an `MvTrack` progress bar with mono ticks, an action row (`MvButton.primary('Смотреть')` + 2× `MvButton.ghost`), and a 2-column row of `EditorialSideCard` instances.
4. The Editorial Hero Section shall apply title text-shadow capped at `kSafeShadowBlurMax` (`12.0`) — never higher.
5. The Editorial Hero Section shall not use `BackdropFilter`, `ShaderMask`, or `BoxShadow.blurRadius > kSafeShadowBlurMax` anywhere in its build tree.
6. The Editorial Hero Section shall expose a primary action (`MvButton.primary`) with focusable `FocusNode` that initially receives focus on mount.
7. The Editorial Hero Section shall render an optional decorative «EDITORS' PICK · NN» rotated badge using a static `Transform.rotate` + `Container` with palette gold background — no animated rotation, no blur.

### Requirement 4: Editorial side card

**Objective:** Как пользователь, я хочу компактную side-card (84×112 thumbnail + meta) для «Далее в эфире» / «Рекомендуем» рядом с hero — без BackdropFilter glassy эффекта, но с palette-tinted surface.

#### Acceptance Criteria

1. The Editorial Side Card shall render as a horizontal row `[Poster(portrait, w=84, h=112, hideText: true), Expanded(text column)]` with `padding: EdgeInsets.all(14)` and `borderRadius: AppRadius.md`.
2. The Editorial Side Card's surface shall use a flat semi-opaque palette colour (e.g., `palette.surface2.withOpacity(0.55)`) plus a 1-px `Border.all(color: palette.line)` — no `BackdropFilter` and no real-time blur.
3. The Editorial Side Card shall render text in three rows: an uppercase mono label (`metaMono`), an italic display short title (`displayMedium` or palette small italic), and a mono `remaining` line (e.g., «через 55 мин»).
4. The Editorial Side Card shall not use `BackdropFilter`, `ShaderMask`, or `BoxShadow.blurRadius > kSafeShadowBlurMax`.
5. The Editorial Side Card shall be focusable as a single unit (a `Focus` wrapper around the row) with `SafeFocusRing` applied on focus.

### Requirement 5: Editorial bento grid

**Objective:** Как пользователь, я хочу плотную газетную бенто-сетку из карточек разных размеров (1×1, 1×2, 2×1, 2×2) на 6-колоночной разметке — выразительный, плотный editorial-каталог без перерасхода GPU.

#### Acceptance Criteria

1. The Editorial Bento Grid shall accept a list of cells, each declaring `cols: int` (1..6) and `rows: int` (1..4).
2. The Editorial Bento Grid shall lay out cells across a 6-column grid with row-height ≈ 220 lp using a `CustomMultiChildLayout` / `StaggeredGrid` / equivalent layout primitive — implementer chooses but result must respect `cols×rows` spans.
3. The Editorial Bento Grid's gap between cells shall be 16 lp horizontally and vertically.
4. The Editorial Bento Grid shall delegate card rendering to `EditorialBentoCard`; the grid widget itself shall not render content beyond layout.
5. The Editorial Bento Grid shall not use `BackdropFilter`, `ShaderMask`, or `BoxShadow.blurRadius > kSafeShadowBlurMax`.
6. The Editorial Bento Grid shall scroll vertically as part of the parent scroll view; it shall not own its own scrollable.

### Requirement 6: Editorial bento card

**Objective:** Как пользователь, я хочу bento-карточку с poster-фоном, нижним gradient-overlay, italic display title (размер зависит от cols/rows), опциональным `Chip(live)` и mono-meta — без BackdropFilter и в пределах perf-budget.

#### Acceptance Criteria

1. The Editorial Bento Card shall render as `Stack(children: [Positioned.fill(Poster(image=...)), Positioned.fill(DecoratedBox(linear-gradient bottom)), Positioned(top:12,left:12,Chip(live)), Positioned(left:16,right:16,bottom:14,Column(title+mono))])`.
2. The Editorial Bento Card's title font size shall be 36 sp when `cols >= 2 && rows >= 2`, else 20 sp — mapped to `displayMedium` and `displaySmall` palette styles respectively.
3. The Editorial Bento Card shall apply a single `LinearGradient(begin: topCenter, end: bottomCenter, colors: [Color(0x0D000000), Color(0xD9000000)])` overlay — never two stacked gradients (per Req 9.3).
4. The Editorial Bento Card's focus state shall add a `SafeFocusRing` and a `BoxShadow(blurRadius: kSafeShadowBlurMax, color: palette.accentGlow)` — NEVER `blurRadius > 12`.
5. The Editorial Bento Card shall use `Transform.scale(focused ? 1.04 : 1.0)` for focus emphasis — no `AnimatedContainer.width`/`height`.
6. The Editorial Bento Card shall not use `BackdropFilter`, `ShaderMask`, or `BoxShadow.blurRadius > kSafeShadowBlurMax`.
7. The Editorial Bento Card's image source shall route through the same poster-image plumbing used by closed widgets (no new image-decode pathway introduced by this spec).

### Requirement 7: Film-reel strip header

**Objective:** Как пользователь IPTV, я хочу декоративный film-reel strip 18 рамок 16:9 в нижней части editorial экрана — отсылка к плёнке, через атом `MvStrip` без BackdropFilter и без runtime-blur.

#### Acceptance Criteria

1. The Editorial Film-Reel Strip shall render the `MvStrip` atom from the atoms barrel with frame count ≈ 18 (configurable parameter).
2. The Editorial Film-Reel Strip shall display a leading mono label «КАНАЛЫ ↓» using `MegaVTextStyles.metaMono`.
3. The Editorial Film-Reel Strip shall display a trailing mono counter «NN / NNN» (e.g., «05 / 124») using `MegaVTextStyles.metaMono`.
4. The Editorial Film-Reel Strip shall not use `BackdropFilter`, `ShaderMask`, or `BoxShadow.blurRadius > kSafeShadowBlurMax`.
5. The Editorial Film-Reel Strip shall not own scroll-tick / animation logic itself; any animated frame highlight lives inside the `MvStrip` atom (closed by #14).

### Requirement 8: Editorial-styled section title and genre tabs

**Objective:** Как пользователь, я хочу editorial-tone заголовки секций «Кино *без расписания* · 30» (italic em + count) и горизонтальную полосу жанров под masthead с edge-fade — для consistent editorial-typography через экран.

#### Acceptance Criteria

1. The Editorial Section Title shall render via the `SectionTitle` atom from the atoms barrel with primary label and italic emphasis fragment, applying `MegaVTextStyles.displayMedium` italic to the em segment.
2. The Editorial Section Title shall append an inline count using `MegaVTextStyles.metaMono` when `count != null && count >= 0`.
3. The Editorial Section Title shall expose an optional «more →» trailing action when `onMoreTap != null`.
4. The Editorial Genre Tabs Bar shall render the `GenreTabs` atom with edge-fade `DecoratedBox` + `LinearGradient` overlays at left and right ends — never `ShaderMask` (per `flutter-tv-perf.md`).
5. The Editorial Section Title and Genre Tabs Bar shall not use `BackdropFilter`, `ShaderMask`, or `BoxShadow.blurRadius > kSafeShadowBlurMax`.

### Requirement 9: Performance compliance with flutter-tv-perf.md

**Objective:** Как мейнтейнер, я хочу гарантию что editorial экран — несмотря на бенто-grid с большим количеством одновременно-видимых poster-decode'ов — не регрессит avg `GPURasterizer::Draw ≤ 16.7 ms` на rtd2851a.

#### Acceptance Criteria

1. The Editorial Home Module shall not contain any usage of `BackdropFilter`, `ImageFilter.blur`, or `ShaderMask` in code paths reachable from `EditorialHomeScreen`.
2. The Editorial Home Module shall not contain any `BoxShadow` literal whose `blurRadius` exceeds `kSafeShadowBlurMax` (`12.0`) in code paths reachable from `EditorialHomeScreen`.
3. The Editorial Home Module shall not stack more than one full-screen `LinearGradient` over hero or bento-card backgrounds.
4. The Editorial Home Module shall configure all horizontal `ListView` instances it creates with `cacheExtent: 1500`, `addAutomaticKeepAlives: true`, `addRepaintBoundaries: true`, and `clipBehavior: Clip.none`.
5. The Editorial Home Module shall use focus-debounce of 400 ms for any heavy side-effect (preview player start, hero swap) on bento-card focus changes.
6. The Editorial Home Module shall isolate any `StreamBuilder` / `ref.watch` of streaming state into a separate `ConsumerWidget` / `StatefulWidget` wrapped in `RepaintBoundary` with a `const` parent constructor.
7. The Editorial Bento Grid shall cap simultaneously-visible bento cards at ≤ 12 within the initial viewport (i.e., the demo bento layout with 8 cards lives inside one viewport; subsequent groups arrive lazily as user scrolls).
8. Each bento card's image-decode shall happen at most once per item per session (image cache reuse) — implementer relies on existing image-cache layer; this spec does not introduce a new decoder.

### Requirement 10: Backward compatibility with closed and sibling specs

**Objective:** Как мейнтейнер, я хочу гарантию что закрытые специй `home-grid-optimization` + `home-grid-visual-polish` + sibling-spec `home-cinematic-redesign` остаются работоспособными и нетронутыми.

#### Acceptance Criteria

1. The Editorial Home Module shall not modify any file under `lib/features/home/widgets/` other than reading.
2. The Editorial Home Module shall not modify any file under `lib/features/home/cinematic/` other than reading.
3. The Editorial Home Module shall not modify `_grid_tokens.dart`, `cinema_row.dart`, `cinema_card.dart`, or `_card_poster.dart`.
4. The Editorial Home Module shall not modify the `pickColumns(double screenW)` function signature, return values, or breakpoint thresholds.
5. The Editorial Home Module shall not modify `home_screen.dart` (legacy entry retained intact).
6. While the editorial entry point is disabled, the application's behaviour shall be byte-for-byte identical to the post-cinematic-spec `master`.
7. The Editorial Home Module shall not modify `pubspec.yaml`.

### Requirement 11: Coexistence with cinematic variant via shared flag

**Objective:** Как пользователь / QA, я хочу выбирать между Cinematic A и Editorial B вариантами главного экрана через один централизованный flag, и при этом мой выбор сохраняется per-user между сессиями.

#### Acceptance Criteria

1. The Editorial Home Module and the Cinematic Home Module shall coexist as two independent feature-flagged variants of the home screen, switchable via a single shared configuration flag without code revert.
2. The Editorial Home Module shall introduce (or extend, if already present) a single shared file `lib/features/home/home_variant_provider.dart` that defines an enum `HomeVariant { cinematic, editorial }` (and optionally `legacy`) and exposes a Riverpod `StateProvider<HomeVariant> homeVariantProvider` plus a `const HomeVariant kHomeVariantDefault = HomeVariant.cinematic;` constant as the single source of truth.
3. While `homeVariantProvider` evaluates to `HomeVariant.editorial`, the application shall mount `EditorialHomeScreen` as the root home content.
4. While `homeVariantProvider` evaluates to `HomeVariant.cinematic`, the application shall mount `CinematicHomeScreen` (from `home-cinematic-redesign`) unchanged.
5. The selection persists per-user: the chosen `HomeVariant` shall be persisted to the same local-storage layer already used by Settings (or, if no such layer is available, this spec persists via a `SharedPreferences`-backed `StateNotifier` which writes on change and reads on app start).
6. The default value of the flag shall be configurable in exactly one place (`kHomeVariantDefault`) so QA can flip it without modifying multiple files.
7. The shared flag file shall be the only «common» file this spec creates outside the `lib/features/home/editorial/` directory; it shall not modify `lib/features/home/cinematic/use_cinematic_home_provider.dart` (the cinematic-spec's flag remains its own concern but, if both flags exist, `homeVariantProvider` is the authoritative coordinator and `useCinematicHomeProvider` becomes a derived view — implementer reconciles in design / task without breaking either spec's tests).

### Requirement 12: Test coverage and regression guard

**Objective:** Как мейнтейнер, я хочу обширное покрытие editorial widgets + регрессионную защиту существующих тестов и cinematic-spec тестов.

#### Acceptance Criteria

1. The Editorial Home Module shall ship at least one widget-level test per new widget defined under Requirement 1 — Requirement 8 (≥10 widget tests).
2. The Editorial Home Module shall ship at least one smoke-level test that pumps `EditorialHomeScreen` with mocked providers and asserts no exception is thrown for two frames.
3. The Editorial Home Module shall ship one regression test asserting that `pickColumns(1280)`, `pickColumns(2560)`, `pickColumns(3840)` return `3 / 4 / 5` respectively (sourced from closed `_grid_tokens.dart`).
4. The Editorial Home Module shall ship one coexistence test asserting that `homeVariantProvider` set to `HomeVariant.cinematic` results in `CinematicHomeScreen` being mounted (presence of `Key('cinematic-home-root')`) and `HomeVariant.editorial` results in `EditorialHomeScreen` being mounted (presence of `Key('editorial-home-root')`).
5. After all editorial-spec tasks land, the full test suite (`flutter test`) shall report all previously-green tests still passing (94 baseline + cinematic-spec additions + new editorial tests).

### Requirement 13: Testability & observable hooks

**Objective:** Как мейнтейнер, я хочу чёткие точки наблюдения чтобы CI / kiro-review мог проверить compliance без ручного вмешательства.

#### Acceptance Criteria

1. The Editorial Home Module shall expose stable `Key` identifiers on root widgets: `Key('editorial-home-root')`, `Key('editorial-masthead')`, `Key('editorial-hero')`, `Key('editorial-side-card-${slot}')` (e.g., `next`/`featured`), `Key('editorial-bento-grid')`, `Key('editorial-bento-card-${index}')`, `Key('editorial-film-reel-strip')`, `Key('editorial-genre-tabs')`, `Key('editorial-brand-header')`, `Key('editorial-section-title-${label}')`.
2. The Editorial Home Module's static analysis shall be clean: `flutter analyze lib/features/home/editorial/` reports zero issues.
3. The Editorial Home Module shall be greppable by `BackdropFilter|ShaderMask|ImageFilter\.blur` returning zero hits in `lib/features/home/editorial/` and in the new shared file `lib/features/home/home_variant_provider.dart` (verifiable by CI or by review checklist).
4. The Editorial Home Module shall not require any new package in `pubspec.yaml`.
5. The Editorial Home Module shall be greppable by `blurRadius:\s*([2-9][0-9]+|1[3-9])` returning zero hits in `lib/features/home/editorial/`.
