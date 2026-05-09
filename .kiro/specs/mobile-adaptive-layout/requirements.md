# Requirements Document — mobile-adaptive-layout

## Introduction

`mobile-adaptive-layout` — Wave 3 финальный, lower-priority спек. Цель — добавить компактные mobile-варианты трёх свежедизайненных TV-экранов (`home-cinematic-redesign` #5, `detail-screen-fullbleed` #7, `player-cinematic-redesign` #8) плюс bottom tabbar для навигации, **не трогая TV widget trees**. Mobile и TV сосуществуют через breakpoint switch на входе в каждый адаптивный screen.

User в chat: «И то и другое (адаптив)» — явно хочет обе платформы. TV — основной приоритет, mobile — дополнение поверх готовых TV-флоу.

Ключевые отличия mobile-флоу от TV:
- **Single-column scroll** (вместо TV-сетки `pickColumns 3/4/5`).
- **Full-screen sheet style** для detail (вместо TV full-bleed hero).
- **Vertical-первый плеер** с bottom controls overlay и horizontal swipe для канал-switching.
- **Glass-blur bottom tabbar** с 5 tabs (Home / TV / Search / Guide / Profile) — floating, всегда видимый поверх content.

**Mobile-specific perf relaxation (Req 11)**: на мобильных GPU `BackdropFilter` и подобные TV-запрещённые операции **разрешены**. Это **единственный** спек, которому позволено использовать raw blur — все TV-target специй (#5/#7/#8) продолжают соблюдать `flutter-tv-perf.md`. Граница строго локализована: blur допустим **только** в файлах под `lib/features/<screen>/mobile/` и `lib/features/mobile/`.

Foundation deps (все закрыты + GO):
- `design-system-foundation` (#4) — `AppPalette`, `AppRadius`, `AppColors` proxy, `MegaVTextStyles`, `themeProvider`.
- `perf-safe-widgets` (#13) — `SafePill`, `SafeFocusRing`, `SafeFilmGrain`, `SafeBackdrop`, `combinedHeroGradient`, `ComputedColors`, `kSafeShadowBlurMax`. Mobile может **дополнительно** использовать raw `BackdropFilter` (NOT через SafeBackdrop) когда нужен real-time blur.
- `design-system-atoms` (#14) — 13 atoms через barrel `package:megav_iptv/core/ui/atoms/atoms.dart`.

Wave 3 deps (just-generated, ready_for_implementation = true):
- `home-cinematic-redesign` (#5) — TV home screen, не модифицируется.
- `detail-screen-fullbleed` (#7) — TV detail screen, не модифицируется.
- `player-cinematic-redesign` (#8) — TV player screen, не модифицируется.

См. `brief.md`, GH issue #12, `.kiro/design/megav-iptv-handoff/project/screens/mobile-v2.jsx` (~700 строк, 3 mobile artboards), `.kiro/steering/roadmap.md`, и `.kiro/steering/flutter-tv-perf.md` (TV-only — mobile путь освобождён).

## Boundary Context

- **In scope** (NEW directories):
  - `lib/core/layout/screen_kind.dart` (NEW) — `enum ScreenKind { mobile, tablet, tv }` + `screenKindOf(BuildContext)` + Riverpod `screenKindProvider` derived from `MediaQuery.sizeOf(context).width`. Breakpoints: `< 600` mobile, `< 1280` tablet, `>= 1280` tv.
  - `lib/core/layout/adaptive_scaffold.dart` (NEW) — `AdaptiveScaffold` widget which selects mobile vs TV child via `ScreenKind`. Per-screen entry uses this scaffold (not a router replacement).
  - `lib/features/home/mobile/home_mobile_screen.dart` (NEW) — single-column mobile home (vertical stacked rails, hero card, status-bar reservation).
  - `lib/features/home/mobile/widgets/m_top_bar.dart` (NEW) — top bar with city / temp / time + brand mark.
  - `lib/features/home/mobile/widgets/m_hero_card.dart` (NEW) — 380-px portrait hero card + paginator dots.
  - `lib/features/home/mobile/widgets/m_stacked_rail.dart` (NEW) — vertical-scroll single-column rail (replaces TV horizontal rail on mobile).
  - `lib/features/detail/mobile/detail_mobile_screen.dart` (NEW) — full-screen sheet style detail (poster top → meta → actions → description), 16-22-px fonts.
  - `lib/features/player/mobile/player_mobile_screen.dart` (NEW) — separate widget tree from TV player, vertical-first, bottom controls overlay, horizontal swipe → channel switch.
  - `lib/features/player/mobile/widgets/m_player_controls.dart` (NEW) — bottom-anchored controls (play/pause, channel up/down, volume).
  - `lib/features/player/mobile/widgets/m_swipe_hint.dart` (NEW) — «SWIPE ↔ КАНАЛ» hint overlay with pulse animation.
  - `lib/features/mobile/widgets/m_tab_bar.dart` (NEW) — floating glass bottom tabbar (5 tabs: Home / TV / Search / Guide / Profile). May use raw `BackdropFilter(blur 28px)`.
  - `lib/features/mobile/widgets/m_icon_btn.dart` (NEW) — mobile-styled icon button atom.
  - `lib/features/mobile/widgets/m_live_dot.dart` (NEW) — pulsing live dot with `RepaintBoundary` wrapping.
  - Widget tests + smoke tests + breakpoint switch tests under `test/core/layout/` and `test/features/<screen>/mobile/`.

- **In scope** (BACKWARD-COMPAT TOUCH — minimal, ONE-LINE per file):
  - For each of 3 adaptive screens (home, detail, player), the existing TV screen entry file gets a one-line wrap into `AdaptiveScaffold(mobile: ..., tv: ...)`. The TV widget tree is identical, only the entry point dispatches by breakpoint. Mounting points:
    - `lib/features/home/cinematic/cinematic_home_screen.dart` → ONE-LINE wrap OR new `lib/features/home/home_root.dart` carrying the switch (implementer chooses; both keep TV tree untouched).
    - `lib/features/detail/<root entry>.dart` → same pattern.
    - `lib/features/player/<root entry>.dart` → same pattern.
  - Alternative (preferred): introduce `lib/features/<screen>/<screen>_root.dart` that owns the breakpoint switch and is registered in `app_router.dart` instead of the TV widget directly. TV file gets ZERO modifications.

- **Out of scope** (HARD prohibition):
  - Любые модификации виджетов TV cinematic / detail-fullbleed / player-cinematic — `lib/features/home/cinematic/*` (except possibly the root entry one-line wrap, see above), `lib/features/detail/*` (TV trees), `lib/features/player/*` (TV trees) — read-only.
  - Foundation specs `lib/core/theme/*`, `lib/core/perf/*`, `lib/core/ui/atoms/*` — read-only.
  - Closed specs (`cinema_row.dart`, `cinema_card.dart`, `_grid_tokens.dart`, `_card_poster.dart`, sealed `PlayerUiState`) — read-only.
  - iOS / macOS-specific features (haptics, share-sheet integration, native widgets) — out of project scope per roadmap.
  - Apple TV / tvOS — not a Flutter target in this repo.
  - Backend / data layer (`lib/core/api/*`, `lib/core/playlist/*`, `lib/core/epg/*`) — read-only.
  - Native player engines (`lib/core/player/*`) — read-only.

- **Adjacent expectations**:
  - 94+ existing tests pass unchanged — including TV cinematic / detail / player redesign tests added by #5/#7/#8.
  - Atoms (#14) reused as-is — mobile widgets compose them, do not extend.
  - `AppPalette`, `MegaVTextStyles` (#4) reused.
  - `flutter-tv-perf.md` rules apply ONLY to non-mobile code paths. Mobile path is free to use `BackdropFilter`, raw blur, larger shadow blur within reason. The boundary is enforced by directory-scoped grep (Req 11.4).

## Requirements

### Requirement 1: Breakpoint detector — `ScreenKind` + `AdaptiveScaffold`

**Objective:** Как пользователь, я хочу чтобы приложение автоматически выбирало mobile или TV layout в зависимости от ширины экрана, без явного toggle и без флага.

#### Acceptance Criteria

1. The Mobile Adaptive Module shall provide a public `ScreenKind` enum with values `mobile`, `tablet`, `tv` located at `lib/core/layout/screen_kind.dart`.
2. The Mobile Adaptive Module shall provide a public function `ScreenKind screenKindOf(BuildContext context)` that returns `mobile` for `MediaQuery.sizeOf(context).width < 600`, `tablet` for `< 1280`, and `tv` for `>= 1280`.
3. The Mobile Adaptive Module shall expose a Riverpod `screenKindProvider` derivable from a synthetic `MediaQueryData` source (e.g., `Provider.autoDispose` reading via a helper) so non-widget code can read current screen kind in tests.
4. The Mobile Adaptive Module shall provide an `AdaptiveScaffold` widget at `lib/core/layout/adaptive_scaffold.dart` whose `build` returns the `mobile` child when `screenKindOf(context) == ScreenKind.mobile`, otherwise the `tv` child. `tablet` shall fall through to `tv` by default unless an explicit `tablet` builder is passed.
5. The Mobile Adaptive Module shall NOT introduce any global state that overrides MediaQuery — switching is purely a function of current screen size at build time.
6. The Mobile Adaptive Module shall not modify `MediaQuery`, `WidgetsBinding.instance.window`, or any platform-channel.

### Requirement 2: Home mobile variant — single-column scroll

**Objective:** Как пользователь телефона, я хочу видеть главный экран в виде вертикального скролла с одной колонкой, hero-карточкой и stacked rails — без TV-сетки `3/4/5 columns`.

#### Acceptance Criteria

1. The Mobile Home shall provide a public `HomeMobileScreen` widget at `lib/features/home/mobile/home_mobile_screen.dart`.
2. The Mobile Home shall render a top bar (`MTopBar`) with city / temperature / time on the left and brand mark on the right at the top.
3. The Mobile Home shall reserve `MediaQuery.viewPaddingOf(context).top` (status-bar) above the top bar.
4. The Mobile Home shall render a portrait hero card via `MHeroCard` (~380-px tall) with paginator dots below.
5. The Mobile Home shall render N stacked vertical rails (`MStackedRail`) — single-column scroll, each rail labelled by section title, items shown one-per-row or 2-per-row maximum.
6. The Mobile Home shall NOT use horizontal `CinemaRow` / `pickColumns 3/4/5` logic — those are TV-only.
7. The Mobile Home shall reuse data providers (`categoryNotifierProvider`, `moviesNotifierProvider`, IPTV-now-playing providers) without redefining their API.
8. The Mobile Home shall NOT modify any file under `lib/features/home/cinematic/`, `lib/features/home/widgets/`, or `lib/features/home/home_screen.dart`.
9. The Mobile Home shall mount root `Key('home-mobile-root')`.

### Requirement 3: Detail mobile variant — full-screen sheet style

**Objective:** Как пользователь телефона, я хочу видеть detail-экран как полноэкранный sheet — poster сверху, мета-блок, action row, описание — компактно с 16-22-px шрифтами вместо TV 32-96-px.

#### Acceptance Criteria

1. The Mobile Detail shall provide a public `DetailMobileScreen` widget at `lib/features/detail/mobile/detail_mobile_screen.dart`.
2. The Mobile Detail shall render a single-column layout: poster (top, full-width) → title → meta-row (year, duration, rating) → action row (`Play` + `Add` + `Share`) → description.
3. The Mobile Detail shall use `MegaVTextStyles` scaled-down variants for title (≤ 22 px), body (16 px), meta (14 px monospace).
4. The Mobile Detail shall render a back-arrow button at top-left for sheet dismissal.
5. The Mobile Detail shall NOT modify any file under `lib/features/detail/` outside `lib/features/detail/mobile/`.
6. The Mobile Detail shall reuse the same `Movie` / `Channel` model as the TV detail screen.
7. The Mobile Detail shall mount root `Key('detail-mobile-root')`.

### Requirement 4: Player mobile variant — vertical-first + swipe channel switch

**Objective:** Как пользователь телефона, я хочу видеть плеер в портретной ориентации с controls overlay снизу и горизонтальным свайпом для переключения каналов («SWIPE ↔ КАНАЛ»).

#### Acceptance Criteria

1. The Mobile Player shall provide a public `PlayerMobileScreen` widget at `lib/features/player/mobile/player_mobile_screen.dart`.
2. The Mobile Player shall render the video surface in the upper region (16:9 or 9:16 depending on orientation) and the controls overlay (`MPlayerControls`) anchored at the bottom.
3. The Mobile Player shall recognise a horizontal swipe gesture (`GestureDetector(onHorizontalDragEnd:)`) and dispatch a channel-switch action — left swipe = next channel, right swipe = previous channel.
4. The Mobile Player shall render an `MSwipeHint` overlay («SWIPE ↔ КАНАЛ») dismissable on first swipe and not re-shown for that session.
5. The Mobile Player shall render a pulsing LIVE dot via `MLiveDot` wrapped in `RepaintBoundary` to isolate the pulse animation from sibling rebuilds.
6. The Mobile Player shall NOT modify the sealed `PlayerUiState` type, native player engines (`lib/core/player/*`), or any TV player file (`lib/features/player/` outside `lib/features/player/mobile/`).
7. The Mobile Player shall consume the existing `PlayerUiState` stream / provider as a read-only subscriber.
8. The Mobile Player shall mount root `Key('player-mobile-root')`.

### Requirement 5: Bottom tabbar — floating glass nav

**Objective:** Как пользователь телефона, я хочу видеть нижнюю плавающую glass-tabbar с 5 tabs (Home, TV, Search, Guide, Profile) поверх content.

#### Acceptance Criteria

1. The Mobile Module shall provide a public `MTabBar` widget at `lib/features/mobile/widgets/m_tab_bar.dart`.
2. The `MTabBar` shall render 5 tabs in a horizontal row: Home / TV / Search / Guide / Profile, each with an icon and a label.
3. The `MTabBar` shall mark exactly one tab as active per render, derived from a Riverpod `activeMobileTabProvider` (new, mobile-only).
4. The `MTabBar` shall float above content with a glass blur background — implemented via raw `BackdropFilter(filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28))` (allowed by Req 11).
5. The `MTabBar` shall position itself at the bottom edge with a safe-area inset (`MediaQuery.viewPaddingOf(context).bottom`).
6. The `MTabBar` shall not appear on TV layouts — it is rendered only inside mobile-path widget trees.

### Requirement 6: Adaptive screen entry — minimal touch on TV files

**Objective:** Как мейнтейнер, я хочу гарантию что подключение mobile-варианта не модифицирует TV widget trees — только mounting seam меняется на `AdaptiveScaffold`.

#### Acceptance Criteria

1. The Mobile Adaptive Module shall mount each adaptive screen via `AdaptiveScaffold(mobile: ..., tv: ...)` at exactly one entry point per screen.
2. The Mobile Adaptive Module shall NOT modify any widget tree inside `lib/features/home/cinematic/` other than (optionally) a one-line wrap in the screen entry file. Implementer SHOULD prefer a separate `<screen>_root.dart` file owning `AdaptiveScaffold`, leaving the TV file with zero modifications.
3. The Mobile Adaptive Module shall NOT modify any widget tree under `lib/features/detail/` outside `lib/features/detail/mobile/`, except (optionally) a one-line wrap.
4. The Mobile Adaptive Module shall NOT modify any widget tree under `lib/features/player/` outside `lib/features/player/mobile/`, except (optionally) a one-line wrap.
5. The cumulative diff outside `lib/core/layout/`, `lib/features/<screen>/mobile/`, `lib/features/mobile/`, and `app_router.dart` (or equivalent) shall be ≤ 3 lines per screen (one wrap per home / detail / player), and zero lines if the implementer adopts the `<screen>_root.dart` pattern.

### Requirement 7: Mobile widgets — `MTopBar`, `MIconBtn`, `MHeroCard`, `MStackedRail`, `MPlayerControls`, `MSwipeHint`, `MLiveDot`

**Objective:** Как разработчик, я хочу набор reusable mobile-специфичных widgets для composition mobile-screens.

#### Acceptance Criteria

1. The Mobile Module shall provide `MTopBar` rendering city / temp / time on the left, brand mark on the right.
2. The Mobile Module shall provide `MIconBtn` — mobile-styled tap-target icon button with min 44×44-px touch area.
3. The Mobile Module shall provide `MHeroCard` — portrait hero with image, title, paginator dots row.
4. The Mobile Module shall provide `MStackedRail` — vertical-scroll single-column rail wrapping atoms `Poster` / `SectionTitle`.
5. The Mobile Module shall provide `MPlayerControls` — bottom-anchored play/pause + channel-up/down + volume slider.
6. The Mobile Module shall provide `MSwipeHint` — animated «SWIPE ↔ КАНАЛ» hint with pulse keyframe (`AnimatedOpacity` 1.5 s loop wrapped in `RepaintBoundary`).
7. The Mobile Module shall provide `MLiveDot` — pulsing live indicator with `RepaintBoundary` wrapping the `AnimationController`.

### Requirement 8: Reuse atoms and theme tokens

**Objective:** Как мейнтейнер, я хочу чтобы mobile widgets переиспользовали atoms (#14) и palette/text styles (#4) — без дублирования visual primitives.

#### Acceptance Criteria

1. The Mobile Module shall import atoms via the barrel `package:megav_iptv/core/ui/atoms/atoms.dart`.
2. The Mobile Module shall read colours via `Theme.of(context).extension<AppColors>()` or the `AppColors` proxy from `design-system-foundation`.
3. The Mobile Module shall read text styles via `Theme.of(context).megavText.<style>` from `design-system-foundation`.
4. The Mobile Module shall not redefine palette colour values, radius constants, or text styles — only mobile-specific spacing / sizing constants are allowed.
5. The Mobile Module shall not introduce any new theme token override.

### Requirement 9: Backward compatibility — TV path untouched

**Objective:** Как мейнтейнер, я хочу гарантию что TV layouts (#5/#7/#8) и закрытые специй продолжают работать без регрессии.

#### Acceptance Criteria

1. The Mobile Adaptive Module shall NOT modify `lib/features/home/cinematic/` widget trees (one-line wrap in the entry file is acceptable iff no other lines change).
2. The Mobile Adaptive Module shall NOT modify TV detail screen widget trees (one-line wrap acceptable as above).
3. The Mobile Adaptive Module shall NOT modify TV player screen widget trees (one-line wrap acceptable as above).
4. The Mobile Adaptive Module shall NOT modify any file under `lib/features/home/widgets/` (closed-spec ownership).
5. The Mobile Adaptive Module shall NOT modify `pickColumns` / `_grid_tokens.dart` / `cinema_row.dart` / `cinema_card.dart` / `_card_poster.dart`.
6. The Mobile Adaptive Module shall NOT modify the sealed `PlayerUiState` type or any file under `lib/core/player/`.
7. While `screenKindOf(context) != ScreenKind.mobile`, the application's behaviour shall be byte-for-byte identical to the TV-only baseline.

### Requirement 10: Test coverage — mobile path + TV regression

**Objective:** Как мейнтейнер, я хочу обширное покрытие mobile widgets + регрессионную защиту существующих TV-тестов.

#### Acceptance Criteria

1. The Mobile Adaptive Module shall ship at least one widget-level test per new mobile widget defined under Requirement 7 (≥7 widget tests).
2. The Mobile Adaptive Module shall ship at least one widget test for `AdaptiveScaffold` asserting that — given a `MediaQuery` with width < 600 — the `mobile` child is built and the `tv` child is not, and vice versa for width ≥ 1280.
3. The Mobile Adaptive Module shall ship at least one smoke-level test for each of the 3 mobile screens (`HomeMobileScreen`, `DetailMobileScreen`, `PlayerMobileScreen`) pumping with mocked providers and asserting no exception across two frames.
4. The Mobile Adaptive Module shall ship one regression test asserting that `AdaptiveScaffold` selects the `tv` child for widths ≥ 1280 — guaranteeing TV path is reachable.
5. After all mobile-spec tasks land, the full test suite (`flutter test`) shall report the prior baseline (94 + tests added by #5/#7/#8) plus all newly added mobile tests, with zero pre-existing tests modified or deleted.

### Requirement 11: Mobile-specific performance relaxation

**Objective:** Как разработчик, я хочу явную локальную свободу использовать `BackdropFilter` / raw blur / расслабленные shadow-blur лимиты в mobile-path коде, потому что mobile GPU (Apple, Snapdragon, recent Android) справляются — это ограничение было только для Mali-class TV-боксов.

#### Acceptance Criteria

1. On the mobile path code (files under `lib/core/layout/`, `lib/features/<screen>/mobile/`, `lib/features/mobile/`), `BackdropFilter`, `ImageFilter.blur`, and `ShaderMask` SHALL be permitted where they materially improve visual quality (e.g., glass tabbar, bottom controls overlay).
2. On the mobile path code, `BoxShadow.blurRadius` may exceed `kSafeShadowBlurMax (12.0)` up to `28.0` for glass / depth effects, except where it would be obviously wasteful.
3. The mobile path SHALL nevertheless wrap any animated blur / pulse / shimmer in `RepaintBoundary` to isolate from sibling rebuilds — this rule is platform-agnostic.
4. The boundary of «mobile path» shall be enforced by directory scope: a CI / review check `grep -rE "BackdropFilter|ImageFilter\.blur|ShaderMask" lib/` returning hits ONLY in `lib/core/layout/`, `lib/features/<screen>/mobile/`, and `lib/features/mobile/` — any hit outside those directories fails the gate.
5. The TV-target specs (#5/#7/#8 and all closed specs) SHALL continue to forbid `BackdropFilter` / `ImageFilter.blur` / `ShaderMask` per `flutter-tv-perf.md` — this requirement does NOT relax the TV-path rule.

### Requirement 12: Testability and observable hooks

**Objective:** Как мейнтейнер, я хочу чёткие точки наблюдения чтобы CI / kiro-review мог проверить compliance без ручного вмешательства.

#### Acceptance Criteria

1. The Mobile Adaptive Module shall expose stable `Key` identifiers on root widgets: `Key('home-mobile-root')`, `Key('detail-mobile-root')`, `Key('player-mobile-root')`, `Key('m-tab-bar')`, `Key('m-top-bar')`, `Key('m-hero-card')`, `Key('m-swipe-hint')`, `Key('m-live-dot')` so tests can locate them.
2. The Mobile Adaptive Module's static analysis shall be clean: `flutter analyze lib/core/layout/ lib/features/home/mobile/ lib/features/detail/mobile/ lib/features/player/mobile/ lib/features/mobile/` reports zero issues.
3. The Mobile Adaptive Module shall be greppable for boundary violations: `grep -rE "BackdropFilter|ImageFilter\.blur|ShaderMask" lib/` shall show hits ONLY inside the mobile directories listed in Req 11.4.
4. The Mobile Adaptive Module shall not require any new package in `pubspec.yaml`.
5. The Mobile Adaptive Module shall expose a per-screen `<Screen>RootScreen` (e.g., `HomeRootScreen`) registered in the router instead of the TV widget directly, so that switching between mobile and TV is handled inside the root file (not at the router) — implementer chooses this OR the one-line wrap pattern, and documents the choice in commit message.
